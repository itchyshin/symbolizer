# Tests for drm_strip_re_terms — the helper that strips lme4-style
# `(... | g)` random-effect bars from a formula RHS so the term parser
# (stats::model.frame) sees only the fixed-effect skeleton.
#
# Pre-v0.21-redo the helper used a regex that explicitly rejected inner
# parens, so brms's `(1 | gr(species, cov = A))` survived the strip and
# crashed model.frame with "could not find function 'gr'". The
# nested-paren cases in this file lock in correct behavior.

deparse_one <- function(x) paste(deparse(x), collapse = " ")

test_that("drm_strip_re_terms removes a flat random intercept", {
  e <- quote(temperature + (1 | g))
  out <- drm_strip_re_terms(e)
  expect_equal(deparse_one(out), "temperature")
})

test_that("drm_strip_re_terms collapses intercept-only-RE to '1'", {
  e <- quote((1 | g))
  out <- drm_strip_re_terms(e)
  expect_equal(deparse_one(out), "1")
})

test_that("drm_strip_re_terms removes a random slope", {
  e <- quote(x + (1 + z | g))
  out <- drm_strip_re_terms(e)
  expect_equal(deparse_one(out), "x")
})

test_that("drm_strip_re_terms removes brms-style gr(group, cov = A)", {
  # The nested-paren case that previously crashed model.frame.
  e <- quote(1 + (1 | gr(species, cov = A)))
  out <- drm_strip_re_terms(e)
  expect_equal(deparse_one(out), "1")
})

test_that("drm_strip_re_terms removes brms-style gr() alongside fixed effects", {
  e <- quote(temperature + (1 | gr(species, cov = A)))
  out <- drm_strip_re_terms(e)
  expect_equal(deparse_one(out), "temperature")
})

test_that("drm_strip_re_terms removes multiple RE bars including nested-paren", {
  e <- quote(x + (1 | g) + (1 | gr(species, cov = A)))
  out <- drm_strip_re_terms(e)
  expect_equal(deparse_one(out), "x")
})

test_that("drm_strip_re_terms removes drmTMB-style phylo(... | species)", {
  # phylo() / animal() markers are handled separately by drm_strip_markers
  # in symbolize-drmtmb.R; drm_strip_re_terms shouldn't touch a non-
  # bar-form RE marker. But once markers are stripped (call("(", ...)),
  # the result IS a (...) wrapped | expression and must be removed.
  e <- quote(y_obs + (1 | species))  # after marker strip, this is what's left
  out <- drm_strip_re_terms(e)
  expect_equal(deparse_one(out), "y_obs")
})
