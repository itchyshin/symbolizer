# print walkthrough is stable

    Code
      print(explain_factors(lm(y ~ site, data = d)))
    Message
      
      -- Factors in your <lm> model --------------------------------------------------
      
      -- site --
      
      `site` has 3 levels (A, B, C). R uses A as the baseline and adds 2 indicator
      column(s); each coefficient is the difference from A, not that group's own
      mean.
      
      
      -- Group means --
      
      site=A estimate = "0.343" (-0.165, 0.851)
      site=B estimate = "0.238" (-0.270, 0.746)
      site=C estimate = "0.881" (0.373, 1.39) *
      Scale: response. CI method: wald. Rows marked `*` have a 95% interval that
      excludes zero.
      
      
      -- Group contrasts (pairwise) --
      
      A - B estimate = "0.105" (-0.613, 0.823)
      A - C estimate = "-0.538" (-1.26, 0.180)
      B - C estimate = "-0.643" (-1.36, 0.0753)
      Intervals are per-contrast, not family-wise; pass adjust = "tukey" for
      simultaneous bands. Scale: response. CI method: wald. Adjustment: none. Rows
      marked `*` have a 95% interval that excludes the null.

