;;; templ-ts-web-mode-tests.el --- Tests for templ-ts-web-mode -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'treesit)

(load-file (expand-file-name "templ-ts-web-mode.el"
                             (file-name-directory (or load-file-name
                                                      buffer-file-name))))

;;; Test helpers

(defconst ttwt--wrapper-prefix "package main\n\ntempl test() {\n"
  "Templ wrapper inserted before test content.")

(defconst ttwt--wrapper-suffix "\n}\n"
  "Templ wrapper inserted after test content.")

(defun ttwt--templ-buffer (content &optional point-marker)
  "Create a temp buffer with a templ tree-sitter parser and CONTENT.
If POINT-MARKER is non-nil, `|' in CONTENT marks point position and is removed.
Returns the buffer (caller must kill it)."
  (let ((buf (generate-new-buffer " *ttwt-test*")))
    (with-current-buffer buf
      (let ((pos nil))
        (if point-marker
            (let ((idx (string-search "|" content)))
              (when idx
                (setq content (concat (substring content 0 idx)
                                      (substring content (1+ idx))))
                (setq pos (1+ idx))))
          (setq pos (1+ (length content))))
        (insert content)
        ;; Wrap in a minimal templ component.
        (goto-char (point-min))
        (insert ttwt--wrapper-prefix)
        (goto-char (point-max))
        (insert ttwt--wrapper-suffix)
        ;; Adjust pos for prefix.
        (setq pos (+ pos (length ttwt--wrapper-prefix)))
        (goto-char pos)
        (treesit-parser-create 'templ)
        (setq-local treesit-language-at-point-function
                    (lambda (_pos) 'templ))
        (templ-ts-web-mode 1)))
    buf))

(defmacro ttwt--with-templ (content point-marker &rest body)
  "Execute BODY in a templ buffer with CONTENT.
POINT-MARKER: if non-nil, `|' in content marks point."
  (declare (indent 2))
  `(let ((buf (ttwt--templ-buffer ,content ,point-marker)))
     (unwind-protect
         (with-current-buffer buf ,@body)
       (kill-buffer buf))))

(defun ttwt--content ()
  "Return buffer content without the templ wrapper."
  (let ((text (buffer-string)))
    (substring text
               (length ttwt--wrapper-prefix)
               (- (length text) (length ttwt--wrapper-suffix)))))

(defun ttwt--point-in-content ()
  "Return point as 1-based offset into just the content (without wrapper)."
  (- (point) (length ttwt--wrapper-prefix)))

(defun ttwt--type-char (char)
  "Simulate typing CHAR: insert it and run post-self-insert-hook."
  (let ((last-command-event char))
    (insert (char-to-string char))
    (run-hooks 'post-self-insert-hook)))

;;; Tests: auto-close on `>'

(ert-deftest ttwt-close-div ()
  "Typing > after <div inserts </div>."
  (ttwt--with-templ "<div" nil
    (ttwt--type-char ?>)
    (should (string= (ttwt--content) "<div></div>"))
    ;; Point should be between > and </
    (should (= (ttwt--point-in-content) 6))))

(ert-deftest ttwt-close-span ()
  "Typing > after <span inserts </span>."
  (ttwt--with-templ "<span" nil
    (ttwt--type-char ?>)
    (should (string= (ttwt--content) "<span></span>"))))

(ert-deftest ttwt-close-with-attributes ()
  "Typing > after tag with attributes inserts closing tag."
  (ttwt--with-templ "<div class=\"foo\" id=\"bar\"" nil
    (ttwt--type-char ?>)
    (should (string= (ttwt--content)
                      "<div class=\"foo\" id=\"bar\"></div>"))))

(ert-deftest ttwt-no-close-void-br ()
  "Void element <br> does not get a closing tag."
  (ttwt--with-templ "<br" nil
    (ttwt--type-char ?>)
    (should (string= (ttwt--content) "<br>"))))

(ert-deftest ttwt-no-close-void-img ()
  "Void element <img> does not get a closing tag."
  (ttwt--with-templ "<img src=\"x\"" nil
    (ttwt--type-char ?>)
    (should (string= (ttwt--content) "<img src=\"x\">"))))

(ert-deftest ttwt-no-close-void-input ()
  "Void element <input> does not get a closing tag."
  (ttwt--with-templ "<input type=\"text\"" nil
    (ttwt--type-char ?>)
    (should (string= (ttwt--content) "<input type=\"text\">"))))

(ert-deftest ttwt-no-close-self-closing ()
  "Self-closing <img /> does not get a closing tag."
  (ttwt--with-templ "<img src=\"x\" /" nil
    (ttwt--type-char ?>)
    (should (string= (ttwt--content) "<img src=\"x\" />"))))

(ert-deftest ttwt-close-nested-same-name ()
  "Typing <div> inside existing <div>|</div> auto-closes the inner div."
  (ttwt--with-templ "<div>|</div>" t
    ;; Simulate typing <div> between existing tags
    (insert "<div")
    (ttwt--type-char ?>)
    (should (string= (ttwt--content) "<div><div></div></div>"))))

;;; Tests: auto-complete on `</'

(ert-deftest ttwt-complete-div ()
  "Typing </ inside <div>hello completes to </div>."
  (ttwt--with-templ "<div>hello<" nil
    (ttwt--type-char ?/)
    (should (string= (ttwt--content) "<div>hello</div>"))))

(ert-deftest ttwt-complete-nested-inner ()
  "Typing </ inside nested tags completes the innermost unclosed."
  (ttwt--with-templ "<div><span>text<" nil
    (ttwt--type-char ?/)
    (should (string= (ttwt--content) "<div><span>text</span>"))))

(ert-deftest ttwt-complete-nested-same-name ()
  "Typing </ with nested same-name tags: inner closed, complete outer."
  (ttwt--with-templ "<div><div></div><" nil
    (ttwt--type-char ?/)
    (should (string= (ttwt--content) "<div><div></div></div>"))))

(ert-deftest ttwt-complete-deeply-nested ()
  "Typing </ in deeply nested unclosed structure completes innermost."
  (ttwt--with-templ "<div><p><span>text<" nil
    (ttwt--type-char ?/)
    (should (string= (ttwt--content) "<div><p><span>text</span>"))))

;;; Tests: smart Enter between tags

(ert-deftest ttwt-enter-between-tags ()
  "RET between <div>|</div> opens an indented blank line."
  (ttwt--with-templ "<div>|</div>" t
    (templ-ts-web--smart-enter)
    (let ((content (ttwt--content)))
      ;; Should have opening tag, then newline, then closing tag
      (should (string-match-p "\\`<div>\n" content))
      (should (string-match-p "\n</div>\\'" content))
      ;; Point should be on the middle line (between the two newlines)
      (let ((lines (split-string content "\n")))
        (should (= (length lines) 3))
        (should (string= (car lines) "<div>"))
        (should (string= (nth 2 lines) "</div>"))))))

(ert-deftest ttwt-enter-not-between-tags ()
  "RET after text (not between tags) does a normal newline."
  (ttwt--with-templ "<div>hello|</div>" t
    (templ-ts-web--smart-enter)
    (let ((content (ttwt--content)))
      ;; Should NOT do the three-line expansion
      (should (string-match-p "hello\n" content)))))

(ert-deftest ttwt-enter-point-on-middle-line ()
  "After smart Enter, point is on the blank middle line."
  (ttwt--with-templ "<div>|</div>" t
    ;; Remember where <div> line is (in absolute line numbers)
    (let ((open-tag-line (line-number-at-pos)))
      (templ-ts-web--smart-enter)
      ;; Point should be exactly one line below the opening tag
      (should (= (line-number-at-pos) (1+ open-tag-line))))))

(ert-deftest ttwt-no-duplicate-close-on-retype ()
  "Deleting > and retyping it does NOT insert a duplicate close tag."
  (ttwt--with-templ "<div>|</div>" t
    ;; Delete the > we're sitting after, then retype it
    (delete-char -1)
    (ttwt--type-char ?>)
    (should (string= (ttwt--content) "<div></div>"))))

(ert-deftest ttwt-enter-between-tags-with-whitespace ()
  "RET with point in whitespace between tags on the same line."
  (ttwt--with-templ "<div>  |  </div>" t
    (templ-ts-web--smart-enter)
    (let ((lines (split-string (ttwt--content) "\n")))
      (should (= (length lines) 3))
      (should (string= (car lines) "<div>"))
      (should (string-match-p "^\\s-*</div>$" (nth 2 lines))))))

(ert-deftest ttwt-enter-no-trigger-across-lines ()
  "RET between tags on different lines does normal newline-and-indent."
  (ttwt--with-templ "<div>\n|</div>" t
    (templ-ts-web--smart-enter)
    ;; Should NOT collapse into 3-line form; just inserts a newline
    (let ((content (ttwt--content)))
      (should (string-match-p "<div>\n" content))
      (should (string-match-p "\n</div>" content)))))

;;; Tests: void element list

(ert-deftest ttwt-void-elements-complete ()
  "All standard HTML void elements are in the list."
  (dolist (tag '("area" "base" "br" "col" "embed" "hr" "img"
                 "input" "link" "meta" "source" "track" "wbr"))
    (should (member tag templ-ts-web--void-elements))))

(provide 'templ-ts-web-mode-tests)

;;; templ-ts-web-mode-tests.el ends here
