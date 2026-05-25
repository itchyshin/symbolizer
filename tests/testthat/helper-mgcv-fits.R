# Helper fits for symbolize.gam tests (mgcv + gamm + gamm4).

fit_gam_simple <- function(seed = 1L, n = 200L) {
  testthat::skip_if_not_installed("mgcv")
  set.seed(seed)
  x <- runif(n)
  z <- runif(n)
  y <- 2 + sin(2 * pi * x) + 0.5 * z + rnorm(n, 0, 0.3)
  mgcv::gam(y ~ s(x) + z, data = data.frame(y = y, x = x, z = z),
            method = "REML")
}

fit_gam_by <- function(seed = 2L, n = 300L) {
  testthat::skip_if_not_installed("mgcv")
  set.seed(seed)
  x <- runif(n)
  g <- factor(sample(c("A", "B"), n, replace = TRUE))
  y <- 2 + sin(2 * pi * x) * (g == "A") + cos(2 * pi * x) * (g == "B") +
    rnorm(n, 0, 0.3)
  mgcv::gam(y ~ s(x, by = g) + g,
            data = data.frame(y = y, x = x, g = g), method = "REML")
}

fit_gam_te <- function(seed = 3L, n = 300L) {
  testthat::skip_if_not_installed("mgcv")
  set.seed(seed)
  x <- runif(n)
  z <- runif(n)
  y <- 2 + sin(2 * pi * x) * cos(2 * pi * z) + rnorm(n, 0, 0.3)
  mgcv::gam(y ~ te(x, z), data = data.frame(y = y, x = x, z = z),
            method = "REML")
}

# gamm fit -- returns a list with $gam and $lme. We symbolize the
# $gam slot (documented in symbolize.gam).
fit_gamm_simple <- function(seed = 4L, n = 200L, n_groups = 10L) {
  testthat::skip_if_not_installed("mgcv")
  set.seed(seed)
  g <- factor(rep(seq_len(n_groups), length.out = n))
  group_effect <- rnorm(n_groups, 0, 0.5)[as.integer(g)]
  x <- runif(n)
  y <- 2 + sin(2 * pi * x) + group_effect + rnorm(n, 0, 0.3)
  out <- suppressWarnings(suppressMessages(
    mgcv::gamm(y ~ s(x), random = list(g = ~ 1),
               data = data.frame(y = y, x = x, g = g))
  ))
  out$gam
}

# gamm4 fit -- only run if gamm4 is installed. Returns a list with
# $gam and $mer; we symbolize $gam.
fit_gamm4_simple <- function(seed = 5L, n = 200L, n_groups = 10L) {
  testthat::skip_if_not_installed("mgcv")
  testthat::skip_if_not_installed("gamm4")
  set.seed(seed)
  g <- factor(rep(seq_len(n_groups), length.out = n))
  group_effect <- rnorm(n_groups, 0, 0.5)[as.integer(g)]
  x <- runif(n)
  y <- 2 + sin(2 * pi * x) + group_effect + rnorm(n, 0, 0.3)
  out <- suppressWarnings(suppressMessages(
    gamm4::gamm4(y ~ s(x), random = ~ (1 | g),
                 data = data.frame(y = y, x = x, g = g))
  ))
  out$gam
}
