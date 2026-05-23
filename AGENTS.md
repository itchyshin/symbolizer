# Agent operating instructions for symbolizer

## Project memory

If a `.memory/` directory exists, read `.memory/MEMORY.md` before starting non-trivial work. Otherwise, treat the design plan referenced in issues or PR descriptions as the source of truth.

## Architectural rules

- `symbolized_model` is the product. All renderers consume it; no renderer parses formulas itself.
- Every prose output comes from a template in `inst/extdata/*.csv`. No LLM-generated prose at runtime.
- The term-grammar bridge (`R/extract-terms.R`) is the prerequisite for every renderer. Changes there require snapshot tests covering: factor contrasts, two-way interactions, offsets, `scale()`/`log()`/`I()` transforms, random-effect groupings.
- The capability registry (`inst/extdata/capabilities.csv`) gates `symbolize()`. New `(class, family, component)` tuples must have a row with one of: Stable / First slice / Opt-in control / Planned or reserved / Unsupported or blocked.

## Code conventions

- Files in `R/`: kebab-case, grouped by topic (`render-*.R`, `symbolize-*.R`, `extract-*.R`, `compare-*.R`).
- Functions: `snake_case`.
- Messages: `cli::cli_abort()`, `cli::cli_inform()`, `cli::cli_warn()` with `{.fn}`, `{.arg}`, `{.code}` interpolation.
- Documentation: roxygen2 v8.0.0 with `Roxygen: list(markdown = TRUE)`; `\eqn{...}` for inline math.
- Tests: testthat edition 3 + snapshot tests + helper fixtures in `tests/testthat/helper-*.R`.
- S3 only. Methods dispatch on the fitted-object class (e.g., `symbolize.drmTMB`, `as_latex.symbolized_model`).

## Development discipline

- Run `devtools::test()` and `devtools::check()` locally before pushing.
- Prefer small, reviewable changes.
- Cite files and commands when making claims about the repository.
