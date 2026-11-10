#' Simulation recipe for a symbolized model
#'
#' @description
#' Returns a structured recipe -- pseudocode + runnable R code --
#' explaining how to simulate data *from* a fitted model. The recipe
#' is family-aware: it picks the right RNG (`rnorm`, `rbinom`,
#' `rpois`, `rgamma`, `rnbinom`, ...) and lists the draws in the
#' right order (random effects first, then linear predictor, then
#' response).
#'
#' The returned object is an S3 list with `pseudocode` (character
#' vector, one element per step) and `r_code` (single character
#' string, ready to `eval(parse(text = ...))`). `print()` formats it
#' for the console; `knit_print()` formats it as a fenced R code
#' block plus a numbered pseudocode list.
#'
#' This is a teaching surface: the recipe shows the **generative
#' model**, not the inferential machinery. For a real simulation
#' that round-trips through the fitted-model object's internals
#' (sampling from posterior, properly propagating uncertainty), the
#' relevant package's own `simulate()` / `posterior_predict()` /
#' `predict()` interface is the right tool.
#'
#' @param x A [`symbolized_model`][new_symbolized_model].
#' @param n Optional integer; if supplied, the R code uses `n`
#'   observations. Defaults to `sym$model$n_obs`.
#' @param seed Optional integer; if supplied, the R code begins with
#'   `set.seed(seed)`.
#' @param ... Reserved for future use.
#'
#' @return A list of class `symbolizer_simulation_recipe` with
#'   `pseudocode` and `r_code` character slots, plus `metadata` for
#'   the family and submodel decomposition.
#'
#' @export
simulate_recipe <- function(x, n = NULL, seed = NULL, ...) {
  UseMethod("simulate_recipe")
}

#' @export
simulate_recipe.default <- function(x, n = NULL, seed = NULL, ...) {
  cli::cli_abort(c(
    "{.fn simulate_recipe} has no method for {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
simulate_recipe.symbolized_model <- function(x, n = NULL, seed = NULL, ...) {
  family <- x$model$family %||% "gaussian"
  response <- x$model$response %||% "y"
  n_obs <- as.integer(n %||% x$model$n_obs %||% 100L)

  steps <- list()
  code <- character(0L)

  # ---- 0. set seed --------------------------------------------------------
  if (!is.null(seed)) {
    code <- c(code, sprintf("set.seed(%d)", as.integer(seed)))
  }

  # ---- 1. random-effects draws -------------------------------------------
  re <- x$random_effects
  re_groups <- if (!is.null(re) && nrow(re) > 0L) unique(re$group_var) else character(0L)
  if (length(re_groups) > 0L) {
    for (g in re_groups) {
      sd_g <- recipe_re_sd(x, g)
      sd_label <- if (!is.na(sd_g)) sprintf("%.4g", sd_g) else sprintf("sigma_%s", g)
      n_g <- recipe_re_n(x, g)
      n_label <- if (!is.na(n_g)) as.character(n_g) else sprintf("n_%s", g)
      steps[[length(steps) + 1L]] <- sprintf(
        "Draw the group-level intercepts: u_%s ~ N(0, %s^2) for each of the %s groups.",
        g, sd_label, n_label
      )
      code <- c(code,
        sprintf("u_%s <- stats::rnorm(%s, mean = 0, sd = %s)", g, n_label, sd_label))
    }
  }

  # ---- 2. linear predictor (mu) ------------------------------------------
  link_mu <- recipe_link_for(x, "mu")
  inv_mu <- recipe_inv_link(link_mu)
  steps[[length(steps) + 1L]] <- sprintf(
    "Build the linear predictor for the mean on the %s scale: eta_mu = X * beta%s.",
    link_mu,
    if (length(re_groups) > 0L) paste0(" + sum_g u_g[i]") else ""
  )
  re_term <- if (length(re_groups) > 0L) {
    paste0(" + ", paste(sprintf("u_%s[%s_index]", re_groups, re_groups), collapse = " + "))
  } else ""
  code <- c(code,
    sprintf("eta_mu <- as.numeric(X_mu %%*%% beta_mu)%s", re_term))
  if (link_mu != "identity") {
    steps[[length(steps) + 1L]] <- sprintf(
      "Apply the inverse link to get mu_i = %s(eta_mu).", inv_mu
    )
    code <- c(code, sprintf("mu <- %s(eta_mu)", inv_mu))
  } else {
    code <- c(code, "mu <- eta_mu")
  }

  # ---- 3. optional sigma submodel (distributional) -----------------------
  has_sigma <- "sigma" %in% (x$submodels$parameter %||% character(0L))
  if (has_sigma) {
    link_sigma <- recipe_link_for(x, "sigma")
    inv_sigma <- recipe_inv_link(link_sigma)
    steps[[length(steps) + 1L]] <- sprintf(
      "Build the linear predictor for the residual SD: eta_sigma = Z * gamma; then sigma_i = %s(eta_sigma).",
      inv_sigma
    )
    code <- c(code,
      "eta_sigma <- as.numeric(Z_sigma %*% gamma_sigma)",
      sprintf("sigma <- %s(eta_sigma)", inv_sigma))
  }

  # ---- 4. optional zi submodel -------------------------------------------
  has_zi <- "zi" %in% (x$submodels$parameter %||% character(0L))
  if (has_zi) {
    steps[[length(steps) + 1L]] <- "Build the zero-inflation probability: pi_zi_i = plogis(eta_zi)."
    code <- c(code,
      "eta_zi <- as.numeric(X_zi %*% alpha_zi)",
      "pi_zi  <- stats::plogis(eta_zi)")
  }

  # ---- 5. response sampling ----------------------------------------------
  sampling_step <- recipe_response_sampling(family, has_sigma, has_zi)
  steps[[length(steps) + 1L]] <- sampling_step$pseudocode
  code <- c(code, sampling_step$r_code)

  recipe <- list(
    pseudocode = vapply(seq_along(steps),
                        function(i) sprintf("%d. %s", i, steps[[i]]),
                        character(1L)),
    r_code = paste(code, collapse = "\n"),
    metadata = list(
      family   = family,
      response = response,
      n_obs    = n_obs,
      has_sigma = has_sigma,
      has_zi    = has_zi,
      n_random_groups = length(re_groups),
      created_by = "simulate_recipe.symbolized_model"
    )
  )
  class(recipe) <- c("symbolizer_simulation_recipe", "list")
  recipe
}

# ---- helpers ---------------------------------------------------------------

# Look up the link for a given submodel, falling back to family-default.
recipe_link_for <- function(x, dpar) {
  sm <- x$submodels
  if (is.null(sm) || nrow(sm) == 0L) return("identity")
  hit <- sm[sm$parameter == dpar, , drop = FALSE]
  if (nrow(hit) >= 1L && !is.na(hit$link[[1L]])) {
    as.character(hit$link[[1L]])
  } else "identity"
}

recipe_inv_link <- function(link) {
  switch(
    link,
    identity = "identity",
    log      = "exp",
    logit    = "stats::plogis",
    probit   = "stats::pnorm",
    cloglog  = "function(x) -expm1(-exp(x))",
    inverse  = "function(x) 1 / x",
    "identity"
  )
}

# Best-effort lookup of a random-effect SD estimate from
# variance_components. Returns NA when not numerically resolvable.
recipe_re_sd <- function(x, group_var) {
  vc <- x$variance_components
  if (is.null(vc) || nrow(vc) == 0L) return(NA_real_)
  hit <- vc[vc$group == group_var, , drop = FALSE]
  if (nrow(hit) >= 1L && !is.na(hit$sd_estimate[[1L]])) {
    as.numeric(hit$sd_estimate[[1L]])
  } else NA_real_
}

recipe_re_n <- function(x, group_var) {
  re <- x$random_effects
  if (is.null(re) || nrow(re) == 0L) return(NA_integer_)
  hit <- re[re$group_var == group_var, , drop = FALSE]
  if (nrow(hit) >= 1L && !is.na(hit$n_levels[[1L]])) {
    as.integer(hit$n_levels[[1L]])
  } else NA_integer_
}

# Family-specific response sampling step.
recipe_response_sampling <- function(family, has_sigma, has_zi) {
  if (family %in% c("gaussian", "lognormal", "student")) {
    sd_term <- if (has_sigma) "sigma" else "sigma_residual"
    return(list(
      pseudocode = sprintf("Sample the response: y_i ~ N(mu_i, %s_i^2).", sd_term),
      r_code = sprintf("y <- stats::rnorm(length(mu), mean = mu, sd = %s)", sd_term)
    ))
  }
  if (family %in% c("binomial", "bernoulli")) {
    return(list(
      pseudocode = "Sample the response: y_i ~ Bernoulli(mu_i)  (use size = n_trials for grouped binomial).",
      r_code = paste(
        "n_trials <- 1L  # change to weights / cbind(success, fail) for grouped binomial",
        "y <- stats::rbinom(length(mu), size = n_trials, prob = mu)",
        sep = "\n")
    ))
  }
  if (family %in% c("poisson")) {
    if (has_zi) {
      return(list(
        pseudocode = "Sample the response: y_i ~ ZIP(mu_i, pi_zi_i). With probability pi_zi_i, y_i = 0; otherwise y_i ~ Poisson(mu_i).",
        r_code = paste(
          "is_struct_zero <- stats::rbinom(length(mu), size = 1, prob = pi_zi)",
          "y_pois <- stats::rpois(length(mu), lambda = mu)",
          "y <- ifelse(is_struct_zero == 1L, 0L, y_pois)",
          sep = "\n")
      ))
    }
    return(list(
      pseudocode = "Sample the response: y_i ~ Poisson(mu_i).",
      r_code = "y <- stats::rpois(length(mu), lambda = mu)"
    ))
  }
  if (family %in% c("nbinom2", "truncated_nbinom2")) {
    return(list(
      pseudocode = "Sample the response: y_i ~ NegBinomial(mu = mu_i, size = exp(sigma_i)).",
      r_code = "y <- stats::rnbinom(length(mu), mu = mu, size = exp(sigma))"
    ))
  }
  if (family %in% c("Gamma")) {
    return(list(
      pseudocode = "Sample the response: y_i ~ Gamma(shape = 1/sigma_i^2, scale = mu_i * sigma_i^2).",
      r_code = paste(
        "shape_g <- 1 / sigma^2",
        "scale_g <- mu * sigma^2",
        "y <- stats::rgamma(length(mu), shape = shape_g, scale = scale_g)",
        sep = "\n")
    ))
  }
  if (family %in% c("beta")) {
    return(list(
      pseudocode = "Sample the response: y_i ~ Beta(mu_i * sigma_i, (1 - mu_i) * sigma_i)  where sigma is the precision.",
      r_code = "y <- stats::rbeta(length(mu), shape1 = mu * sigma, shape2 = (1 - mu) * sigma)"
    ))
  }
  if (family %in% c("meta_normal")) {
    return(list(
      pseudocode = paste(
        "Two-tier meta-analytic draw:",
        "(a) theta_i = mu_i + u_study[i],  u_study ~ N(0, tau^2)  (between-study heterogeneity),",
        "(b) y_i ~ N(theta_i, v_i)  where v_i is the KNOWN sampling variance per study.",
        sep = " "),
      r_code = paste(
        "u_study <- stats::rnorm(n_studies, mean = 0, sd = sqrt(tau2))",
        "theta   <- mu + u_study[study_index]",
        "y       <- stats::rnorm(length(theta), mean = theta, sd = sqrt(v_i))",
        sep = "\n")
    ))
  }
  # Fallback
  list(
    pseudocode = sprintf("Sample the response from family %s (consult the package's own simulate() for details).", family),
    r_code = sprintf("# family = %s: replace with a family-appropriate RNG call\ny <- stats::rnorm(length(mu), mean = mu, sd = 1)", family)
  )
}

# ---- print / knit_print ----------------------------------------------------

#' @export
print.symbolizer_simulation_recipe <- function(x, ...) {
  cli::cli_h2("Simulation recipe")
  cli::cli_text("{.emph Family:} {x$metadata$family}{?  with sigma submodel}{?  with zi submodel}")
  cli::cli_h3("Pseudocode")
  for (line in x$pseudocode) cli::cli_text(line)
  cli::cli_h3("R code")
  cli::cli_verbatim(x$r_code)
  invisible(x)
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_simulation_recipe <- function(x, ...) {
  if (!requireNamespace("knitr", quietly = TRUE)) return(invisible(x))
  out <- paste(
    c("",
      "**Pseudocode**",
      "",
      paste(x$pseudocode, collapse = "\n"),
      "",
      "**R code**",
      "",
      "```r",
      x$r_code,
      "```",
      ""),
    collapse = "\n"
  )
  knitr::asis_output(out)
}
