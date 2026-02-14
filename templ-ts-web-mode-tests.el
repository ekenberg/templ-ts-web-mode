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
        (transient-mark-mode 1)
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

;;; Tests: element-navigate (tag jumping)

(ert-deftest ttwt-navigate-from-content-to-close ()
  "From content, jump to the closing tag's `<'."
  ;; <div>hel|lo</div>
  ;; 1234567890123456
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-navigate)
    (should (= (ttwt--point-in-content) 11))))

(ert-deftest ttwt-navigate-from-open-to-close ()
  "From the opening tag, jump to the closing tag's `<'."
  ;; <di|v>hello</div>
  (ttwt--with-templ "<di|v>hello</div>" t
    (templ-ts-web-element-navigate)
    (should (= (ttwt--point-in-content) 11))))

(ert-deftest ttwt-navigate-from-close-to-open ()
  "From the closing tag, jump to the opening tag's `<'."
  ;; <div>hello</di|v>
  (ttwt--with-templ "<div>hello</di|v>" t
    (templ-ts-web-element-navigate)
    (should (= (ttwt--point-in-content) 1))))

(ert-deftest ttwt-navigate-nested ()
  "Navigate targets the innermost element."
  ;; <div><span>te|xt</span></div>
  ;;      ^6          ^16
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-navigate)
    (should (= (ttwt--point-in-content) 16))))

(ert-deftest ttwt-navigate-self-closing-noop ()
  "Navigate on a self-closing tag is a no-op."
  (ttwt--with-templ "<br />|" t
    (let ((pos (ttwt--point-in-content)))
      (templ-ts-web-element-navigate)
      (should (= (ttwt--point-in-content) pos)))))

(ert-deftest ttwt-navigate-roundtrip ()
  "Two navigations return to the opening tag."
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-navigate)
    (should (= (ttwt--point-in-content) 11))
    (templ-ts-web-element-navigate)
    (should (= (ttwt--point-in-content) 1))))

;;; Tests: element-next

(ert-deftest ttwt-next-sibling ()
  "Move from first sibling to second."
  ;; <div><span>a</span><em>b|</em></div>
  ;;      ^6         ^16
  (ttwt--with-templ "<div><span>a|</span><em>b</em></div>" t
    (templ-ts-web-element-next)
    (should (= (ttwt--point-in-content) 20))))

(ert-deftest ttwt-next-no-sibling ()
  "No-op when no next sibling element."
  (ttwt--with-templ "<div><span>a|</span></div>" t
    (let ((pos (ttwt--point-in-content)))
      (templ-ts-web-element-next)
      (should (= (ttwt--point-in-content) pos)))))

(ert-deftest ttwt-next-skips-text ()
  "Next element skips over text nodes between siblings."
  ;; <div><span>a</span>text<em>b</em></div>
  ;;      ^6              ^21
  (ttwt--with-templ "<div><span>a|</span>text<em>b</em></div>" t
    (templ-ts-web-element-next)
    (should (= (ttwt--point-in-content) 24))))

(ert-deftest ttwt-next-past-self-closing ()
  "Next element moves past a self-closing tag without getting stuck."
  ;; <div><br /><span>a</span></div>
  ;;      ^6    ^12
  (ttwt--with-templ "<div><br />|<span>a</span></div>" t
    ;; Point is right after <br />, should be inside it or near it.
    ;; First, go back to inside the <br /> element.
    (goto-char (+ (length ttwt--wrapper-prefix) 6))
    (templ-ts-web-element-next)
    (should (= (ttwt--point-in-content) 12))))

;;; Tests: element-previous

(ert-deftest ttwt-previous-sibling ()
  "Move from second sibling to first."
  (ttwt--with-templ "<div><span>a</span><em>b|</em></div>" t
    (templ-ts-web-element-previous)
    (should (= (ttwt--point-in-content) 6))))

(ert-deftest ttwt-previous-no-sibling ()
  "No-op when no previous sibling element."
  (ttwt--with-templ "<div><span>a|</span></div>" t
    (let ((pos (ttwt--point-in-content)))
      (templ-ts-web-element-previous)
      (should (= (ttwt--point-in-content) pos)))))

(ert-deftest ttwt-previous-skips-text ()
  "Previous element skips over text nodes between siblings."
  (ttwt--with-templ "<div><span>a</span>text<em>b|</em></div>" t
    (templ-ts-web-element-previous)
    (should (= (ttwt--point-in-content) 6))))

(ert-deftest ttwt-previous-past-self-closing ()
  "Previous element moves past a self-closing tag without getting stuck."
  ;; <div><span>a</span><br /></div>
  ;;      ^6             ^20
  (ttwt--with-templ "<div><span>a</span><br /><em>b|</em></div>" t
    ;; Point is in <em>, go to <br /> first
    (templ-ts-web-element-previous)
    ;; Now at <br />, go to <span>
    (templ-ts-web-element-previous)
    (should (= (ttwt--point-in-content) 6))))

;;; Tests: element-beginning

(ert-deftest ttwt-element-beginning-from-content ()
  "Point in element content moves to the opening `<'."
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-beginning)
    (should (= (ttwt--point-in-content) 1))))

(ert-deftest ttwt-element-beginning-from-close-tag ()
  "Point inside the closing tag moves to the opening `<'."
  (ttwt--with-templ "<div>hello</di|v>" t
    (templ-ts-web-element-beginning)
    (should (= (ttwt--point-in-content) 1))))

(ert-deftest ttwt-element-beginning-from-open-tag ()
  "Point inside the opening tag moves to the `<'."
  (ttwt--with-templ "<di|v>hello</div>" t
    (templ-ts-web-element-beginning)
    (should (= (ttwt--point-in-content) 1))))

(ert-deftest ttwt-element-beginning-nested ()
  "Point in inner element goes to inner element's beginning."
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-beginning)
    (should (= (ttwt--point-in-content) 6))))

;;; Tests: element-end

(ert-deftest ttwt-element-end-from-content ()
  "Point in element content moves past the closing `>'."
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-end)
    (should (= (ttwt--point-in-content) 17))))

(ert-deftest ttwt-element-end-from-open-tag ()
  "Point in the opening tag moves past the closing `>'."
  (ttwt--with-templ "<di|v>hello</div>" t
    (templ-ts-web-element-end)
    (should (= (ttwt--point-in-content) 17))))

(ert-deftest ttwt-element-end-nested ()
  "Point in inner element goes to inner element's end."
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-end)
    (should (= (ttwt--point-in-content) 23))))

;;; Tests: element-select

(ert-deftest ttwt-element-select-from-content ()
  "Select element when point is in content."
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-select)
    (should (use-region-p))
    (should (= (ttwt--point-in-content) 1))
    (should (= (- (region-end) (length ttwt--wrapper-prefix)) 17))))

(ert-deftest ttwt-element-select-from-open-tag ()
  "Select element when point is in the opening tag."
  (ttwt--with-templ "<di|v>hello</div>" t
    (templ-ts-web-element-select)
    (should (use-region-p))
    (should (= (ttwt--point-in-content) 1))
    (should (= (- (region-end) (length ttwt--wrapper-prefix)) 17))))

(ert-deftest ttwt-element-select-nested ()
  "Select innermost element when nested."
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-select)
    (should (use-region-p))
    (should (= (ttwt--point-in-content) 6))
    (should (= (- (region-end) (length ttwt--wrapper-prefix)) 23))))

(ert-deftest ttwt-element-select-expand-to-parent ()
  "Repeated select expands to parent element."
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-select)
    ;; First call selects <span>
    (should (= (ttwt--point-in-content) 6))
    (should (= (- (region-end) (length ttwt--wrapper-prefix)) 23))
    ;; Second call expands to <div>
    (templ-ts-web-element-select)
    (should (= (ttwt--point-in-content) 1))
    (should (= (- (region-end) (length ttwt--wrapper-prefix)) 29))))

;;; Tests: element-kill

(ert-deftest ttwt-kill-element ()
  "Kill removes the entire element and puts it on the kill ring."
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-kill)
    (should (string= (ttwt--content) ""))
    (should (string= (car kill-ring) "<div>hello</div>"))))

(ert-deftest ttwt-kill-nested-inner ()
  "Kill targets the innermost element."
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-kill)
    (should (string= (ttwt--content) "<div></div>"))))

(ert-deftest ttwt-kill-self-closing ()
  "Kill removes a self-closing tag."
  (ttwt--with-templ "<div><br| /></div>" t
    (templ-ts-web-element-kill)
    (should (string= (ttwt--content) "<div></div>"))))

(ert-deftest ttwt-kill-at-child-start ()
  "Kill at `<' of child element kills the child, not the parent."
  (ttwt--with-templ "<div>|<span>text</span></div>" t
    (templ-ts-web-element-kill)
    (should (string= (ttwt--content) "<div></div>"))))

(ert-deftest ttwt-kill-in-gap-before-child ()
  "Kill in whitespace before child element kills the parent."
  (ttwt--with-templ "<div>|  <span>text</span></div>" t
    (templ-ts-web-element-kill)
    (should (string= (ttwt--content) ""))))

;;; Tests: element-vanish (unwrap)

(ert-deftest ttwt-vanish-unwraps ()
  "Vanish removes tags but keeps content."
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-vanish)
    (should (string= (ttwt--content) "<div>text</div>"))))

(ert-deftest ttwt-vanish-outer ()
  "Vanish on outer element keeps inner elements."
  (ttwt--with-templ "<di|v><span>text</span></div>" t
    (templ-ts-web-element-vanish)
    (should (string= (ttwt--content) "<span>text</span>"))))

(ert-deftest ttwt-vanish-self-closing ()
  "Vanish on self-closing tag removes it entirely."
  (ttwt--with-templ "<div><br| /></div>" t
    (templ-ts-web-element-vanish)
    (should (string= (ttwt--content) "<div></div>"))))

;;; Tests: element-content-select

(ert-deftest ttwt-content-select ()
  "Select content between tags."
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-content-select)
    (should (use-region-p))
    ;; Point at end of <div> = position 6, mark at start of </div> = position 11
    (should (= (ttwt--point-in-content) 6))
    (should (= (- (region-end) (length ttwt--wrapper-prefix)) 11))))

(ert-deftest ttwt-content-select-nested ()
  "Select content of innermost element."
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-content-select)
    (should (use-region-p))
    (should (= (ttwt--point-in-content) 12))
    (should (= (- (region-end) (length ttwt--wrapper-prefix)) 16))))

(ert-deftest ttwt-content-select-self-closing-noop ()
  "Content select on self-closing tag is a no-op."
  (ttwt--with-templ "<div><br| /></div>" t
    (templ-ts-web-element-content-select)
    (should-not (use-region-p))))

;;; Tests: element-rename

(ert-deftest ttwt-rename-div-to-span ()
  "Rename <div> to <span> changes both tags."
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-rename "span")
    (should (string= (ttwt--content) "<span>hello</span>"))))

(ert-deftest ttwt-rename-from-open-tag ()
  "Rename works when point is in the opening tag."
  (ttwt--with-templ "<di|v>hello</div>" t
    (templ-ts-web-element-rename "section")
    (should (string= (ttwt--content) "<section>hello</section>"))))

(ert-deftest ttwt-rename-from-close-tag ()
  "Rename works when point is in the closing tag."
  (ttwt--with-templ "<div>hello</di|v>" t
    (templ-ts-web-element-rename "p")
    (should (string= (ttwt--content) "<p>hello</p>"))))

(ert-deftest ttwt-rename-nested-inner ()
  "Rename targets the innermost element."
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-rename "em")
    (should (string= (ttwt--content) "<div><em>text</em></div>"))))

(ert-deftest ttwt-rename-with-attributes ()
  "Rename preserves attributes on the opening tag."
  (ttwt--with-templ "<div class=\"foo\">hel|lo</div>" t
    (templ-ts-web-element-rename "section")
    (should (string= (ttwt--content) "<section class=\"foo\">hello</section>"))))

(ert-deftest ttwt-rename-empty-string-noop ()
  "Rename with empty string does nothing."
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-rename "")
    (should (string= (ttwt--content) "<div>hello</div>"))))

;;; Tests: element-wrap

(ert-deftest ttwt-wrap-region-inline ()
  "Wrap inline region without newlines."
  (ttwt--with-templ "<p>hello</p>" nil
    ;; Select "hello"
    (goto-char (+ (length ttwt--wrapper-prefix) 4))
    (push-mark (+ (length ttwt--wrapper-prefix) 9) nil t)
    (templ-ts-web-element-wrap "em")
    (should (string= (ttwt--content) "<p><em>hello</em></p>"))))

(ert-deftest ttwt-wrap-enclosing-element ()
  "Wrap enclosing element with block-style newlines."
  (ttwt--with-templ "<span>te|xt</span>" t
    (templ-ts-web-element-wrap "div")
    (let ((content (ttwt--content)))
      ;; Should have wrapping div with the span inside
      (should (string-match-p "<div>" content))
      (should (string-match-p "</div>" content))
      (should (string-match-p "<span>text</span>" content)))))

(ert-deftest ttwt-wrap-empty-string-noop ()
  "Wrap with empty string does nothing."
  (ttwt--with-templ "<div>hel|lo</div>" t
    (templ-ts-web-element-wrap "")
    (should (string= (ttwt--content) "<div>hello</div>"))))

(ert-deftest ttwt-wrap-nested-inner ()
  "Wrap targets the innermost element when no region."
  (ttwt--with-templ "<div><span>te|xt</span></div>" t
    (templ-ts-web-element-wrap "em")
    (let ((content (ttwt--content)))
      (should (string-match-p "<em>" content))
      (should (string-match-p "</em>" content))
      ;; The outer div should remain unwrapped
      (should (string-match-p "\\`<div>" content)))))

;;; Tests: data-* attribute fontification

(defmacro ttwt--with-fontified-templ (content &rest body)
  "Execute BODY in a fontified templ buffer with CONTENT."
  (declare (indent 1))
  `(let ((buf (ttwt--templ-buffer ,content nil)))
     (unwind-protect
         (with-current-buffer buf
           (setq-local font-lock-defaults '(nil t))
           (setq-local font-lock-fontify-region-function
                       #'treesit-font-lock-fontify-region)
           (font-lock-mode 1)
           (font-lock-ensure)
           ,@body)
       (kill-buffer buf))))

(defun ttwt--face-at (content-offset)
  "Return the face text property at CONTENT-OFFSET (1-based in content)."
  (get-text-property (+ (length ttwt--wrapper-prefix) content-offset) 'face))

(ert-deftest ttwt-fontify-data-attr ()
  "data-* attribute names get `templ-ts-web-data-attr-face'."
  ;; <div data-testid="main">x</div>
  ;;      ^pos 6
  (ttwt--with-fontified-templ "<div data-testid=\"main\">x</div>"
    (should (eq (ttwt--face-at 6) 'templ-ts-web-data-attr-face))))

(ert-deftest ttwt-fontify-regular-attr-no-data-face ()
  "Regular attribute names do NOT get `templ-ts-web-data-attr-face'."
  ;; <div class="foo" data-x="y">x</div>
  ;;      ^pos 6        ^pos 18
  (ttwt--with-fontified-templ "<div class=\"foo\" data-x=\"y\">x</div>"
    (should-not (eq (ttwt--face-at 6) 'templ-ts-web-data-attr-face))
    (should (eq (ttwt--face-at 18) 'templ-ts-web-data-attr-face))))

(ert-deftest ttwt-fontify-multiple-data-attrs ()
  "Multiple data-* attributes on the same element all get the face."
  ;; <div data-a="1" data-b="2">x</div>
  ;;      ^pos 6       ^pos 17
  (ttwt--with-fontified-templ "<div data-a=\"1\" data-b=\"2\">x</div>"
    (should (eq (ttwt--face-at 6) 'templ-ts-web-data-attr-face))
    (should (eq (ttwt--face-at 17) 'templ-ts-web-data-attr-face))))

;;; Tests: void element list

(ert-deftest ttwt-void-elements-complete ()
  "All standard HTML void elements are in the list."
  (dolist (tag '("area" "base" "br" "col" "embed" "hr" "img"
                 "input" "link" "meta" "source" "track" "wbr"))
    (should (member tag templ-ts-web--void-elements))))

(provide 'templ-ts-web-mode-tests)

;;; templ-ts-web-mode-tests.el ends here
