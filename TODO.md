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

## Backlog
- [ ] ~~Element insert (`web-mode-element-insert`)~~ MAYBE-LATER-OR-NOT — overlaps with auto-close + wrap
- [ ] Indentation: uses tabs instead of spaces — investigate and fix
