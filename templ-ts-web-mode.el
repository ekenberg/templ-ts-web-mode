;;; templ-ts-web-mode.el --- Web-editing conveniences for templ-ts-mode -*- lexical-binding: t; -*-

;; Author: Johan
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, templ, web
;; URL: https://github.com/johan/templ-ts-web-mode

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Minor mode adding web-mode-like editing conveniences on top of
;; templ-ts-mode.  Uses tree-sitter for structural awareness — requires
;; a templ tree-sitter parser active in the buffer.
;;
;; Features:
;; - Auto-close tags: typing `>' after `<div' inserts `</div>'
;; - Auto-complete closing tags: typing `</' completes the tag name
;; - Smart Enter: RET between `<div>|</div>' opens a new indented line
;; - Element navigation: jump to beginning/end of enclosing element
;; - Element select: mark enclosing element, expand on repeat
;; - Element rename: change tag name in both open and close tags
;; - Element wrap: wrap region or enclosing element with a new tag

;;; Code:

(require 'treesit)

;;; Customization

(defgroup templ-ts-web nil
  "Web-editing conveniences for templ buffers."
  :group 'languages
  :prefix "templ-ts-web-")

;;; Constants

(defconst templ-ts-web--void-elements
  '("area" "base" "br" "col" "embed" "hr" "img" "input"
    "link" "meta" "source" "track" "wbr")
  "HTML void elements that must not have a closing tag.")

(defcustom templ-ts-web-tag-list
  '("a" "abbr" "address" "area" "article" "aside" "audio" "b"
    "base" "bdi" "bdo" "blockquote" "body" "br" "button" "canvas"
    "caption" "cite" "code" "col" "colgroup" "data" "datalist"
    "dd" "del" "details" "dfn" "dialog" "div" "dl" "dt" "em"
    "embed" "fieldset" "figcaption" "figure" "footer" "form" "h1"
    "h2" "h3" "h4" "h5" "h6" "head" "header" "hgroup" "hr" "html"
    "i" "iframe" "img" "input" "ins" "kbd" "label" "legend" "li"
    "link" "main" "map" "mark" "math" "menu" "meta" "meter" "nav"
    "noscript" "object" "ol" "optgroup" "option" "output" "p"
    "picture" "pre" "progress" "q" "rp" "rt" "ruby" "s" "samp"
    "script" "search" "section" "select" "slot" "small" "source"
    "span" "strong" "style" "sub" "summary" "sup" "svg" "table"
    "tbody" "td" "template" "textarea" "tfoot" "th" "thead" "time"
    "title" "tr" "track" "u" "ul" "var" "video" "wbr")
  "HTML tag names offered for completion.
Used by `templ-ts-web-element-rename' and other tag-prompting commands."
  :type '(repeat string)
  :group 'templ-ts-web)

(defvar templ-ts-web--tag-history nil
  "History list for tag name prompts.")

;;; Tree-sitter helpers

(defun templ-ts-web--in-templ-p ()
  "Return non-nil if the treesit language at point is `templ'."
  (eq (treesit-language-at (point)) 'templ))

(defun templ-ts-web--ancestor-of-type (node &rest types)
  "Walk up from NODE returning first ancestor whose type is in TYPES."
  (let ((cur (treesit-node-parent node)))
    (while (and cur (not (member (treesit-node-type cur) types)))
      (setq cur (treesit-node-parent cur)))
    cur))

(defun templ-ts-web--tag-name (tag-node)
  "Extract the tag name string from TAG-NODE (tag_start, tag_end, etc)."
  (when-let* ((name-node (treesit-node-child-by-field-name tag-node "name")))
    (treesit-node-text name-node t)))

(defun templ-ts-web--element-tag-name (element)
  "Return the tag name string from ELEMENT (element or self_closing_tag)."
  (pcase (treesit-node-type element)
    ("element"
     (when-let* ((tag (treesit-search-subtree element "^tag_start$" nil nil 1)))
       (templ-ts-web--tag-name tag)))
    ("self_closing_tag"
     (when-let* ((name (treesit-node-child-by-field-name element "name")))
       (treesit-node-text name t)))))

(defun templ-ts-web--element-name-nodes (element)
  "Return name nodes for ELEMENT, ordered start-to-end.
For an element, returns the name nodes from tag_start and tag_end.
For a self_closing_tag, returns a single name node."
  (pcase (treesit-node-type element)
    ("element"
     (let ((nodes nil))
       (when-let* ((tag-start (treesit-search-subtree element "^tag_start$" nil nil 1))
                   (name (treesit-node-child-by-field-name tag-start "name")))
         (push name nodes))
       (when-let* ((tag-end (treesit-search-subtree element "^tag_end$" nil nil 1))
                   (name (treesit-node-child-by-field-name tag-end "name")))
         (push name nodes))
       (nreverse nodes)))
    ("self_closing_tag"
     (when-let* ((name (treesit-node-child-by-field-name element "name")))
       (list name)))))

(defun templ-ts-web--find-tag-start-at (pos)
  "Find a `tag_start' node at or near POS.
Returns the tag_start node or nil."
  (let* ((node (treesit-node-at pos 'templ))
         (type (and node (treesit-node-type node))))
    (cond
     ;; Directly on tag_start
     ((equal type "tag_start") node)
     ;; On the ">" token — parent is tag_start
     ((equal type ">")
      (let ((parent (treesit-node-parent node)))
        (when (and parent (equal (treesit-node-type parent) "tag_start"))
          parent)))
     ;; Walk up to find tag_start ancestor
     (t (when node
          (templ-ts-web--ancestor-of-type node "tag_start"))))))

(defun templ-ts-web--enclosing-element (&optional pos)
  "Return the innermost `element' or `self_closing_tag' node containing POS.
POS defaults to point."
  (when-let* ((node (treesit-node-at (or pos (point)) 'templ)))
    (if (member (treesit-node-type node) '("element" "self_closing_tag"))
        node
      (templ-ts-web--ancestor-of-type node "element" "self_closing_tag"))))

(defun templ-ts-web--find-unclosed-tag-name ()
  "Find the innermost unclosed tag name at point using text scanning.
Scans forward from the enclosing component_block start to point,
tracking a stack of open/close tags.  Returns the tag name or nil."
  (let* ((node (treesit-node-at (point) 'templ))
         (scope (and node (templ-ts-web--ancestor-of-type node "component_block")))
         (start (if scope (treesit-node-start scope) (point-min)))
         (end (point))
         (open-stack nil))
    (save-excursion
      (goto-char start)
      (while (re-search-forward "<\\(/\\)?\\([a-zA-Z][a-zA-Z0-9-]*\\)" end t)
        (let ((closing (match-string 1))
              (name (match-string 2)))
          (if closing
              ;; Closing tag: pop innermost matching open from stack
              (let ((found nil)
                    (result nil))
                (dolist (item open-stack)
                  (if (and (not found) (string= item name))
                      (setq found t)
                    (push item result)))
                (setq open-stack (nreverse result)))
            ;; Opening tag: push unless void or self-closing
            (unless (or (member (downcase name) templ-ts-web--void-elements)
                        (looking-at "[^>]*/[ \t]*>"))
              (push name open-stack))))))
    (car open-stack)))

;;; Feature: auto-close on `>'

(defun templ-ts-web--tag-is-unclosed-p (name)
  "Return non-nil if NAME has more opens than closes in the current scope.
Counts <NAME...> and </NAME> occurrences within the enclosing
component_block, avoiding reliance on tree-sitter's element pairing
which is unreliable during mid-edit parse states."
  (let* ((node (treesit-node-at (point) 'templ))
         (scope (and node (templ-ts-web--ancestor-of-type node "component_block")))
         (start (if scope (treesit-node-start scope) (point-min)))
         (end (if scope (treesit-node-end scope) (point-max)))
         (open-re (concat "<" (regexp-quote name) "[ \t\n>]"))
         (close-re (concat "</" (regexp-quote name) ">"))
         (opens 0)
         (closes 0))
    (save-excursion
      (goto-char start)
      (while (re-search-forward open-re end t)
        (setq opens (1+ opens)))
      (goto-char start)
      (while (re-search-forward close-re end t)
        (setq closes (1+ closes))))
    (> opens closes)))

(defun templ-ts-web--post-close-angle ()
  "After `>' is inserted, auto-close the tag if appropriate."
  (when (and (eq last-command-event ?>)
             (templ-ts-web--in-templ-p)
             ;; Not self-closing: char before `>' isn't `/'
             (not (eq (char-before (1- (point))) ?/)))
    ;; Re-parse so tree-sitter sees the just-typed `>'.
    (treesit-update-ranges)
    (let ((tag-start (templ-ts-web--find-tag-start-at (1- (point)))))
      (when tag-start
        (let ((name (templ-ts-web--tag-name tag-start)))
          (when (and name
                     (not (member (downcase name) templ-ts-web--void-elements))
                     ;; Confirm this tag_start ends at point — the `>'
                     ;; we just typed is the closing `>' of THIS tag,
                     ;; not some ancestor found by walking up.
                     (= (treesit-node-end tag-start) (point))
                     ;; Only auto-close if opens > closes in scope.
                     ;; Text-counting avoids tree-sitter's greedy pairing
                     ;; which steals close tags during mid-edit states.
                     (templ-ts-web--tag-is-unclosed-p name))
            (save-excursion (insert "</" name ">"))))))))

;;; Feature: auto-complete on `</'

(defun templ-ts-web--post-close-slash ()
  "After `/' is inserted following `<', auto-complete the closing tag."
  (when (and (eq last-command-event ?/)
             (>= (point) 3)
             (eq (char-before (1- (point))) ?<)
             (templ-ts-web--in-templ-p))
    (let ((name (save-excursion
                  (goto-char (- (point) 2))
                  (templ-ts-web--find-unclosed-tag-name))))
      (when name
        (insert name ">")))))

;;; Feature: smart Enter between tags

(defun templ-ts-web--between-tags-p ()
  "Return non-nil if point is in whitespace between an open and close tag.
Scans backward over whitespace for `>' of an opening tag and forward
over whitespace for `</', verifying only whitespace separates them."
  (save-excursion
    (let ((start (progn (skip-chars-backward " \t") (point))))
      (and (eq (char-before start) ?>)
           ;; Not a self-closing tag (/>)
           (not (eq (char-before (1- start)) ?/))
           ;; The > belongs to an opening tag, not a closing tag
           (save-excursion
             (goto-char (1- start))
             (and (search-backward "<" (max (- (point) 500) (point-min)) t)
                  (not (eq (char-after (1+ (point))) ?/))))
           ;; Forward from > finds only same-line whitespace then </
           (progn
             (goto-char start)
             (skip-chars-forward " \t")
             (looking-at "</"))))))

(defun templ-ts-web--smart-enter ()
  "If point is between an open and close tag, open an indented blank line.
Otherwise run the normal binding for RET."
  (interactive)
  (if (and (templ-ts-web--in-templ-p)
           (templ-ts-web--between-tags-p))
      (let ((open-end (save-excursion
                        (skip-chars-backward " \t")
                        (point)))
            (close-start (save-excursion
                           (skip-chars-forward " \t")
                           (point))))
        ;; Delete all whitespace between > and </
        (delete-region open-end close-start)
        (goto-char open-end)
        ;; Insert two newlines: one for the cursor line, one before the close tag
        (insert "\n\n")
        ;; Point is now on the line with the close tag — indent it
        (indent-according-to-mode)
        ;; Move back to the middle (blank) line and indent
        (forward-line -1)
        (indent-according-to-mode))
    ;; Not between tags — normal RET
    (newline-and-indent)))

;;; Feature: element navigation

(defun templ-ts-web-element-beginning ()
  "Move point to the beginning of the enclosing HTML element."
  (interactive)
  (when-let* ((element (templ-ts-web--enclosing-element)))
    (goto-char (treesit-node-start element))))

(defun templ-ts-web-element-end ()
  "Move point to the end of the enclosing HTML element."
  (interactive)
  (when-let* ((element (templ-ts-web--enclosing-element)))
    (goto-char (treesit-node-end element))))

(defun templ-ts-web-element-select ()
  "Select the enclosing HTML element.
On repeat, expand selection to the parent element."
  (interactive)
  (when-let* ((element (templ-ts-web--enclosing-element)))
    ;; If region already matches this element, expand to parent.
    (when (and (use-region-p)
               (= (region-beginning) (treesit-node-start element))
               (= (region-end) (treesit-node-end element)))
      (setq element (templ-ts-web--ancestor-of-type element "element")))
    (when element
      (push-mark (treesit-node-end element) nil t)
      (goto-char (treesit-node-start element)))))

;;; Feature: element rename

(defun templ-ts-web-element-rename (new-name)
  "Rename the enclosing HTML element's tag to NEW-NAME.
Replaces the tag name in both the opening and closing tags."
  (interactive
   (let ((name (when-let* ((el (templ-ts-web--enclosing-element)))
                 (templ-ts-web--element-tag-name el))))
     (list (completing-read
            (if name (format "Rename <%s> to: " name) "Tag name: ")
            templ-ts-web-tag-list nil nil nil
            'templ-ts-web--tag-history))))
  (when (and new-name (not (string-empty-p new-name)))
    (when-let* ((element (templ-ts-web--enclosing-element))
                (name-nodes (templ-ts-web--element-name-nodes element)))
      ;; Replace end-to-start to preserve positions.
      (dolist (node (sort (copy-sequence name-nodes)
                          (lambda (a b) (> (treesit-node-start a)
                                           (treesit-node-start b)))))
        (delete-region (treesit-node-start node) (treesit-node-end node))
        (goto-char (treesit-node-start node))
        (insert new-name)))))

;;; Feature: element wrap

(defun templ-ts-web-element-wrap (tag-name)
  "Wrap the region or enclosing element with TAG-NAME tags.
With an active region, wraps the selected text.  Otherwise wraps
the enclosing element.  Block-wraps (with newlines and
re-indentation) when the content spans multiple lines or when
wrapping a whole element; inline-wraps otherwise."
  (interactive
   (list (completing-read "Wrap with tag: "
                          templ-ts-web-tag-list nil nil nil
                          'templ-ts-web--tag-history)))
  (when (and tag-name (not (string-empty-p tag-name)))
    (let (beg end block-p)
      (if (use-region-p)
          (setq beg (region-beginning)
                end (region-end)
                block-p (string-match-p "\n" (buffer-substring-no-properties beg end)))
        (when-let* ((element (templ-ts-web--enclosing-element)))
          (setq beg (treesit-node-start element)
                end (treesit-node-end element)
                block-p t)))
      (when (and beg end)
        (let ((open-tag (concat "<" tag-name ">"))
              (close-tag (concat "</" tag-name ">")))
          (goto-char end)
          (if block-p
              (insert "\n" close-tag)
            (insert close-tag))
          (goto-char beg)
          (if block-p
              (insert open-tag "\n")
            (insert open-tag))
          (when block-p
            (treesit-update-ranges)
            (indent-region beg (+ end (length open-tag) (length close-tag) 2)))
          (goto-char beg))))))

;;; Minor mode

(defvar templ-ts-web-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'templ-ts-web--smart-enter)
    map)
  "Keymap for `templ-ts-web-mode'.")

;;;###autoload
(define-minor-mode templ-ts-web-mode
  "Web-editing conveniences for templ buffers.

Adds auto-close tags, closing tag completion, and smart Enter
on top of a templ tree-sitter major mode."
  :lighter " tw"
  :keymap templ-ts-web-mode-map
  (if templ-ts-web-mode
      (progn
        (add-hook 'post-self-insert-hook #'templ-ts-web--post-close-angle nil t)
        (add-hook 'post-self-insert-hook #'templ-ts-web--post-close-slash nil t))
    (remove-hook 'post-self-insert-hook #'templ-ts-web--post-close-angle t)
    (remove-hook 'post-self-insert-hook #'templ-ts-web--post-close-slash t)))

(provide 'templ-ts-web-mode)

;;; templ-ts-web-mode.el ends here
