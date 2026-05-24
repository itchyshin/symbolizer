# Agent operating instructions for symbolizer

This file is the entry point for any agent (Claude Code, Codex CLI,
others) working on this package. Claude Code reads `CLAUDE.md` which
imports this file via `@AGENTS.md`. Codex CLI reads this file directly.

## Where to read

| If you need...                                 | Read |
| ---------------------------------------------- | --- |
| Long-term direction / mission / what we are NOT | `.github/VISION.md` |
| Standing project memory — team roster, conventions, hard rules | `.memory/MEMORY.md` |
| Open design notes for upcoming work             | `.memory/designs/` |
| Most recent session report                      | `.memory/reports/` (latest dated file) |
| Version history                                 | `NEWS.md` |
| How to contribute (humans)                      | `CONTRIBUTING.md` |
| User-facing entry                               | `README.md` |
| The R package code                              | `R/`, `inst/`, `tests/`, `vignettes/` |

The `.memory/` tree is gitignored and machine-local — it persists across
sessions on this machine but never ships with the package and never
reaches GitHub.

## Architectural rules

- `symbolized_model` is the product. All renderers consume it; no
  renderer parses formulas itself.
- Every prose output comes from a template in `inst/extdata/*.csv`. No
  LLM-generated prose at runtime.
- The term-grammar bridge (`R/extract-terms.R`) is the prerequisite for
  every renderer. Changes there require snapshot tests covering: factor
  contrasts, two-way interactions, offsets, `scale()` / `log()` / `I()`
  transforms, random-effect groupings.
- The capability registry (`inst/extdata/capabilities.csv`) gates
  `symbolize()`. New `(class, family, component)` tuples must have a row
  with one of: `Stable` / `First slice` / `Opt-in control` / `Planned or
  reserved` / `Unsupported or blocked`.

## Code conventions

- Files in `R/`: kebab-case, grouped by topic (`render-*.R`,
  `symbolize-*.R`, `extract-*.R`, `compare-*.R`).
- Functions: `snake_case`.
- Messages: `cli::cli_abort()`, `cli::cli_inform()`, `cli::cli_warn()`
  with `{.fn}`, `{.arg}`, `{.code}` interpolation.
- Documentation: roxygen2 v8.0.0 with `Roxygen: list(markdown = TRUE)`;
  `\eqn{...}` for inline math.
- Tests: testthat edition 3 + snapshot tests + helper fixtures in
  `tests/testthat/helper-*.R`.
- S3 only. Methods dispatch on the fitted-object class (e.g.,
  `symbolize.drmTMB`, `as_latex.symbolized_model`).

## Development discipline

- Run `devtools::test()` and `devtools::check()` locally before pushing.
- Run `pkgdown::build_site()` locally before any push that adds an
  `@export` tag or a vignette.
- Prefer small, reviewable changes.
- Cite files and commands when making claims about the repository.

## Session reports

When a session finishes a meaningful batch of work (one slice landed,
or several slices in an autonomous run), write a session report to
`.memory/reports/YYYY-MM-DD-<short-tag>.md`. Do not overwrite prior
reports.
