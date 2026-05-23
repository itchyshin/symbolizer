# symbolizer

> **Equations are not enough.** `symbolizer` turns fitted models into equations, assumptions, interpretations, and teachable model stories.

## Positioning

`symbolizer` is the complement to [`equatiomatic`](https://datalorax.github.io/equatiomatic/), not a replacement. Reach for `equatiomatic` when you want a clean LaTeX equation for one model. Reach for `symbolizer` when you need to understand the model — its assumptions, what each coefficient means on a natural scale, both notations side by side, and (soon) how your data actually flows through the matrices.

| What you want | `equatiomatic` | `symbolizer` |
| --- | --- | --- |
| The equation | `extract_eq(fit)` | `equations(symbolize(fit))` |
| Substituted coefficients | `extract_eq(fit, use_coefs = TRUE)` | `as_latex(sym)` |
| Multi-submodel models (μ + σ + RE) | partial | first-class |
| Stated and implied assumptions | — | `assumption_table(sym)` |
| Per-coefficient reading | — | `parameter_interpretation(sym)` |
| Index and matrix notation side by side | — | `equations(sym, notation = "both")`, `notation_bridge(sym)` |

For example, on a Gaussian location-scale fit (`body_mass ~ temperature` + `sigma ~ temperature`, with `(1 | group)` random intercepts), `parameter_interpretation(sym)` reads the temperature slope on σ as:

> *"A unit change in temperature multiplies the unexplained variability of body_mass by $e^{0.08} \approx 1.08$."*

Built first for the two TMB sister packages — [`drmTMB`](https://itchyshin.github.io/drmTMB/) and [`gllvmTMB`](https://itchyshin.github.io/gllvmTMB/) — and extended across the GLMM ecosystem used in ecology and evolution: `glmmTMB`, `brms`, `MCMCglmm`, `sdmTMB`, `lme4`, and base `lm`/`glm`.

## Install

`symbolizer` is pre-CRAN. Install the development build from GitHub with `pak`:

```r
install.packages("pak")
pak::pak("itchyshin/symbolizer")
```

## Tiny example

```r
library(symbolizer)
library(drmTMB)

set.seed(1)
n <- 200
temperature <- runif(n, 10, 25)
dat <- data.frame(
  body_mass   = rnorm(n, 30 + 0.4 * temperature, exp(0.5 + 0.1 * temperature)),
  temperature = temperature
)

fit <- drmTMB(
  drm_formula(body_mass ~ temperature, sigma ~ temperature),
  family = gaussian(),
  data   = dat
)

sym <- symbolize(
  fit,
  symbols = c(body_mass = "W_i", temperature = "T_i"),
  units   = c(body_mass = "g",   temperature = "C"),
  context = "avian body-size location-scale model"
)

equations(sym)
symbol_table(sym)
assumption_table(sym)
parameter_interpretation(sym)
cat(as_latex(sym))
```

## Status

Pre-release. Read status words consistently:

| Status word         | Meaning for a user                                                                  |
| ------------------- | ----------------------------------------------------------------------------------- |
| Stable              | Routine path with tests, diagnostics, and a reader-facing example.                  |
| First slice         | Fitted and tested, but intentionally narrow.                                        |
| Opt-in control      | Available for hardening, not a general modelling guarantee.                         |
| Planned or reserved | Public grammar may exist, but `symbolize()` should reject it as design-only.        |
| Unsupported         | Do not use as analysis syntax; fit the nearest implemented model.                   |

### v0.1 capability matrix

| Surface | Status |
| --- | --- |
| `drmTMB` Gaussian location-scale, fixed effects (μ + σ submodels) | Stable |
| `drmTMB` Gaussian random intercepts `(1 \| group)` | First slice |
| `drmTMB` non-Gaussian families, ZI, hurdle, bivariate | Planned |
| `gllvmTMB`, `glmmTMB`, `brms`, `MCMCglmm`, `sdmTMB`, `lme4`, `lm`/`glm` | Unsupported in v0.1 (see roadmap) |
| `compare_symbolic()`, `model_card()`, `methods_text()`, model diagrams | Planned (v0.2 to v0.5) |

See `symbolizer_capabilities()` for the full registry.

## Roadmap

| Version | Theme |
| --- | --- |
| v0.1 | drmTMB symbolic specification with educational extras |
| v0.2 | Structural model comparison (`compare_symbolic`) |
| v0.3 | Teaching and writing layer (`model_card`, `methods_text`, warnings, family sheets) |
| v0.4 | `gllvmTMB` and `gllvmTMB_multi` |
| v0.5 | Diagrams and notebooks |
| v0.6 | `glmmTMB` |
| v0.7 | `brms` |
| v0.8 | `MCMCglmm` |
| v0.9 | `sdmTMB` |
| v0.10 | `lme4`, `lm`, `glm` |

## License

GPL-3. Companion to [`drmTMB`](https://itchyshin.github.io/drmTMB/) and [`gllvmTMB`](https://itchyshin.github.io/gllvmTMB/).
