# Reusable test fixtures for extract_terms() snapshot tests.
# Each helper returns a small data frame designed to exercise a specific
# feature of the term-grammar / model-matrix bridge.

fx_continuous_pair <- function() {
  # All-positive z so log(z) is valid downstream.
  data.frame(
    y = 1:8,
    x = seq(-3, 4, by = 1),
    z = seq(1, 8, by = 1)
  )
}

fx_two_level_factor <- function() {
  data.frame(
    y = 1:6,
    sex = factor(rep(c("female", "male"), 3))
  )
}

fx_three_level_factor <- function() {
  data.frame(
    y = 1:9,
    site = factor(rep(c("A", "B", "C"), 3), levels = c("A", "B", "C"))
  )
}

fx_cont_factor <- function() {
  data.frame(
    y = 1:8,
    x = seq(-2, 5, by = 1),
    sex = factor(rep(c("female", "male"), 4))
  )
}

fx_with_offset <- function() {
  data.frame(
    y = 1:5,
    x = 1:5,
    exposure = c(1, 2, 4, 8, 16)
  )
}
