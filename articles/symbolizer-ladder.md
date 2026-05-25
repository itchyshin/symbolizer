# Building up: from \`lm\` to location-scale

## The idea

`symbolizer` turns any fitted model into a structured symbolic
specification. To see *what* that buys you, the easiest path is to fit a
sequence of models — each adding one feature — and watch the symbolic
specification grow rung by rung.

Throughout this article we use **one dataset** — body mass measured
across temperature, sex, and site — and climb four rungs:

| Rung | Model | What’s new in the symbolic story |
|----|----|----|
| 1 | `lm(body_mass ~ temperature)` | distribution + linear predictor |
| 2 | `lm(body_mass ~ temperature + sex)` | a factor: dummy-encoded contrast |
| 3 | `lmer(body_mass ~ temperature + sex + (1\|site))` | a random intercept + variance components |
| 4 | `drmTMB(body_mass ~ temperature + sex + (1\|site), sigma ~ temperature)` | heteroscedasticity: variance depends on temperature |

The reader-facing surface stays exactly the same: at every rung you call
`symbolize(fit)`, then
[`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md)
/
[`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
/
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
to read it. The *contents* of those outputs grow.

## Setup — one shared dataset

``` r

library(symbolizer)
set.seed(1)

n <- 200
n_sites <- 12
sites <- factor(rep(paste0("S", sprintf("%02d", seq_len(n_sites))),
                    length.out = n))
site_effect <- rnorm(n_sites, 0, 0.6)[as.integer(sites)]
sex <- factor(sample(c("F", "M"), n, replace = TRUE))
temperature <- runif(n, 10, 25)

# Mean: linear in temperature, +0.7 for males, plus a site offset.
# Variance: heteroscedastic — residual SD grows with temperature.
mu_true    <- 30 + 0.4 * temperature + 0.7 * (sex == "M") + site_effect
sigma_true <- exp(0.3 + 0.05 * temperature)
body_mass  <- rnorm(n, mean = mu_true, sd = sigma_true)

dat <- data.frame(
  body_mass   = body_mass,
  temperature = temperature,
  sex         = sex,
  site        = sites
)
head(dat, 4)
#>   body_mass temperature sex site
#> 1  37.38671    23.85953   F  S01
#> 2  32.70239    17.66440   F  S02
#> 3  38.41142    13.86432   M  S03
#> 4  38.73812    10.69691   F  S04
```

The “truth” the ladder will gradually uncover:

- Slope of temperature on the mean: `0.4` g per °C
- Sex contrast (M − F) on the mean: `+0.7` g
- Site-to-site SD on the mean: `0.6` g
- Heteroscedasticity: residual SD grows by a factor of
  `exp(0.05) ≈ 1.05` per °C

## Rung 1 — A linear model

The simplest fit. Just temperature on the mean.

``` r

fit1 <- lm(body_mass ~ temperature, data = dat)
sym1 <- symbolize(fit1)
```

The equation:

``` r

cat(as_latex(sym1), "\n")
#> \begin{aligned}
#> body_mass \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
#> \mu_i & = \beta_{0} + \beta_{1} \, temperature_i
#> \end{aligned}
```

The symbol dictionary, listing every variable the model uses:

``` r

symbol_table(sym1)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| body_mass | $`\mathbf{body_mass}`$ | body_mass | NA | response | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | response variable |
| temperature_i | — | temperature | NA | predictor | column of design matrix | column of X (length 200) | continuous predictor |
| $`\mu_i`$ | $`\boldsymbol{\mu}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | conditional mu of body_mass |
| $`\beta_{0}, \beta_{1}`$ | $`\boldsymbol{\beta}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{2}`$ | mu submodel coefficients |
| — | $`\mathbf{X}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{200 \times 2}`$ | mu submodel design matrix |

What each coefficient means, on each scale `symbolizer` knows about:

``` r

parameter_interpretation(sym1, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | 95% CI | biological_reading |
|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 32.3 | 30.4, 34.2 \* | Baseline body_mass in the reference condition |
| mu | temperature | slope | 0.294 | 0.188, 0.401 \* | A unit change in temperature shifts the expected body_mass by 0.294 |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

**What we have so far.** A distribution line for the response, a linear
predictor for $`\mu_i`$, and one slope to interpret. No variance
modelling beyond a single residual SD. No grouping. The biological
reading is “a unit change in temperature shifts the expected body_mass
by 0.294.”

## Rung 2 — Adding a factor

What if mass differs systematically between sexes? Add `sex` to the
mean.

``` r

fit2 <- lm(body_mass ~ temperature + sex, data = dat)
sym2 <- symbolize(fit2)
```

``` r

cat(as_latex(sym2), "\n")
#> \begin{aligned}
#> body_mass \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
#> \mu_i & = \beta_{0} + \beta_{1} \, temperature_i + \beta_{2} \, [sex = \mathrm{M}]
#> \end{aligned}
```

The equation now carries a contrast term. The symbol dictionary adds a
row for the dummy-encoded contrast:

``` r

symbol_table(sym2)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| body_mass | $`\mathbf{body_mass}`$ | body_mass | NA | response | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | response variable |
| temperature_i | — | temperature | NA | predictor | column of design matrix | column of X (length 200) | continuous predictor |
| sex_i | — | sex | NA | factor | column of design matrix | column of X (length 200) | factor (F \[reference\], M) |
| $`\mu_i`$ | $`\boldsymbol{\mu}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | conditional mu of body_mass |
| $`\beta_{0}, \beta_{1}, \beta_{2}`$ | $`\boldsymbol{\beta}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{3}`$ | mu submodel coefficients |
| — | $`\mathbf{X}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{200 \times 3}`$ | mu submodel design matrix |

`sex` is a factor with reference level `F` (alphabetical). The single
dummy column `[sex = M]` enters the linear predictor with its own slope
$`\beta_2`$. The interpretation reads the contrast explicitly:

``` r

pi2 <- parameter_interpretation(sym2, scale = "biological")
pi2[pi2$coefficient_role == "factor_contrast", c("term_label", "estimate", "biological_reading")]
```

| term_label | estimate | biological_reading                                 |
|:-----------|:---------|:---------------------------------------------------|
| sex        | 0.499    | Average body_mass differs between M and F by 0.499 |

**What just got added.** One row in the symbol table (the factor
contrast), one row in
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md),
and one term in the LaTeX. The model class didn’t change (`lm` to `lm`),
but the symbolic story grew exactly where the model grew.

## Rung 3 — Adding random effects

Sites probably differ from one another, even at the same temperature.
Add a random intercept per site.

``` r

library(lme4)
#> Loading required package: Matrix
#> 
#> Attaching package: 'Matrix'
#> The following object is masked from 'package:symbolizer':
#> 
#>     expand
fit3 <- lmer(body_mass ~ temperature + sex + (1 | site), data = dat)
#> boundary (singular) fit: see help('isSingular')
sym3 <- symbolize(fit3)
```

``` r

cat(as_latex(sym3), "\n")
#> \begin{aligned}
#> body_mass \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
#> \mu_i & = \beta_{0} + \beta_{1} \, temperature_i + \beta_{2} \, [sex = \mathrm{M}] + u_{site(i)} \\
#> u_{site} & \sim \mathcal{N}(0,\, \sigma_{site}^2)
#> \end{aligned}
```

Two new rows in the equation block:

1.  `u_{site(i)}` is added to the linear predictor for $`\mu_i`$.
2.  A second distributional line: `u_{site} ~ N(0, σ²_site)`.

Variance components are now first-class:

``` r

sym3$variance_components
#> # A tibble: 2 × 5
#>   parameter group    term        sd_estimate var_estimate
#>   <chr>     <chr>    <chr>             <dbl>        <dbl>
#> 1 mu        site     (Intercept)        0             0  
#> 2 residual  residual Residual           3.28         10.8
```

You can read off the between-site SD and the residual SD directly. The
fixed-effect interpretation rows for temperature and sex still read on
the response scale; what changed is that the model now *partitions* the
variability into between-site and within-site parts.

**What just got added.** A `u_{site(i)}` symbol, a random-effect
distributional line, and a `variance_components` tibble showing the two
SDs. Same
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
call, richer object.

## Rung 4 — Location-scale (heteroscedasticity)

Look at the residuals against temperature — they fan out:

``` r

plot(dat$temperature, residuals(fit3),
     xlab = "temperature (°C)", ylab = "residual (g)",
     pch = 16, col = "#a0282b")
abline(h = 0, col = "#666666")
```

![Residuals against temperature with a wedge-shaped
spread](symbolizer-ladder_files/figure-html/rung4-resid-1.png)

The variance is changing with temperature. A standard mixed model forces
residual variance to be constant, so the inference on $`\beta_1`$
ignores that. Climb the last rung: fit
$`\log(\sigma_i) = \gamma_0 + \gamma_1\, T_i`$.

``` r

library(drmTMB)
#> 
#> Attaching package: 'drmTMB'
#> The following objects are masked from 'package:lme4':
#> 
#>     fixef, ranef
#> The following object is masked from 'package:base':
#> 
#>     beta
fit4 <- drmTMB(
  drm_formula(body_mass ~ temperature + sex + (1 | site),
              sigma     ~ temperature),
  family = gaussian(),
  data   = dat
)
sym4 <- symbolize(fit4)
```

``` r

cat(as_latex(sym4), "\n")
#> \begin{aligned}
#> body_mass_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
#> \mu_i & = \beta_{0} + \beta_{1} \, temperature_i + \beta_{2} \, [sex = \mathrm{M}] + u_{site(i)} \\
#> \log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, temperature_i \\
#> u_{site} & \sim \mathcal{N}(0,\, \sigma_{site}^2)
#> \end{aligned}
```

The equation block grew by **one new line** — the
$`\log(\sigma_i) = \gamma_0 + \gamma_1\, T_i`$ row. That single
additional line is the heteroscedasticity story.

Reading on the variability scale:

``` r

pi4 <- parameter_interpretation(sym4, scale = "biological")
pi4[pi4$submodel == "sigma", c("term_label", "estimate", "biological_reading")]
```

| term_label | estimate | biological_reading |
|:---|:---|:---|
| (Intercept) | 0.476 | Baseline level of unexplained individual variation in body_mass |
| temperature | 0.0392 | A unit change in temperature multiplies the unexplained variability of body_mass by exp(0.0392) |

The slope $`\gamma_1`$ reads as “residual SD multiplies by `exp(γ_1)`
per °C”. For our simulated data the truth was `exp(0.05) ≈ 1.05`, so
each additional °C inflates the residual SD by about 5 %.

## Three views of the same fit

For the full educator-facing surface — equation, index expansion, matrix
form, with the actual numeric arrays running alongside — ask for the
three-view widget:

``` r

as_html_three_views(sym4)
```

[Skip three-views widget](#sym-sym-1779724032-end)

    <button type="button" class="sym-tab sym-active" role="tab" id="sym-sym-1779724032-tab-eq" aria-controls="sym-sym-1779724032-panel-eq" aria-selected="true" tabindex="0" data-tab="eq"><span class="sym-tab-marker" aria-hidden="true">&#9656;</span>1. Equation</button>
    <button type="button" class="sym-tab" role="tab" id="sym-sym-1779724032-tab-idx" aria-controls="sym-sym-1779724032-panel-idx" aria-selected="false" tabindex="-1" data-tab="idx"><span class="sym-tab-marker" aria-hidden="true">&#9656;</span>2. Index</button>
    <button type="button" class="sym-tab" role="tab" id="sym-sym-1779724032-tab-mat" aria-controls="sym-sym-1779724032-panel-mat" aria-selected="false" tabindex="-1" data-tab="mat"><span class="sym-tab-marker" aria-hidden="true">&#9656;</span>3. Matrix (with data)</button>

The structural contract. No indices, no numbers – the shape of the
model.

``` math
\begin{aligned}
\mathbf{body_mass} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} + \mathbf{u} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma} \\
\mathbf{u}_{site} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{site}^2 \mathbf{I}_{12})
\end{aligned}
```

What happens for each observation *i*.

``` math
\begin{aligned}
body_mass_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, temperature_i + \beta_{2} \, [sex = \mathrm{M}] + u_{site(i)} \\
\log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, temperature_i \\
u_{site} & \sim \mathcal{N}(0,\, \sigma_{site}^2)
\end{aligned}
```

The actual numbers stacked – what the computer is multiplying. Showing
first 5 and last 2 rows of n = 200.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below. A random-effect indicator matrix Z_g and the predicted BLUPs u
are also shown.

``` sym-matrix

  y                   X                          beta
  y_1 = 37.4          1.00  23.9  0           
  y_2 = 32.7          1.00  17.7  0           
  y_3 = 38.4          1.00  13.9  1.00        
  y_4 = 38.7          1.00  10.7  0           
  y_5 = 35.8          1.00  16.3  0           
  ...               ...                   
  y_199 = 37.6        1.00  19.9  1.00        
  y_200 = 37.6        1.00  12.1  1.00        

  Coefficients (beta, mu):
    beta_0 = 31.9
    beta_1 = 0.298
    beta_2 = 0.766

  X_sigma                       gamma
  1.00  23.9                    
  1.00  17.7                    
  1.00  13.9                    
  1.00  10.7                    
  1.00  16.3                    
  ...                         
  1.00  19.9                    
  1.00  12.1                    
    gamma_0 = 0.476
    gamma_1 = 0.0392

  Z_g (group indicator)         u (random effects, BLUPs)
  1.00  0  0  0  0  0  0  0  0  0  0  0  
  0  1.00  0  0  0  0  0  0  0  0  0  0  
  0  0  1.00  0  0  0  0  0  0  0  0  0  
  0  0  0  1.00  0  0  0  0  0  0  0  0  
  0  0  0  0  1.00  0  0  0  0  0  0  0  
  ...                         
  0  0  0  0  0  0  1.00  0  0  0  0  0  
  0  0  0  0  0  0  0  1.00  0  0  0  0  
    u_1 = -0.000000257
    u_2 = 0.000000114
    u_3 = -0.000000245
    u_4 = 0.000000218
    u_5 = 0.000000167
    u_6 = -0.0000000271
    u_7 = -0.000000126
    u_8 = -0.00000000693
    u_9 = -0.0000000901
    u_10 = -0.000000120
    u_11 = 0.000000322
    u_12 = 0.0000000515

  Fitted mu_hat (first 5): 39.0  37.1  36.7  35.0  36.7
  Fitted sigma_hat (first 5): 4.10  3.22  2.77  2.45  3.04
```

\<style\>.sym-tabs { position: relative; border: 1px solid \#e5e7eb;
border-radius: 8px; overflow: hidden; margin: 1em 0; font-family:
-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
.sym-tablist { display: flex; background: \#f9fafb; border-bottom: 1px
solid \#e5e7eb; } .sym-tab { flex: 1; text-align: center; padding:
0.6rem 0.5rem; cursor: pointer; font-weight: 600; color: \#6b7280;
border: 0; border-right: 1px solid \#e5e7eb; background: transparent;
user-select: none; font-size: 0.92rem; font-family: inherit; }
.sym-tab:last-child { border-right: 0; } .sym-tab:hover { background:
\#fbe7e7; color: \#7a2a2a; } .sym-tab.sym-active { background: \#fff;
color: \#8a1f22; box-shadow: inset 0 -3px 0 \#a0282b; }
.sym-tab:focus-visible { outline: 2px solid \#a0282b; outline-offset:
-2px; } .sym-tab-marker { display: inline-block; margin-right: 0.35em;
opacity: 0; transition: opacity 0.1s; } .sym-tab.sym-active
.sym-tab-marker { opacity: 1; } .sym-panel { padding: 1rem 1.1rem
1.2rem; } .sym-panel\[hidden\] { display: none; } .sym-eq { background:
\#fbe7e7; border: 1px solid \#a0282b; border-radius: 6px; padding:
0.7rem 1rem; margin: 0.4rem 0; text-align: center; } .sym-caption {
color: \#6b7280; font-size: 0.85rem; margin: 0.2rem 0 0.4rem; }
.sym-matrix { font-family: ui-monospace, "SF Mono", Menlo, monospace;
font-size: 0.78rem; line-height: 1.35; white-space: pre; overflow-x:
auto; background: \#f9fafb; border: 1px solid \#e5e7eb; border-radius:
6px; padding: 0.6rem 0.8rem; margin: 0.3rem 0; } .sym-sr-only {
position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border:
0; } .sym-skip { position: absolute; top: -100px; left: 0; padding:
0.4rem 0.7rem; background: \#8a1f22; color: \#fff; text-decoration:
none; font-size: 0.85rem; z-index: 5; } .sym-skip:focus { top: 0;
}\</style\> \<div class="sym-tabs" id="sym-sym-1779724032"\> \<a
class="sym-skip" href="#sym-sym-1779724032-end"\>Skip three-views
widget\</a\> \<div class="sym-tablist" role="tablist" aria-label="Three
views of the model"\> \<button type="button" class="sym-tab sym-active"
role="tab" id="sym-sym-1779724032-tab-eq"
aria-controls="sym-sym-1779724032-panel-eq" aria-selected="true"
tabindex="0" data-tab="eq"\>\<span class="sym-tab-marker"
aria-hidden="true"\>&#9656;\</span\>1. Equation\</button\> \<button
type="button" class="sym-tab" role="tab" id="sym-sym-1779724032-tab-idx"
aria-controls="sym-sym-1779724032-panel-idx" aria-selected="false"
tabindex="-1" data-tab="idx"\>\<span class="sym-tab-marker"
aria-hidden="true"\>&#9656;\</span\>2. Index\</button\> \<button
type="button" class="sym-tab" role="tab" id="sym-sym-1779724032-tab-mat"
aria-controls="sym-sym-1779724032-panel-mat" aria-selected="false"
tabindex="-1" data-tab="mat"\>\<span class="sym-tab-marker"
aria-hidden="true"\>&#9656;\</span\>3. Matrix (with data)\</button\>
\</div\> \<div class="sym-panel sym-active" role="tabpanel"
id="sym-sym-1779724032-panel-eq"
aria-labelledby="sym-sym-1779724032-tab-eq" data-panel="eq"
tabindex="0"\> \<p class="sym-caption"\>The structural contract. No
indices, no numbers -- the shape of the model.\</p\> \<div
class="sym-eq"\>\$\$\begin{aligned} \mathbf{body_mass} \mid
\boldsymbol{\mu},\\ \boldsymbol{\sigma} & \sim
\mathcal{N}(\boldsymbol{\mu},\\ \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} + \mathbf{u} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma} \\
\mathbf{u}\_{site} & \sim \mathcal{N}(\mathbf{0},\\ \sigma\_{site}^2
\mathbf{I}\_{12}) \end{aligned}\$\$\</div\> \</div\> \<div
class="sym-panel" role="tabpanel" id="sym-sym-1779724032-panel-idx"
aria-labelledby="sym-sym-1779724032-tab-idx" data-panel="idx" hidden
tabindex="0"\> \<p class="sym-caption"\>What happens for each
observation \<em\>i\</em\>.\</p\> \<div
class="sym-eq"\>\$\$\begin{aligned} body_mass_i \mid \mu_i,\\ \sigma_i &
\sim \mathrm{Normal}(\mu_i,\\ \sigma_i^2) \\ \mu_i & = \beta\_{0} +
\beta\_{1} \\ temperature_i + \beta\_{2} \\ \[sex = \mathrm{M}\] +
u\_{site(i)} \\ \log(\sigma_i) & = \gamma\_{0} + \gamma\_{1} \\
temperature_i \\ u\_{site} & \sim \mathcal{N}(0,\\ \sigma\_{site}^2)
\end{aligned}\$\$\</div\> \</div\> \<div class="sym-panel"
role="tabpanel" id="sym-sym-1779724032-panel-mat"
aria-labelledby="sym-sym-1779724032-tab-mat" data-panel="mat" hidden
tabindex="0"\> \<p class="sym-caption"\>The actual numbers stacked --
what the computer is multiplying. Showing first 5 and last 2 rows of n =
200.\</p\> \<span class="sym-sr-only"\>Matrix-form expansion of the
model. Each row shows the response y_i and the corresponding row of the
design matrix X (showing head and tail rows of the n total
observations), with the coefficient vector beta listed below. A
random-effect indicator matrix Z_g and the predicted BLUPs u are also
shown.\</span\> \<pre class="sym-matrix" aria-hidden="true"\> y X beta
y_1 = 37.4 1.00 23.9 0 y_2 = 32.7 1.00 17.7 0 y_3 = 38.4 1.00 13.9 1.00
y_4 = 38.7 1.00 10.7 0 y_5 = 35.8 1.00 16.3 0 ... ... y_199 = 37.6 1.00
19.9 1.00 y_200 = 37.6 1.00 12.1 1.00 Coefficients (beta, mu): beta_0 =
31.9 beta_1 = 0.298 beta_2 = 0.766 X_sigma gamma 1.00 23.9 1.00 17.7
1.00 13.9 1.00 10.7 1.00 16.3 ... 1.00 19.9 1.00 12.1 gamma_0 = 0.476
gamma_1 = 0.0392 Z_g (group indicator) u (random effects, BLUPs) 1.00 0
0 0 0 0 0 0 0 0 0 0 0 1.00 0 0 0 0 0 0 0 0 0 0 0 0 1.00 0 0 0 0 0 0 0 0
0 0 0 0 1.00 0 0 0 0 0 0 0 0 0 0 0 0 1.00 0 0 0 0 0 0 0 ... 0 0 0 0 0 0
1.00 0 0 0 0 0 0 0 0 0 0 0 0 1.00 0 0 0 0 u_1 = -0.000000257 u_2 =
0.000000114 u_3 = -0.000000245 u_4 = 0.000000218 u_5 = 0.000000167 u_6 =
-0.0000000271 u_7 = -0.000000126 u_8 = -0.00000000693 u_9 =
-0.0000000901 u_10 = -0.000000120 u_11 = 0.000000322 u_12 = 0.0000000515
Fitted mu_hat (first 5): 39.0 37.1 36.7 35.0 36.7 Fitted sigma_hat
(first 5): 4.10 3.22 2.77 2.45 3.04 \</pre\> \</div\> \</div\> \<span
id="sym-sym-1779724032-end" tabindex="-1"\>\</span\>
\<script\>(function() { var root =
document.getElementById("sym-sym-1779724032"); if (!root) return; var
tabs =
Array.prototype.slice.call(root.querySelectorAll("\[role="tab"\]")); var
panels =
Array.prototype.slice.call(root.querySelectorAll("\[role="tabpanel"\]"));
function activate(idx) { tabs.forEach(function(t, i) { var on = (i ===
idx); t.classList.toggle("sym-active", on);
t.setAttribute("aria-selected", on ? "true" : "false");
t.setAttribute("tabindex", on ? "0" : "-1"); });
panels.forEach(function(p, i) { var on = (i === idx);
p.classList.toggle("sym-active", on); if (on) {
p.removeAttribute("hidden"); } else { p.setAttribute("hidden", ""); }
}); if (typeof window.MathJax !== "undefined" &&
window.MathJax.typesetPromise) { try {
window.MathJax.typesetPromise(\[panels\[idx\]\]); } catch (e) {} } }
tabs.forEach(function(t, idx) { t.addEventListener("click", function() {
activate(idx); t.focus(); }); t.addEventListener("keydown", function(e)
{ var k = e.key; var n = tabs.length; var next = null; if (k ===
"ArrowRight") next = (idx + 1) % n; else if (k === "ArrowLeft") next =
(idx - 1 + n) % n; else if (k === "Home") next = 0; else if (k ===
"End") next = n - 1; else if (k === "Enter" \|\| k === " ") {
activate(idx); e.preventDefault(); return; } if (next !== null) {
activate(next); tabs\[next\].focus(); e.preventDefault(); } }); });
})();\</script\>

(The widget renders live in this page. In an R session it opens in the
Viewer pane.)

## What just happened: a recap

[TABLE]

Three observations:

1.  **The same
    [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
    call works on every fit.** No class-specific accessors. The four
    fits cover three different packages (`stats`, `lme4`, `drmTMB`) and
    the user-facing surface is identical.
2.  **The equation block grows exactly where the model grows.** Each
    rung adds *one* concept; the LaTeX line count tells you which.
3.  **The symbolic surface is incrementally readable.** A student who
    just learned `lm` can read Rung 1; a student who just learned random
    effects can read Rung 3 *and* see what Rung 4 adds on top.

The same approach scales to every model class `symbolizer` covers —
`glmmTMB`, `brms`, `MCMCglmm`, `sdmTMB`, `metafor`, `mgcv`. The
educator-facing surface stays one verb deep.

## Where to next

- For factor / interaction pedagogy in depth, see
  [`vignette("symbolizer-factors")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-factors.md).
- For a tour of distributional families (Student-t, Gamma, beta,
  binomial, …), see
  [`vignette("symbolizer-families")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-families.md).
- For meta-analysis with `metafor`, `glmmTMB::propto()`, and `drmTMB`
  location-scale side by side, see
  [`vignette("symbolizer-meta")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-meta.md).
- For the full capability matrix and what’s planned next, see
  [`vignette("symbolizer-roadmap")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-roadmap.md).
