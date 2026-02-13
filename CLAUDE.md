# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Emacs Lisp minor mode that ports selected web-mode features — piece by piece — to work on top of templ-ts-mode. Uses tree-sitter for structural awareness of templ (Go templating language) files. Feature set is driven by actual editing needs, not by completeness — we cherry-pick the good stuff from web-mode, not replicate it wholesale.

## Development Commands

**IMPORTANT**: Always use `/usr/bin/emacs` (full path) when running Emacs from the command line. The user has a wrapper script in `~/local/bin/emacs` that does extra setup — batch-mode commands must bypass it.

### Running Tests

Tests use ERT (Emacs Lisp Regression Testing). Run from command line:

```bash
/usr/bin/emacs -batch -l templ-ts-web-mode-tests.el -f ert-run-tests-batch-and-exit
```

Or from within Emacs:

```elisp
;; Load the test file
(load-file "templ-ts-web-mode-tests.el")

;; Run all tests
(ert t)

;; Run specific test
(ert 'ttwt-auto-close-div)

;; Run tests matching pattern
(ert "ttwt-auto-close")
```

## Architecture

### Tree-sitter Integration

The mode relies on a templ tree-sitter parser being active. Core pattern:

1. `post-self-insert-hook` functions catch key presses (`>`, `/`)
2. `treesit-update-ranges` forces immediate re-parse
3. Query tree-sitter AST at point to determine context
4. Insert appropriate closing tags/completions

### Text-based Tag Counting Strategy

Key insight: tree-sitter produces ERROR nodes for incomplete markup during typing, making AST-based tag matching unreliable. Both auto-close (`>`) and auto-complete (`</`) use text-based regex scanning within the `component_block` scope instead:

- `templ-ts-web--tag-is-unclosed-p`: Counts `<name...>` opens vs `</name>` closes to decide if a known tag needs closing
- `templ-ts-web--find-unclosed-tag-name`: Forward-scans from scope start to point, tracking an open/close stack to find the innermost unclosed tag name
- `templ-ts-web--ancestor-of-type`: Walks up AST to find the enclosing `component_block` (scope boundary for text scanning)

### Test Helpers

Tests wrap content in minimal valid templ component syntax (`package main\ntempl test() { ... }`) since the tree-sitter parser expects valid templ structure. The `ttwt--templ-buffer` helper manages this wrapper and adjusts point positions accordingly.
