# capability_check() rejects drmTMB/gaussian/zi (Planned)

    Code
      symbolizer:::capability_check("drmTMB", "gaussian", "zi")
    Condition
      Error in `symbolizer:::capability_check()`:
      ! `symbolize()` cannot read drmTMB / gaussian / zi yet (status: Planned or reserved).
      i Today we can read:
      * brmsfit gaussian: mu, random_effects, sigma_distributional (First slice)
      * drmTMB gaussian: mu, sigma (Stable)
      * drmTMB beta: mu, sigma (First slice)
      * drmTMB beta_binomial: mu, sigma (First slice)
      * drmTMB biv_gaussian: mu1, mu2, rho12, sigma1, sigma2 (First slice)
      * drmTMB cumulative_logit: mu (First slice)
      * drmTMB Gamma: mu, sigma (First slice)
      * drmTMB gaussian: random_effects (First slice)
      * drmTMB lognormal: mu, sigma (First slice)
      * drmTMB nbinom2: mu, sigma, zi (First slice)
      * drmTMB poisson: mu, zi (First slice)
      * drmTMB student: mu, nu, sigma (First slice)
      * drmTMB truncated_nbinom2: hu, mu, sigma (First slice)
      * gllvmTMB binomial: Lambda_B, mu, Psi_B, Sigma_B (First slice)
      * gllvmTMB gaussian: Lambda_B, mu, Psi_B, Sigma_B, sigma_eps (First slice)
      * glm binomial: mu (First slice)
      * glm Gamma: mu (First slice)
      * glm gaussian: mu (First slice)
      * glm poisson: mu (First slice)
      * glmerMod binomial: mu, random_effects (First slice)
      * glmerMod poisson: mu, random_effects (First slice)
      * glmmTMB binomial: mu, random_effects (First slice)
      * glmmTMB gaussian: mu, random_effects, sigma (First slice)
      * glmmTMB nbinom2: mu, random_effects, sigma, zi (First slice)
      * glmmTMB poisson: mu, random_effects, zi (First slice)
      * lm gaussian: mu (First slice)
      * lmerMod gaussian: mu, random_effects (First slice)
      * MCMCglmm gaussian: mu, random_effects (First slice)
      i See `symbolizer_capabilities()` for the full registry.

# capability_check() rejects sdmTMB/gaussian/mu (Planned) via wildcard

    Code
      symbolizer:::capability_check("sdmTMB", "gaussian", "mu")
    Condition
      Error in `symbolizer:::capability_check()`:
      ! `symbolize()` cannot read sdmTMB / gaussian / mu yet (status: Planned or reserved).
      i Today we can read:
      * brmsfit gaussian: mu, random_effects, sigma_distributional (First slice)
      * drmTMB gaussian: mu, sigma (Stable)
      * drmTMB beta: mu, sigma (First slice)
      * drmTMB beta_binomial: mu, sigma (First slice)
      * drmTMB biv_gaussian: mu1, mu2, rho12, sigma1, sigma2 (First slice)
      * drmTMB cumulative_logit: mu (First slice)
      * drmTMB Gamma: mu, sigma (First slice)
      * drmTMB gaussian: random_effects (First slice)
      * drmTMB lognormal: mu, sigma (First slice)
      * drmTMB nbinom2: mu, sigma, zi (First slice)
      * drmTMB poisson: mu, zi (First slice)
      * drmTMB student: mu, nu, sigma (First slice)
      * drmTMB truncated_nbinom2: hu, mu, sigma (First slice)
      * gllvmTMB binomial: Lambda_B, mu, Psi_B, Sigma_B (First slice)
      * gllvmTMB gaussian: Lambda_B, mu, Psi_B, Sigma_B, sigma_eps (First slice)
      * glm binomial: mu (First slice)
      * glm Gamma: mu (First slice)
      * glm gaussian: mu (First slice)
      * glm poisson: mu (First slice)
      * glmerMod binomial: mu, random_effects (First slice)
      * glmerMod poisson: mu, random_effects (First slice)
      * glmmTMB binomial: mu, random_effects (First slice)
      * glmmTMB gaussian: mu, random_effects, sigma (First slice)
      * glmmTMB nbinom2: mu, random_effects, sigma, zi (First slice)
      * glmmTMB poisson: mu, random_effects, zi (First slice)
      * lm gaussian: mu (First slice)
      * lmerMod gaussian: mu, random_effects (First slice)
      * MCMCglmm gaussian: mu, random_effects (First slice)
      i See `symbolizer_capabilities()` for the full registry.

# capability_check() errors when no entry exists at all

    Code
      symbolizer:::capability_check("nonexistent", "weird", "thing")
    Condition
      Error in `symbolizer:::capability_check()`:
      ! No capability entry for class "nonexistent" / family "weird" / component "thing".
      i Add a row to 'inst/extdata/capabilities.csv' before exporting a method.

