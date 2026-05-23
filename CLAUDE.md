# Claude Code project instructions for symbolizer

@AGENTS.md

## symbolizer-specific notes

- **Architectural rule**: every prose output is templated from `inst/extdata/*.csv`. Never write string-spliced prose in `R/`.
- **Term-grammar bridge** in `R/extract-terms.R` is first-priority infrastructure; tests come before implementation.
- Match drmTMB and gllvmTMB code conventions: kebab-case files, snake_case functions, `cli::cli_*` messaging, roxygen2 markdown, testthat 3 + snapshots.
- For any new `(class, family, component)` tuple, add a row to `inst/extdata/capabilities.csv` with one of the five status words **before** exporting a method.
- The fitted-object source of truth for the v0.1 extractor is `R/symbolize-drmtmb.R` — the header comments document the real `drmTMB` object shape (`fit$formula$entries`, `fixef(fit, dpar)`, `fit$family$family`, etc.).
