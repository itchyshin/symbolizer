# Tests for group_contrasts() -- pairwise / vs-reference factor comparisons.
# Uses lm / glm fixtures so the suite runs without Suggests-only fit packages;
# emmeans is the only requirement.

skip_if_no_emmeans <- function() skip_if_not_installed("emmeans")

gc_gaussian_fit <- function() {
  set.seed(1)
  d <- data.frame(
    y    = rnorm(60),
    site = factor(rep(c("A", "B", "C"), 20)),
    sex  = factor(rep(c("f", "m"), 30))
  )
  symbolize(lm(y ~ site + sex, data = d))
}

test_that("pairwise on a 3-level factor returns one row per pair", {
  skip_if_no_emmeans()
  gc <- group_contrasts(gc_gaussian_fit(), by = "site")
  expect_s3_class(gc, "symbolizer_group_contrasts")
  expect_equal(nrow(gc), 3L)
  expect_setequal(gc$contrast, c("A - B", "A - C", "B - C"))
})

test_that("trt.vs.ctrl returns one row per non-reference level", {
  skip_if_no_emmeans()
  gc <- group_contrasts(gc_gaussian_fit(), by = "site", method = "trt.vs.ctrl")
  expect_equal(nrow(gc), 2L)
})

test_that("a 2-level factor yields a single contrast", {
  skip_if_no_emmeans()
  gc <- group_contrasts(gc_gaussian_fit(), by = "sex")
  expect_equal(nrow(gc), 1L)
})

test_that("no p-value column is ever produced", {
  skip_if_no_emmeans()
  gc <- group_contrasts(gc_gaussian_fit(), by = "site")
  expect_false("p.value" %in% names(gc))
  expect_false("t.ratio" %in% names(gc))
})

test_that("the contrast estimate recovers the difference of group means", {
  skip_if_no_emmeans()
  sym <- gc_gaussian_fit()
  gm <- group_means(sym, by = "site")
  gc <- group_contrasts(sym, by = "site")
  a_minus_b <- gc$estimate[gc$contrast == "A - B"]
  mean_a <- gm$estimate[gm$site == "A"]
  mean_b <- gm$estimate[gm$site == "B"]
  expect_equal(a_minus_b, mean_a - mean_b, tolerance = 1e-6)
})

test_that("Tukey adjustment widens the band without adding a p-value", {
  skip_if_no_emmeans()
  sym <- gc_gaussian_fit()
  g_none <- group_contrasts(sym, by = "site", adjust = "none")
  g_tuk  <- group_contrasts(sym, by = "site", adjust = "tukey")
  width_none <- g_none$confint_high - g_none$confint_low
  width_tuk  <- g_tuk$confint_high - g_tuk$confint_low
  expect_true(all(width_tuk >= width_none - 1e-8))
  expect_false("p.value" %in% names(g_tuk))
})

test_that("within = stratifies the contrasts by another factor's levels", {
  skip_if_no_emmeans()
  set.seed(3)
  d <- data.frame(
    y    = rnorm(60),
    site = factor(rep(c("A", "B", "C"), 20)),
    sex  = factor(rep(c("f", "m"), 30))
  )
  sym <- symbolize(lm(y ~ site * sex, data = d))
  gc <- group_contrasts(sym, by = "site", within = "sex")
  # 3 pairwise contrasts x 2 sex levels
  expect_equal(nrow(gc), 6L)
  expect_true("sex" %in% names(gc))
})

test_that("log-link response scale reports ratios with null = 1", {
  skip_if_no_emmeans()
  set.seed(4)
  d <- data.frame(cnt = rpois(60, 5), site = factor(rep(c("A", "B", "C"), 20)))
  sym <- symbolize(glm(cnt ~ site, family = poisson, data = d))
  gc <- group_contrasts(sym, by = "site", scale = "response")
  expect_equal(unique(gc$effect_type), "ratio")
  expect_true(all(gc$estimate > 0))
  expect_true(all(grepl("/", gc$contrast)))   # "A / B" style ratio labels
})

test_that("link scale reports additive differences", {
  skip_if_no_emmeans()
  set.seed(5)
  d <- data.frame(cnt = rpois(60, 5), site = factor(rep(c("A", "B", "C"), 20)))
  sym <- symbolize(glm(cnt ~ site, family = poisson, data = d))
  gc <- group_contrasts(sym, by = "site", scale = "link")
  expect_equal(unique(gc$effect_type), "difference")
  expect_true(all(grepl(" - ", gc$contrast)))
})

test_that("a model with no factors errors helpfully", {
  skip_if_no_emmeans()
  sym <- symbolize(lm(mpg ~ wt, data = mtcars))
  expect_error(group_contrasts(sym), "no factors")
})

test_that("unknown factor names error", {
  skip_if_no_emmeans()
  expect_error(group_contrasts(gc_gaussian_fit(), by = "nope"), "Unknown factor")
})

test_that("group_contrasts.default rejects non-symbolized input", {
  expect_error(group_contrasts(list()), "no method")
})

test_that("print method names the method and the null", {
  skip_if_no_emmeans()
  set.seed(6)
  d <- data.frame(cnt = rpois(60, 5), site = factor(rep(c("A", "B", "C"), 20)))
  sym <- symbolize(glm(cnt ~ site, family = poisson, data = d))
  gc <- group_contrasts(sym, by = "site", scale = "response")
  expect_snapshot(print(gc))
})
