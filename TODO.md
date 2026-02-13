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

## Backlog

- [ ] Element select (`web-mode-element-select`)
- [ ] Element rename (`web-mode-element-rename`)
- [ ] Element wrap (`web-mode-element-wrap`)
- [ ] Element insert (`web-mode-element-insert`)
- [ ] Fontify `data-*` attributes with a distinct face
  - web-mode chain: `web-mode-attr-scan` (line 5934) sets flag bit 1 on attrs matching `^data[-]`, then `web-mode-fontify-attrs` (line 6916) maps bit 1 → `web-mode-html-attr-custom-face` (line 537, inherits from attr-name face)
  - TBD: define our own face (no web-mode dependency) — discuss naming/styling later
