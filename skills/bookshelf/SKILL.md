---
name: bookshelf
description: Consult a local reference bookshelf (EPUBs) for authoritative, quotable guidance — the "how/why" that primary sources cover better than memory. Load before asserting a language/framework convention, an OO or refactoring call, a testing approach, or a database behavior, when you have reference books on disk. Reads books in place from $TOMES_DIR; quote the source line you rely on. Stack-agnostic.
---

# Bookshelf

Read your own reference books (EPUBs) in place to ground judgment in primary sources instead of
memory. This is the **deeper-references** shelf — distinct from any framework's live docs/MCP guides
(which cover an API's current surface). Use it to *cite* a design/idiom call, not to look up this
project's facts.

## The reader
`${CLAUDE_PLUGIN_ROOT}/tools/tome.sh` (EPUB = zip; text is de-tagged on the way out):
```
tome.sh list                      # every book across the configured shelves
tome.sh find <name>               # locate a book by fuzzy name
tome.sh toc <book>                # clean table of contents
tome.sh search <book> <regex>     # grep the book, with context
tome.sh chapter <book> <toc-text> # print the section whose TOC entry matches
```
`<book>` is a fuzzy fragment (first match wins); quote multi-word names.

## Where the books come from (BYO — never shipped)
Books are **your own copies** — nothing is bundled or committed (they're copyrighted; only the reader
travels). Point the reader at your shelf with **`TOMES_DIR`** (colon-separated dirs). Set it once per
machine via your config home's `env` block (the harness installer's user step can do this):
```jsonc
// ~/.claude/settings.json (or ~/.claude-work — honors CLAUDE_CONFIG_DIR)
{ "env": { "TOMES_DIR": "/Users/you/books:/Users/you/Documents/books" } }
```
Unset, `tome.sh` falls back to common shelves (`~/Documents/books`, `~/books`, Apple Books,
iCloud Downloads). If a book isn't there, say so — don't invent its contents.

## How to use it
Before asserting a convention/idiom/behavior that a reference book would settle:
1. `tome.sh find` / `toc` the relevant book, then `search` / `chapter` for the specifics.
2. **Quote the source line** you relied on. If the book isn't on the shelf, note that and fall back to
   the framework's live docs or an explicit "unverified" label.
