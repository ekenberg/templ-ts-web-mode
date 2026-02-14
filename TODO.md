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
- [x] Element clone (`web-mode-element-clone`)
- [x] Element close (`web-mode-element-close`) — context-aware with partial name completion
- [x] Mark-and-expand — progressive structural selection (attribute → element → parent content → parent → ceiling)
- [x] Attribute auto-quoting (`foo=` → `foo="|"`) — toggleable via `templ-ts-web-auto-quote`
- [x] Keybindings with web-mode-compatible defaults (`C-c C-e` prefix, `C-c C-m` for mark-and-expand)

## Backlog

### Cross-cutting
- [ ] Configuration via `defcustom` where it makes sense (e.g. auto-pairing, auto-quoting)

### Investigation
- [ ] CSS blocks in templ — formatting is broken and no fontification; investigate parsing and add support
- [ ] Investigate script tags in templ — how they parse, how JS looks/behaves inside templ context
- [ ] Indentation: uses tabs instead of spaces — investigate and fix

### Doubtful
- [ ] Element insert (`web-mode-element-insert`) — probably not; overlaps with auto-close + wrap
