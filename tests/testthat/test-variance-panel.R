# variance-components surface, Slice 3 (widget panel).
# Spec: docs/specs/variance-components.md (S3) + contract clause 5.
#
# three_views_variance_panel(x) returns the "where does the variation live?"
# HTML panel for the three-views Index tab: a CSS-div bar (auto-selected --
# a single stacked between/within bar for exactly 2 components, per-component
# bars for 3+), one sentence, and the ICC line. No bar when the residual /
# ICC is undefined (Poisson, location-scale); instead the "not available on
# this scale yet" line. Returns "" when the fit has no random effects.

test_that("no random effects -> empty panel (nothing to partition)", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_location_scale())  # no (1 | group)
  expect_identical(three_views_variance_panel(symbolize(fit)), "")
})

test_that("Gaussian single-RE panel shows a stacked bar, a sentence and the ICC", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::lmer(
    Reaction ~ Days + (1 | Subject), data = lme4::sleepstudy))
  html <- three_views_variance_panel(symbolize(fit))

  expect_match(html, "variation", ignore.case = TRUE)        # the sentence
  expect_match(html, "sym-vc-stacked")                       # option A bar
  expect_no_match(html, "sym-vc-bars")                       # not per-component
  expect_match(html, "ICC")
  expect_match(html, "data scale", ignore.case = TRUE)
})

test_that("binomial single-RE panel labels the ICC as latent with the caption", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::glmer(
    cbind(incidence, size - incidence) ~ period + (1 | herd),
    data = lme4::cbpp, family = binomial))
  html <- three_views_variance_panel(symbolize(fit))

  expect_match(html, "sym-vc-stacked")                       # 2 components -> A
  expect_match(html, "latent", ignore.case = TRUE)
  expect_match(html, "observed outcome", ignore.case = TRUE) # mandatory caption
})

test_that("Poisson panel shows no bar and the not-available line", {
  skip_if_not_installed("lme4")
  d <- lme4::cbpp
  set.seed(1L)
  d$cnt <- stats::rpois(nrow(d), 3)
  fit <- suppressWarnings(lme4::glmer(
    cnt ~ period + (1 | herd), data = d, family = poisson))
  html <- three_views_variance_panel(symbolize(fit))

  expect_no_match(html, "sym-vc-bar")                        # no bar at all
  expect_match(html, "not available on this scale yet", ignore.case = TRUE)
})

test_that("3-component fit uses per-component bars, not a stacked bar", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::lmer(
    diameter ~ (1 | plate) + (1 | sample), data = lme4::Penicillin))
  html <- three_views_variance_panel(symbolize(fit))

  expect_match(html, "sym-vc-bars")                          # option B
  expect_no_match(html, "sym-vc-stacked")
})

test_that("the variance panel is injected into the full Index-tab widget", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_re_homosked())
  widget <- as_html_three_views(symbolize(fit))
  expect_match(widget, "sym-vc-panel")
  expect_match(widget, "ICC")
})
