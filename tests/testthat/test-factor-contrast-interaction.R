# E3 / P7: a factor contrast whose factor participates in an interaction is the
# group difference at the interacting predictor's reference (0), NOT the
# marginal average. The biological reading must say so (and point to the
# marginal tools) instead of claiming an unconditional "Average ... differs".

test_that("factor_contrast reading is interaction-aware when the factor interacts (E3)", {
  set.seed(1)
  d <- data.frame(y = rnorm(120), x = rnorm(120),
                  sex = factor(sample(c("F", "M"), 120, TRUE)))
  # Match both "factor_contrast" and the interaction-aware
  # "factor_contrast_interaction" coefficient_role.
  fc_read <- function(fit) {
    pii <- parameter_interpretation(symbolize(fit), scale = "biological")
    pii$biological_reading[grepl("factor_contrast", pii$coefficient_role)]
  }
  read_int  <- fc_read(lm(y ~ x * sex, data = d))   # sex interacts with x
  read_main <- fc_read(lm(y ~ x + sex, data = d))   # sex does not interact

  expect_true(length(read_int) >= 1L)
  # Interacting: NOT the unconditional "Average ... differs" claim; must flag
  # the interaction.
  expect_false(any(grepl("^Average", read_int)))
  expect_true(any(grepl("interact", read_int)))
  # Non-interacting: the plain marginal reading is unchanged.
  expect_true(any(grepl("^Average", read_main)))
})
