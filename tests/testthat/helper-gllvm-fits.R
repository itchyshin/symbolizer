# Helper: build the canonical gllvmTMB Gaussian latent-variable fits used
# across symbolize.gllvmTMB tests. Skips the calling test if gllvmTMB is not
# installed.

.glllvm_with_keywords <- function(call_expr) {
  # gllvmTMB's formula parser expects the bare `latent` / `unique` keywords
  # from its attached namespace. Build a small environment that resolves
  # them, drop it in front of the formula's lexical scope, and evaluate.
  e <- new.env(parent = parent.frame())
  e$latent <- get("latent", envir = asNamespace("gllvmTMB"))
  e$`unique` <- get("unique", envir = asNamespace("gllvmTMB"))
  eval(call_expr, envir = e)
}

fit_gllvm_basic <- function(seed = 1L) {
  testthat::skip_if_not_installed("gllvmTMB")
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 6, n_traits = 3,
    mean_species_per_site = 3, n_predictors = 1,
    Lambda_B = matrix(c(0.5, 0.3, -0.2), nrow = 3)
  )
  .glllvm_with_keywords(quote(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1),
      data   = sim$data,
      family = stats::gaussian(),
      trait  = "trait",
      unit   = "site",
      silent = TRUE
    )
  ))
}

fit_gllvm_with_unique <- function(seed = 1L) {
  testthat::skip_if_not_installed("gllvmTMB")
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 6, n_traits = 3,
    mean_species_per_site = 3, n_predictors = 1,
    Lambda_B = matrix(c(0.5, 0.3, -0.2), nrow = 3),
    psi_B = c(0.2, 0.2, 0.2)
  )
  .glllvm_with_keywords(quote(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1) +
        `unique`(0 + trait | site),
      data   = sim$data,
      family = stats::gaussian(),
      trait  = "trait",
      unit   = "site",
      silent = TRUE
    )
  ))
}

fit_gllvm_poisson <- function(seed = 1L) {
  testthat::skip_if_not_installed("gllvmTMB")
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 6, n_traits = 3,
    mean_species_per_site = 3, n_predictors = 1,
    Lambda_B = matrix(c(0.5, 0.3, -0.2), nrow = 3)
  )
  sim$data$count <- as.integer(round(abs(sim$data$value) * 5))
  .glllvm_with_keywords(quote(
    gllvmTMB::gllvmTMB(
      count ~ 0 + trait + latent(0 + trait | site, d = 1),
      data   = sim$data,
      family = stats::poisson(),
      trait  = "trait",
      unit   = "site",
      silent = TRUE
    )
  ))
}

fit_gllvm_binomial <- function(seed = 1L) {
  testthat::skip_if_not_installed("gllvmTMB")
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 5, n_traits = 3,
    mean_species_per_site = 3, n_predictors = 1,
    Lambda_B = matrix(c(0.5, 0.3, -0.2), nrow = 3)
  )
  sim$data$pres <- as.integer(sim$data$value > 0)
  gllvmTMB::gllvmTMB(
    pres ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data, family = stats::binomial(),
    trait = "trait", unit = "site", silent = TRUE
  )
}

fit_gllvm_two_tier <- function(seed = 20260523L) {
  testthat::skip_if_not_installed("gllvmTMB")
  set.seed(seed)
  n_ind  <- 40L; n_sess <- 3L; n_tr <- 5L
  Lam_B <- matrix(c(1.0, 0.0, 0.7, 0.0, 0.6, 0.0,
                    0.0, 1.0, 0.0, 0.7),
                  nrow = n_tr, byrow = TRUE)
  psi_B   <- rep(0.4, n_tr); sig_eps <- sqrt(0.3)
  z_score <- matrix(rnorm(n_ind * 2L), nrow = n_ind, ncol = 2L)
  psi_B_resid <- matrix(rnorm(n_ind * n_tr,
                              sd = rep(sqrt(psi_B), each = n_ind)),
                        nrow = n_ind, ncol = n_tr)
  mu_ind_trait <- z_score %*% t(Lam_B) + psi_B_resid
  dat <- expand.grid(
    trait      = factor(paste0("t", seq_len(n_tr)),
                        levels = paste0("t", seq_len(n_tr))),
    session    = factor(seq_len(n_sess)),
    individual = factor(seq_len(n_ind))
  )
  dat$value <- mu_ind_trait[cbind(as.integer(dat$individual),
                                   as.integer(dat$trait))] +
                rnorm(nrow(dat), sd = sig_eps)
  dat$obs <- factor(paste(dat$individual, dat$session, sep = "_"))
  .glllvm_with_keywords(quote(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              latent(0 + trait | individual, d = 2) +
              `unique`(0 + trait | individual) +
              latent(0 + trait | obs, d = 1) +
              `unique`(0 + trait | obs),
      data     = dat,
      family   = stats::gaussian(),
      trait    = "trait",
      unit     = "individual",
      unit_obs = "obs",
      cluster  = "session",
      silent   = TRUE
    )
  ))
}
