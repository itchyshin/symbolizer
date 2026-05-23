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
