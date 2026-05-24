# capability_check() rejects drmTMB/gaussian/zi (Planned)

    Code
      symbolizer:::capability_check("drmTMB", "gaussian", "zi")
    Condition
      Error in `symbolizer:::capability_check()`:
      ! `symbolize()` cannot read drmTMB / gaussian / zi yet (status: Planned or reserved).
      i Today we can read:
      * drmTMB gaussian: mu, sigma (Stable)
      * drmTMB biv_gaussian: mu1, mu2, rho12, sigma1, sigma2 (First slice)
      * drmTMB gaussian: random_effects (First slice)
      * drmTMB lognormal: mu, sigma (First slice)
      * drmTMB student: mu, nu, sigma (First slice)
      * gllvmTMB gaussian: Lambda_B, mu, Psi_B, Sigma_B, sigma_eps (First slice)
      i See `symbolizer_capabilities()` for the full registry.

# capability_check() rejects brmsfit/gaussian/mu via wildcard

    Code
      symbolizer:::capability_check("brmsfit", "gaussian", "mu")
    Condition
      Error in `symbolizer:::capability_check()`:
      ! `symbolize()` cannot read brmsfit / gaussian / mu yet (status: Planned or reserved).
      i Today we can read:
      * drmTMB gaussian: mu, sigma (Stable)
      * drmTMB biv_gaussian: mu1, mu2, rho12, sigma1, sigma2 (First slice)
      * drmTMB gaussian: random_effects (First slice)
      * drmTMB lognormal: mu, sigma (First slice)
      * drmTMB student: mu, nu, sigma (First slice)
      * gllvmTMB gaussian: Lambda_B, mu, Psi_B, Sigma_B, sigma_eps (First slice)
      i See `symbolizer_capabilities()` for the full registry.

# capability_check() errors when no entry exists at all

    Code
      symbolizer:::capability_check("nonexistent", "weird", "thing")
    Condition
      Error in `symbolizer:::capability_check()`:
      ! No capability entry for class "nonexistent" / family "weird" / component "thing".
      i Add a row to 'inst/extdata/capabilities.csv' before exporting a method.

