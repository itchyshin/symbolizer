# Contributing to symbolizer

`symbolizer` is pre-CRAN and pre-1.0. Contributions are welcome but should respect the package's pace and scope.

## Definition of Done

A change is "done" when all of the following are true:

- **Implementation**: code lives in a `R/*.R` file matching the existing kebab-case naming.
- **Tests**: at least one test in `tests/testthat/test-*.R`. Snapshot tests for any LaTeX or rendered output.
- **Documentation**: roxygen2 block with `@param`, `@return`, and at least one `@examples` block.
- **Capability registry**: any new `(class, family, component)` tuple is added to `inst/extdata/capabilities.csv` with one of the five status words (Stable / First slice / Opt-in control / Planned or reserved / Unsupported or blocked).
- **Templates over splicing**: any new user-facing prose is added as a row in `inst/extdata/*.csv`. Do not write string-spliced sentences in `R/`.
- **Local checks**: `devtools::check()` is clean on macOS or Linux.
- **Design link**: if the change touches the `symbolized_model` structure or a renderer's public output, reference the relevant section of the design plan.

## Local development

```r
devtools::load_all()
devtools::test()
devtools::check()
devtools::document()
pkgdown::build_site()
```

Prefer local checks over CI. GitHub Actions runs Linux-only:

- **R-CMD-check** on pull request and `workflow_dispatch` (unchanged).
- **test-coverage** on pull requests and pushes to `main` that touch `R/`, `inst/`, `tests/`, `DESCRIPTION`, `NAMESPACE`, or the coverage workflows. It runs the existing testthat suite under `covr::package_coverage()` and prints `COVERAGE_PERCENT` in the job log. It does not upload.
- **Upload main coverage** runs only after a successful `test-coverage` **push** to `main`, using GitHub OIDC (no `CODECOV_TOKEN`). A default-branch Codecov baseline therefore exists only after an owner-authorized merge plus that producer/upload pair.

Coverage statuses in `codecov.yml` are informational; they do not replace `R-CMD-check`. There is no coverage badge until a processed default-branch report exists.


## Reporting issues

Issues at <https://github.com/itchyshin/symbolizer/issues>. Please include a minimal reproducible example.
