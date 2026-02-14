# templ-ts-web-mode

Emacs minor mode that adds [web-mode](https://web-mode.org/)-style HTML editing conveniences to [templ-ts-mode](https://github.com/danderson/templ-ts-mode).

## Why?

`templ-ts-mode` provides syntax highlighting and indentation for [templ](https://templ.guide) files, but no HTML editing support — no auto-closing tags, no element navigation, no structural operations. `web-mode` has all of that, but it's a regex-based major mode designed for HTML-primary files. Templ is Go-primary with HTML islands — a different mental model.

This minor mode cherry-picks the most useful HTML editing features from web-mode and re-implements them using tree-sitter, layered non-invasively on top of templ-ts-mode.

## Requirements

- Emacs 29.1+ (tree-sitter support)
- [templ-ts-mode](https://github.com/danderson/templ-ts-mode)
- templ tree-sitter grammar

## Installation

Clone and add to your load path:

```elisp
(add-to-list 'load-path "/path/to/templ-ts-web-mode")
(require 'templ-ts-web-mode)
(add-hook 'templ-ts-mode-hook #'templ-ts-web-mode)
```

## Features

### Auto-insertion

| Trigger | Action |
|---------|--------|
| `>` after `<div` | Inserts `</div>` (skips void elements, self-closing tags) |
| `/` after `<` | Completes closing tag name and `>` |
| `=` in attributes | Inserts `=""` with point between quotes |

Each can be toggled via `defcustom` (see [Customization](#customization)).

### Element operations

All under the `C-c C-e` prefix:

| Key | Command | Description |
|-----|---------|-------------|
| `b` | `element-beginning` | Jump to start of enclosing element |
| `e` | `element-end` | Jump to end of enclosing element |
| `s` | `element-select` | Select enclosing element (expand on repeat) |
| `a` | `element-content-select` | Select content between tags |
| `n` | `element-next` | Jump to next sibling element |
| `p` | `element-previous` | Jump to previous sibling element |
| `m` | `element-navigate` | Jump between opening/closing tag |
| `r` | `element-rename` | Rename tag (updates both open and close) |
| `w` | `element-wrap` | Wrap element or region with a new tag |
| `c` | `element-clone` | Duplicate element |
| `k` | `element-kill` | Kill element |
| `v` | `element-vanish` | Remove tags, keep content (unwrap) |
| `/` | `element-close` | Insert closing tag for innermost unclosed element |

### Other

| Key | Command | Description |
|-----|---------|-------------|
| `C-c C-m` | `mark-and-expand` | Progressive structural selection: attribute, element, parent content, parent, ceiling |
| `RET` | Smart Enter | Opens indented line between `<div>\|</div>` |

Fontifies `data-*` attributes with a distinct face (`templ-ts-web-data-attr-face`).

## Customization

```elisp
;; Toggle auto-insertion behaviors (all default to t)
(setq templ-ts-web-element-auto-close t)    ; > inserts closing tag
(setq templ-ts-web-element-auto-complete t) ; </ completes tag name
(setq templ-ts-web-attr-auto-quote t)       ; = inserts ""
```

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
