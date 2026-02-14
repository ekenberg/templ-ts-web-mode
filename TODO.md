# TODO — templ-ts-web-mode

## Backlog

- [~] Fix element-kill/clone near void elements — tentatively done. Root cause was gap detection in `--enclosing-element` using `when` (single pass) instead of `while` (loop). Wrapper `element` nodes around `self_closing_tag` have identical bounds, so one walk-up wasn't enough. Fix: `when` → `while`. User confirmed kill/clone now work correctly. Tests added: `ttwt-kill-at-void-start`, `ttwt-kill-after-void-no-space`. Awaiting final sign-off.
- [ ] Improve installation instructions — add use-package example, test hook with templ-ts-mode

### Investigation (resolved — upstream)
- Investigated: CSS blocks — `css_declaration` closing `}` misindented, no CSS fontification beyond property names. All upstream in templ-ts-mode.
- Investigated: `<script>` HTML elements — JS parser ranges miss `script_element_text` nodes. Upstream in templ-ts-mode.
- Investigated: `<style>` HTML elements — `style_element_text` is opaque, no embedded CSS parser. Upstream in templ-ts-mode.
- Investigated: Indentation hardcodes `indent-tabs-mode t` — should be user's choice, not forced. Upstream in templ-ts-mode.

### Upstream (templ-ts-mode PRs)
- [ ] Fix css_declaration closing brace indentation — needs a rule like `((node-is "}") (parent-is "css_declaration") parent-bol 0)` added to `templ-ts--indent-rules` in templ-ts-mode.el (currently only has `((parent-is "css_declaration") parent-bol go-ts-mode-indent-offset)` which indents the brace like a property)
- [ ] Fix `<script>` HTML element JS support — `templ-ts--treesit-update-ranges` only queries `(script_block_text)` (templ-native `script funcName() { }` blocks, which work) but not `(script_element_text)` (HTML `<script>` tags, which get no JS parsing/fontification/indentation)
- [ ] Embed CSS parser for `<style>` elements — `style_element_text` is opaque text, needs `treesit-range-rules` with `:embed 'css` like the JS setup does for `script_block_text`
- [ ] Don't hardcode `indent-tabs-mode t` — should respect user preference, not force tabs

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
- [x] Next element (`web-mode-element-next`) — fixed: gap-aware navigation stays at current level, never descends into children
- [x] Previous element (`web-mode-element-previous`) — fixed: gap-aware navigation stays at current level, never descends into children
- [x] Element kill (`web-mode-element-kill`)
- [x] Element vanish (`web-mode-element-vanish`) — unwrap with cleanup and re-indent
- [x] Select element content (`web-mode-element-content-select`)
- [x] Element clone (`web-mode-element-clone`)
- [x] Element close (`web-mode-element-close`) — context-aware with partial name completion
- [x] Mark-and-expand — progressive structural selection (attribute → element → parent content → parent → ceiling)
- [x] Attribute auto-quoting (`foo=` → `foo="|"`) — toggleable via `templ-ts-web-attr-auto-quote`
- [x] Keybindings with web-mode-compatible defaults (`C-c C-e` prefix, `C-c C-m` for mark-and-expand)
- [x] Configuration via `defcustom` — `templ-ts-web-element-auto-close`, `templ-ts-web-element-auto-complete`, `templ-ts-web-attr-auto-quote`
- [x] GitHub publish — README, LICENSE, package headers, remote repo at github.com/ekenberg/templ-ts-web-mode
