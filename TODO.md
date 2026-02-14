# TODO — templ-ts-web-mode

## Completed

- [x] Auto-close tags on `>` (void elements, self-closing, nested same-name)
- [x] Auto-complete closing tags on `</`
- [x] Smart Enter between open/close tags
- [x] Text-based tag counting (replacing broken ERROR-node AST approach)
- [x] Test infrastructure with templ wrapper helper
- [x] CLAUDE.md with project docs and test commands
- [x] Element beginning (`web-mode-element-beginning`)
- [x] Element end (`web-mode-element-end`)
- [x] Element select (`web-mode-element-select`) — with expand-on-repeat
- [x] Element rename (`web-mode-element-rename`)
- [x] Element wrap (`web-mode-element-wrap`) — block-wrap with indent or inline

- [x] Fontify `data-*` attributes with a distinct face (`templ-ts-web-data-attr-face`)
- [x] Tag jumping — jump between opening/closing tag (`web-mode-navigate`)
- [x] Next element (`web-mode-element-next`)
- [x] Previous element (`web-mode-element-previous`)
- [x] Element kill (`web-mode-element-kill`)
- [x] Element vanish (`web-mode-element-vanish`) — unwrap with cleanup and re-indent
- [x] Select element content (`web-mode-element-content-select`)

## Backlog

### Element operations
- [ ] Element close (`web-mode-element-close`)
- [ ] Element clone (`web-mode-element-clone`)

### Editing convenience
- [ ] Attribute auto-quoting (`foo=` → `foo="|"` with point between quotes)

### Cross-cutting
- [ ] Keybindings with web-mode-compatible defaults for implemented functions
- [ ] Configuration via `defcustom` where it makes sense (e.g. auto-pairing, auto-quoting)

### Investigation
- [ ] Investigate script tags in templ — how they parse, how JS looks/behaves inside templ context
- [ ] Indentation: uses tabs instead of spaces — investigate and fix

### Doubtful
- [ ] Element insert (`web-mode-element-insert`) — probably not; overlaps with auto-close + wrap
