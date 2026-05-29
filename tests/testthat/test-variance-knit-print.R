# variance-components surface, Slice 5 (knit_print for the accessors).
# Spec: docs/specs/variance-components.md (S5).
#
# variance_partition() and icc() must render as clean `asis` HTML in a knitted
# vignette -- the bar + a numbers table for the partition, the scale-labelled
# reading + caption for the ICC -- reusing the S3 helpers so the bar travels
# outside the drmTMB-only three-views widget.

test_that("knit_print(variance_partition) is asis HTML with the bar + a numbers table", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("knitr")
  fit <- suppressWarnings(lme4::lmer(
    Reaction ~ Days + (1 | Subject), data = lme4::sleepstudy))
  out <- knitr::knit_print(variance_partition(symbolize(fit)))
  txt <- paste(as.character(out), collapse = "\n")

  expect_s3_class(out, "knit_asis")
  expect_match(txt, "sym-vc-stacked")              # the auto bar (2 components)
  expect_match(txt, "variation", ignore.case = TRUE)  # the intro sentence
  expect_match(txt, "<table")                      # the numbers table
  # The bar helpers indent their <div> rows; pandoc treats 4+ leading spaces
  # as a code block and escapes the HTML as literal text. The emission must be
  # collapsed to one line so no newline-then-4-spaces-then-tag pattern remains.
  expect_no_match(txt, "\n[[:space:]]{4,}<")
})

test_that("knit_print(icc) renders the scale-labelled reading + latent caption", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("knitr")
  fit <- suppressWarnings(lme4::glmer(
    cbind(incidence, size - incidence) ~ period + (1 | herd),
    data = lme4::cbpp, family = binomial))
  out <- knitr::knit_print(icc(symbolize(fit)))
  txt <- paste(as.character(out), collapse = "\n")

  expect_s3_class(out, "knit_asis")
  expect_match(txt, "ICC")
  expect_match(txt, "latent", ignore.case = TRUE)
  expect_match(txt, "observed outcome", ignore.case = TRUE)
})

test_that("knit_print(icc) shows the 'not available' line for Poisson", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("knitr")
  d <- lme4::cbpp
  set.seed(1L)
  d$cnt <- stats::rpois(nrow(d), 3)
  fit <- suppressWarnings(lme4::glmer(
    cnt ~ period + (1 | herd), data = d, family = poisson))
  out <- knitr::knit_print(icc(symbolize(fit)))
  txt <- paste(as.character(out), collapse = "\n")
  expect_match(txt, "not available on this scale yet", ignore.case = TRUE)
})
