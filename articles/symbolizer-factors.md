# Reading factors, dummies, and interactions

> *Categorical predictors are where model output most often misleads a
> biologist — `sexmale` is not “average male body mass.” This article is
> for anyone fitting models with factors and interactions; by the end
> you’ll be able to read every dummy-coded coefficient and interaction
> term for what it actually says, and see how
> [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
> spells out the contrast each one encodes.*

A biologist sees `body_mass ~ sex + temperature` and the model fits. The
output table lists a coefficient for `sexmale`. The obvious reading is
“average male body mass” — and the obvious reading is wrong. The
`sexmale` coefficient is something else. This vignette unpacks the
something else, then builds up to interactions, where the unpacking
becomes essential.

We walk through six steps that build on each other. Each step fits a
small `drmTMB` model, looks at the first few rows of the design matrix,
and asks
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
to read each coefficient on the biological scale. The point is to make
the dummy-variable, contrast, and interaction machinery concrete enough
that a reader can apply the same logic to their own fits. A closing
**Common pitfalls** section catches the mistakes biologists most often
make when reading these tables.

``` r

library(symbolizer)
library(drmTMB)
#> 
#> Attaching package: 'drmTMB'
#> The following object is masked from 'package:base':
#> 
#>     beta
```

## Step 1: A binary factor (`body_mass ~ sex`)

Two-level factor, no other predictors. `sex` is `female` or `male`. We
simulate `n = 120` observations with female mass centred at 30 g and
male mass centred at 35 g, then fit:

``` r

n <- 120
sex <- factor(sample(c("female", "male"), n, replace = TRUE))
dat1 <- data.frame(
  body_mass = rnorm(n, 30 + 5 * (sex == "male"), 3),
  sex       = sex
)

fit1 <- drmTMB(
  drm_formula(body_mass ~ sex, sigma ~ 1),
  family = gaussian(),
  data   = dat1
)

sym1 <- symbolize(
  fit1,
  symbols = c(body_mass = "W_i"),
  units   = c(body_mass = "g"),
  context = "binary factor: sex on body mass"
)
```

`expand(sym1)$X` is the design matrix the computer actually multiplies
against the coefficient vector. The first five rows tell the whole
story:

``` r

head(expand(sym1)$X, 5)
#>   (Intercept) sexmale
#> 1           1       0
#> 2           1       0
#> 3           1       0
#> 4           1       0
#> 5           1       1
```

Two columns. The `(Intercept)` column is all 1s, by design. The
`sexmale` column is 0 for females and 1 for males. There is no
`sexfemale` column — `female` is the **reference level**, absorbed into
the intercept.

The symbol dictionary marks the reference level explicitly:

``` r

symbol_table(sym1)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| W_i | \mathbf{w} | body_mass | g | response | \mathbb{R}^n | \mathbb{R}^{120} | response variable |
| \mathrm{sex}\_i | — | sex | NA | factor | column of design matrix | column of X (length 120) | factor (female \[reference\], male) |
| \mu_i | \boldsymbol{\mu} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{120} | conditional mu of body_mass |
| \sigma_i | \boldsymbol{\sigma} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{120} | residual standard deviation |
| \beta\_{0}, \beta\_{1} | \boldsymbol{\beta} | NA | NA | coefficient | \mathbb{R}^{p\_\mu} | \mathbb{R}^{2} | mu submodel coefficients |
| \gamma\_{0} | \boldsymbol{\gamma} | NA | NA | coefficient | \mathbb{R}^{p\_\sigma} | \mathbb{R}^{1} | sigma submodel coefficients |
| — | \mathbf{X} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\mu} | \mathbb{R}^{120 \times 2} | mu submodel design matrix |
| — | \mathbf{X}\_{\sigma} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\sigma} | \mathbb{R}^{120 \times 1} | sigma submodel design matrix |

Look at the `sex [factor]` row’s description:
`factor (female [reference], male)`. That `[reference]` marker is the
single most important piece of context for reading every coefficient
that follows.

Now the readings:

``` r

parameter_interpretation(sym1, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | 95% CI | biological_reading |
|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 29.8 | 29.2, 30.4 \* | Baseline body_mass in the reference condition |
| mu | sex | factor_contrast | 4.99 | 4.11, 5.87 \* | Average body_mass differs between male and female by 4.99 |
| sigma | (Intercept) | intercept | 0.898 | 0.771, 1.02 \* | Baseline level of unexplained individual variation in body_mass |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

Two coefficients on the mu submodel:

- The **intercept** estimate (29.81) is the expected `body_mass` for the
  **reference level**, i.e. females. It is *not* the overall mean of
  `body_mass` — if the sexes were unbalanced the overall mean would
  differ from the female mean.
- The **`sexmale` contrast** estimate (4.99) is the **difference**
  between male and female means. It is *not* the male mean. To get the
  male mean you add the intercept and the contrast:
  `intercept + sexmale` = 34.8.

The biological reading in the table — *“Average body_mass differs
between male and the reference”* — is the same statement in templated
prose.

This is the rule the rest of the vignette builds on. Write it down.

**Takeaway.** A binary factor turns into one 0/1 dummy column. The
intercept is the reference-level mean; the contrast coefficient is the
*difference* from the reference, not the other group’s mean.

## Step 2: A multi-level factor (`body_mass ~ site`)

`sex` had two levels and produced one dummy column. What happens with
four levels? `site` runs `A`, `B`, `C`, `D`:

``` r

site <- factor(sample(c("A", "B", "C", "D"), n, replace = TRUE))
site_mean <- c(A = 30, B = 32, C = 34, D = 27)
dat2 <- data.frame(
  body_mass = rnorm(n, site_mean[site], 3),
  site      = site
)

fit2 <- drmTMB(
  drm_formula(body_mass ~ site, sigma ~ 1),
  family = gaussian(),
  data   = dat2
)

sym2 <- symbolize(
  fit2,
  symbols = c(body_mass = "W_i"),
  units   = c(body_mass = "g"),
  context = "four-level factor: site on body mass"
)
```

The design matrix:

``` r

head(expand(sym2)$X, 5)
#>   (Intercept) siteB siteC siteD
#> 1           1     0     0     1
#> 2           1     0     1     0
#> 3           1     0     1     0
#> 4           1     0     1     0
#> 5           1     0     1     0
```

Four levels, three dummy columns: `siteB`, `siteC`, `siteD`. Reference
is `A`, absorbed into the intercept. The pattern is mechanical: each row
has a 1 in the column matching its level, or zeros everywhere if it is
at the reference.

The symbol dictionary again carries the reference marker:

``` r

symbol_table(sym2)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| W_i | \mathbf{w} | body_mass | g | response | \mathbb{R}^n | \mathbb{R}^{120} | response variable |
| \mathrm{site}\_i | — | site | NA | factor | column of design matrix | column of X (length 120) | factor (A \[reference\], B, C, D) |
| \mu_i | \boldsymbol{\mu} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{120} | conditional mu of body_mass |
| \sigma_i | \boldsymbol{\sigma} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{120} | residual standard deviation |
| \beta\_{0}, \beta\_{1}, \beta\_{2}, \beta\_{3} | \boldsymbol{\beta} | NA | NA | coefficient | \mathbb{R}^{p\_\mu} | \mathbb{R}^{4} | mu submodel coefficients |
| \gamma\_{0} | \boldsymbol{\gamma} | NA | NA | coefficient | \mathbb{R}^{p\_\sigma} | \mathbb{R}^{1} | sigma submodel coefficients |
| — | \mathbf{X} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\mu} | \mathbb{R}^{120 \times 4} | mu submodel design matrix |
| — | \mathbf{X}\_{\sigma} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\sigma} | \mathbb{R}^{120 \times 1} | sigma submodel design matrix |

The `site [factor]` row reads `factor (A [reference], B, C, D)`. And the
coefficients are:

``` r

parameter_interpretation(sym2, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | 95% CI | biological_reading |
|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 30.5 | 29.6, 31.4 \* | Baseline body_mass in the reference condition |
| mu | site | factor_contrast | 1.91 | 0.394, 3.42 \* | Average body_mass differs between B and A by 1.91 |
| mu | site | factor_contrast | 3.41 | 2.20, 4.61 \* | Average body_mass differs between C and A by 3.41 |
| mu | site | factor_contrast | -3.68 | -4.93, -2.42 \* | Average body_mass differs between D and A by -3.68 |
| sigma | (Intercept) | intercept | 0.933 | 0.806, 1.06 \* | Baseline level of unexplained individual variation in body_mass |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

Reading the table by hand:

- **Intercept** = mean of site `A`.
- **`siteB`** = mean of site `B` minus mean of site `A`.
- **`siteC`** = mean of site `C` minus mean of site `A`.
- **`siteD`** = mean of site `D` minus mean of site `A`.

None of the contrast coefficients are group means. Every one is a
*difference from the reference*. If you want the mean of site `C`, you
add `intercept + siteC`. If you want the difference between sites `B`
and `C`, you compute `siteC - siteB` by hand; the table does not give it
directly.

The rule generalises: **`k` levels become `k − 1` dummy columns, which
become `k − 1` contrasts, all measured against the reference**. A factor
with twelve levels would produce eleven dummies — never one per level.

**Takeaway.** A `k`-level factor becomes `k − 1` dummy columns. Each
non-reference contrast is a *difference from the reference*, not a group
mean.

## Step 3: Factor plus continuous predictor (`body_mass ~ sex + body_size`)

Adding a continuous predictor changes what the intercept means. We
re-use `sex` and add `body_size`:

``` r

body_size <- runif(n, 50, 150)
dat3 <- data.frame(
  body_mass = rnorm(n, 30 + 5 * (sex == "male") + 0.2 * body_size, 3),
  sex       = sex,
  body_size = body_size
)

fit3 <- drmTMB(
  drm_formula(body_mass ~ sex + body_size, sigma ~ 1),
  family = gaussian(),
  data   = dat3
)

sym3 <- symbolize(
  fit3,
  symbols = c(body_mass = "W_i", body_size = "L_i"),
  units   = c(body_mass = "g",   body_size = "mm"),
  context = "additive: sex contrast + body_size slope"
)
```

Design matrix:

``` r

head(expand(sym3)$X, 5)
#>   (Intercept) sexmale body_size
#> 1           1       0  60.50070
#> 2           1       0 128.69022
#> 3           1       0  70.47195
#> 4           1       0  77.85910
#> 5           1       1 110.53963
```

Three coefficient columns: `(Intercept)`, `sexmale`, `body_size`. The
shape rule for `X` is now `R^{120 x 3}`. The symbol table makes that
concrete in its design-matrix row:

``` r

symbol_table(sym3)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| W_i | \mathbf{w} | body_mass | g | response | \mathbb{R}^n | \mathbb{R}^{120} | response variable |
| \mathrm{sex}\_i | — | sex | NA | factor | column of design matrix | column of X (length 120) | factor (female \[reference\], male) |
| L_i | — | body_size | mm | predictor | column of design matrix | column of X (length 120) | continuous predictor |
| \mu_i | \boldsymbol{\mu} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{120} | conditional mu of body_mass |
| \sigma_i | \boldsymbol{\sigma} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{120} | residual standard deviation |
| \beta\_{0}, \beta\_{1}, \beta\_{2} | \boldsymbol{\beta} | NA | NA | coefficient | \mathbb{R}^{p\_\mu} | \mathbb{R}^{3} | mu submodel coefficients |
| \gamma\_{0} | \boldsymbol{\gamma} | NA | NA | coefficient | \mathbb{R}^{p\_\sigma} | \mathbb{R}^{1} | sigma submodel coefficients |
| — | \mathbf{X} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\mu} | \mathbb{R}^{120 \times 3} | mu submodel design matrix |
| — | \mathbf{X}\_{\sigma} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\sigma} | \mathbb{R}^{120 \times 1} | sigma submodel design matrix |

Look for the `(design_matrix)` row at the bottom:
`dimension: R^{n × p_mu} (= R^{120 × 3})`. Three coefficients, three
columns.

The coefficient readings:

``` r

parameter_interpretation(sym3, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | 95% CI | biological_reading |
|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 29.9 | 27.9, 32.0 \* | Baseline body_mass in the reference condition |
| mu | sex | factor_contrast | 5.26 | 4.11, 6.42 \* | Average body_mass differs between male and female by 5.26 |
| mu | body_size | slope | 0.197 | 0.177, 0.216 \* | A unit change in body_size shifts the expected body_mass by 0.197 |
| sigma | (Intercept) | intercept | 1.17 | 1.04, 1.29 \* | Baseline level of unexplained individual variation in body_mass |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

The single most important shift from Step 1 is what the intercept now
means. In Step 1 it was *the mean of females*. In Step 3 it is **the
expected `body_mass` for a female at `body_size = 0`**. The intercept is
the reference cell anchored to *both* the reference factor level *and*
the zero of every continuous predictor.

For this fit, `body_size = 0` is not biologically meaningful (no animal
has zero body size), which is why centring continuous predictors is
common practice. After centring, the intercept becomes “expected female
mass at average body size”, which usually is meaningful.

The `sexmale` reading is unchanged in form — *“Average body_mass differs
between male and the reference”* — but its arithmetic is now “at the
same `body_size`”. The contrast is a *vertical shift* of the female
regression line: the male line has the same slope but a different
intercept.

**Takeaway.** Adding a continuous predictor shifts what the intercept
means: it is now the expected response at the reference factor level
*and* at zero of every continuous predictor. The factor contrast is
still a difference from the reference, now read “at the same level of
the continuous predictor(s)”.

### Three views: how the dummy column sits in the X matrix

For a `sex + body_size` fit the design matrix has **three columns** —
intercept, `sexmale` (0 for female, 1 for male), and `body_size` — and
the three-views widget shows exactly that on the matrix-with-data tab:
the `0`s and `1`s of the dummy column sit next to the continuous
`body_size` column, with the coefficient vector \boldsymbol{\beta} =
(\beta_0,\\\beta_1,\\\beta_2)^\top multiplying through:

``` r

as_html_three_views(sym3)
```

[Skip three-views widget](#sym-sym-1781369750-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

**Coefficient reading.** On the response scale, \hat\beta is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

\begin{aligned} W_i \mid \mu_i,\\ \sigma_i & \sim
\mathrm{Normal}(\mu_i,\\ \sigma_i^2) \\ \mu_i & = \beta\_{0} +
\beta\_{1} \\ \[sex = \mathrm{male}\] + \beta\_{2} \\ L_i \\
\log(\sigma_i) & = \gamma\_{0} \end{aligned}

where:

- W_i — response variable  \mathbb{R}^{120}
- \mathrm{sex}\_i — factor (female \[reference\], male)  column of X
  (length 120)
- L_i — continuous predictor  column of X (length 120)
- \mu_i — conditional mu of body_mass  \mathbb{R}^{120}
- \sigma_i — residual standard deviation  \mathbb{R}^{120}
- \beta\_{0}, \beta\_{1}, \beta\_{2} — mu submodel coefficients
   \mathbb{R}^{3}
- \gamma\_{0} — sigma submodel coefficients  \mathbb{R}^{1}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

\begin{aligned} \mathbf{w} \mid \boldsymbol{\mu},\\ \boldsymbol{\sigma}
& \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} \\ \log(\boldsymbol{\sigma}) & = \mathbf{X}\_{\sigma}
\boldsymbol{\gamma} \end{aligned}

where:

- \mathbf{w} — response variable  \mathbb{R}^{120}
- \boldsymbol{\mu} — conditional mu of body_mass  \mathbb{R}^{120}
- \boldsymbol{\sigma} — residual standard deviation  \mathbb{R}^{120}
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{3}
- \boldsymbol{\gamma} — sigma submodel coefficients  \mathbb{R}^{1}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{120 \times 3}
- \mathbf{X}\_{\sigma} — sigma submodel design matrix  \mathbb{R}^{120
  \times 1}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 120.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} w\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\\mathrm{sexmale}\_{1} +
\hat\beta\_{2}\\\mathrm{body\\size}\_{1} + \hat\varepsilon\_{1}
&\quad(\text{response equation, one row of the model}) \\ \hat\mu\_{1}
&= 29.9 + 5.26 \times 0 + 0.197 \times 60.5 \approx 41.8
&\quad(\text{predicted mean} = \text{linear predictor}) \\ w\_{1} &=
\underbrace{41.8}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(-2.36)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 120 observations:

\underbrace{\begin{bmatrix} 39.5 \\ 55.1 \\ 50.4 \\ 46.7 \\ 55.4 \\
\vdots \\ 49.4 \\ 48.7 \end{bmatrix}}\_{\textstyle\\\mathbf{w}\_{\\120
\times 1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 & 0
& 60.5 \\ 1 & 0 & 129 \\ 1 & 0 & 70.5 \\ 1 & 0 & 77.9 \\ 1 & 1 & 111 \\
\vdots & \vdots & \vdots \\ 1 & 0 & 77 \\ 1 & 1 & 103
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\120 \times 3}\\}\\
\underbrace{\begin{bmatrix} 29.9 \\ 5.26 \\ 0.197
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\3 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} -2.36 \\
-0.159 \\ 6.62 \\ 1.51 \\ -1.49 \\ \vdots \\ 4.37 \\ -6.76
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\120
\times 1}\\\text{(residual)}\\}

**Left**: observed vector \mathbf{w}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} = \hat{\boldsymbol{\mu}}. **Right**:
the residual vector \hat{\boldsymbol{\varepsilon}} = \mathbf{w} -
\hat{\boldsymbol{\mu}}. Every row of this matrix equation is one of the
response-equation rows from the worked row above.

And the \sigma submodel (no observed counterpart – \sigma’s job is to
describe the spread of \hat{\boldsymbol{\varepsilon}}). For the same
observation *i* = 1:

\begin{aligned} \log\hat\sigma\_{1} &= \hat\gamma\_{0}
&\quad(\text{sigma submodel for observation 1, log link}) \\
\log\hat\sigma\_{1} &= 1.17 &\quad(\text{with your numbers}) \\
\hat\sigma\_{1} &= \exp(1.17) \approx 3.21 &\quad(\text{predicted
residual SD for observation 1}) \end{aligned}

Stacking the same log-link equation for all *n* = 120 observations:

\log\\\underbrace{\begin{bmatrix} 3.21 \\ 3.21 \\ 3.21 \\ 3.21 \\ 3.21
\\ \vdots \\ 3.21 \\ 3.21
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\sigma}\_{\\120 \times 1}\\}
\\=\\ \underbrace{\begin{bmatrix} 1 \\ 1 \\ 1 \\ 1 \\ 1 \\ \vdots \\ 1
\\ 1 \end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\sigma,\\120 \times
1}\\}\\ \underbrace{\begin{bmatrix} 1.17
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\gamma}\_{\\1 \times 1}\\}

## Step 4: Continuous-by-factor interaction (`body_mass ~ sex * body_size`)

Step 3 forced the male and female regression lines to be parallel.
Adding an interaction lets them have different slopes:

``` r

dat4 <- data.frame(
  body_mass = rnorm(
    n,
    30 + 5 * (sex == "male") + 0.2 * body_size +
      0.05 * (sex == "male") * body_size,
    3
  ),
  sex       = sex,
  body_size = body_size
)

fit4 <- drmTMB(
  drm_formula(body_mass ~ sex * body_size, sigma ~ 1),
  family = gaussian(),
  data   = dat4
)

sym4 <- symbolize(
  fit4,
  symbols = c(body_mass = "W_i", body_size = "L_i"),
  units   = c(body_mass = "g",   body_size = "mm"),
  context = "interaction: sex slope on body_size"
)
```

`sex * body_size` expands to `sex + body_size + sex:body_size`. The
design matrix gains a fourth column for the interaction:

``` r

head(expand(sym4)$X, 5)
#>   (Intercept) sexmale body_size sexmale:body_size
#> 1           1       0  60.50070            0.0000
#> 2           1       0 128.69022            0.0000
#> 3           1       0  70.47195            0.0000
#> 4           1       0  77.85910            0.0000
#> 5           1       1 110.53963          110.5396
```

Four columns: `(Intercept)`, `sexmale`, `body_size`,
`sexmale:body_size`. The interaction column is the **product** of the
`sexmale` dummy and the continuous `body_size` — it is zero for every
female (because the `sexmale` dummy is zero), and equals `body_size` for
every male.

The coefficient table:

``` r

sym4$fixed_effects[, c("term_label", "role", "contrast_level", "estimate")]
#> # A tibble: 5 × 4
#>   term_label    role            contrast_level estimate
#>   <chr>         <chr>           <chr>             <dbl>
#> 1 (Intercept)   intercept       NA              30.9   
#> 2 sex           factor_contrast male             3.04  
#> 3 body_size     predictor       NA               0.198 
#> 4 sex:body_size interaction     male:-           0.0669
#> 5 (Intercept)   intercept       NA               1.11
```

Four coefficients to read. Let us call them \beta_0 (intercept), \beta_1
(`sexmale`), \beta_2 (`body_size`), \beta_3 (`sexmale:body_size`). The
model is

\mathrm{E}(W_i) = \beta_0 + \beta_1 \cdot \mathrm{male}\_i + \beta_2
\cdot L_i + \beta_3 \cdot \mathrm{male}\_i \cdot L_i.

Split it into the two regression lines by setting the `sexmale` dummy to
0 or 1:

- **Females** (`sexmale = 0`): \mathrm{E}(W_i) = \beta_0 + \beta_2 L_i.
  Intercept \beta_0, slope \beta_2.
- **Males** (`sexmale = 1`): \mathrm{E}(W_i) = (\beta_0 + \beta_1) +
  (\beta_2 + \beta_3) L_i. Intercept \beta_0 + \beta_1, slope \beta_2 +
  \beta_3.

So:

- \beta_2 is the **female slope on `body_size`**.
- \beta_2 + \beta_3 is the **male slope**.
- \beta_3 — the interaction coefficient — is the **difference between
  the two slopes**, not the male slope itself.
- \beta_1 — the `sexmale` contrast — is the **difference in intercepts**
  at `body_size = 0`. It is no longer “the average male mass” *or* “the
  male-female mass difference at average body size”.

[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
reads all four templated rows, including the dedicated
continuous-by-factor interaction reading:

``` r

parameter_interpretation(sym4, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | 95% CI | biological_reading |
|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 30.9 | 28.3, 33.5 \* | Baseline body_mass in the reference condition |
| mu | sex | factor_contrast_interaction | 3.04 | -0.801, 6.87 | Because sex interacts with another predictor, the male-vs-female difference in body_mass is not a single number: 3.04 is the difference when the interacting predictor = 0; see group_means() / group_slopes() for the marginal effect. |
| mu | body_size | slope | 0.198 | 0.173, 0.223 \* | A unit change in body_size shifts the expected body_mass by 0.198 |
| mu | sex:body_size | interaction_cont_factor | 0.0669 | 0.0303, 0.104 \* | The effect of body_size on body_mass differs by 0.0669 between male and female. Call `group_slopes(sym, continuous = "body_size")` to see each group’s slope on the response scale, with confidence intervals. |
| sigma | (Intercept) | intercept | 1.11 | 0.979, 1.23 \* | Baseline level of unexplained individual variation in body_mass |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

The interaction row carries its own templated reading. It is
ecologically the most interesting coefficient in the fit — the slope of
`body_mass` on `body_size` *depends on* `sex`, which is exactly what
“interaction” means.

**Takeaway.** A continuous-by-factor interaction lets each factor level
have its own slope. The interaction coefficient is the *difference in
slopes* between the non-reference level and the reference. The bare
factor contrast is now the difference in intercepts at zero of the
continuous predictor.

## Step 5: Continuous-by-continuous interaction (`body_mass ~ temperature * body_size`)

A continuous-by-continuous interaction lets the slope of one continuous
predictor change with the level of another. There are no dummy columns
here, but the same arithmetic — *the interaction coefficient is a
difference of slopes* — still applies, just on a sliding rather than a
group-by-group basis.

``` r

n_cc <- 80
temperature <- runif(n_cc, 10, 30)
body_size_cc <- runif(n_cc, 50, 150)
dat5cc <- data.frame(
  body_mass   = rnorm(
    n_cc,
    20 + 0.1 * temperature + 0.15 * body_size_cc +
      0.01 * temperature * body_size_cc,
    3
  ),
  temperature = temperature,
  body_size   = body_size_cc
)

fit5cc <- drmTMB(
  drm_formula(body_mass ~ temperature * body_size, sigma ~ 1),
  family = gaussian(),
  data   = dat5cc
)

sym5cc <- symbolize(
  fit5cc,
  symbols = c(body_mass = "W_i", temperature = "T_i", body_size = "L_i"),
  units   = c(body_mass = "g",   temperature = "°C", body_size = "mm"),
  context = "continuous-by-continuous interaction"
)
```

`temperature * body_size` expands to
`temperature + body_size + temperature:body_size`. The design matrix has
four coefficient columns — no zeros and ones this time, just two real
numbers and their product:

``` r

head(expand(sym5cc)$X, 5)
#>   (Intercept) temperature body_size temperature:body_size
#> 1           1    29.16281  86.29011             2516.4624
#> 2           1    16.92139  56.04983              948.4407
#> 3           1    28.43270 133.12635             3785.1415
#> 4           1    15.27872  99.52173             1520.5642
#> 5           1    29.48147 140.69294             4147.8343
```

The four columns are `(Intercept)`, `temperature`, `body_size`, and
`temperature:body_size`. The interaction column is literally the product
of the other two predictor columns.

Call the four coefficients \beta_0, \beta_1, \beta_2, \beta_3 in column
order. The model is

\mathrm{E}(W_i) = \beta_0 + \beta_1 T_i + \beta_2 L_i + \beta_3 T_i L_i.

Re-arrange to isolate the slope of `temperature`:

\mathrm{E}(W_i) = \beta_0 + (\beta_1 + \beta_3 L_i) T_i + \beta_2 L_i.

The slope of `temperature` is \beta_1 + \beta_3 L_i — it depends on
`body_size`. Reading the four coefficients in those terms:

- **\beta_0 (intercept)** = expected `body_mass` when `temperature = 0`
  and `body_size = 0`.
- **\beta_1 (`temperature`)** = the `temperature` slope *at*
  `body_size = 0`. Not “the temperature slope”. The slope at one
  specific value of `body_size`.
- **\beta_2 (`body_size`)** = the `body_size` slope *at*
  `temperature = 0`. Same reasoning.
- **\beta_3 (`temperature:body_size`)** = how much the `temperature`
  slope changes per one-unit increase in `body_size`. Equivalently, how
  much the `body_size` slope changes per one-unit increase in
  `temperature`. The two readings are symmetric.

For the cont-by-factor interaction in Step 4 we could call
`group_slopes(sym, continuous = "body_size")` to see one slope per sex.
The continuous-by-continuous equivalent asks for the slope of
`temperature` at *specific values* of `body_size`:

``` r

group_slopes(
  sym5cc,
  continuous = "temperature",
  at = list(body_size = c(50, 100, 150))
)
```

**Group slopes for `temperature`**

| predictor   | level_combo   | body_size | estimate | scale    | 95% CI          |
|:------------|:--------------|----------:|:---------|:---------|:----------------|
| temperature | body_size=50  |        50 | 0.671    | response | 0.410, 0.932 \* |
| temperature | body_size=100 |       100 | 1.11     | response | 0.988, 1.23 \*  |
| temperature | body_size=150 |       150 | 1.55     | response | 1.34, 1.75 \*   |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

Three rows, each the `temperature` slope at a different `body_size`,
with confidence intervals. The slope rises as `body_size` rises — the
sign of \beta_3 tells you whether the interaction amplifies or dampens
the `temperature` effect.

**Takeaway.** A continuous-by-continuous interaction means *the slope of
one continuous predictor changes with the level of another*. Use
`group_slopes(sym, continuous = ..., at = list(other = ...))` to read
the slope at specific values, the same way
[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
and `group_slopes(at = factor)` work for categorical strata.

## Step 6: Factor-by-factor interaction (`body_mass ~ site * sex`)

The hardest case: two factors interacting. `site` has four levels and
`sex` has two, so the fitted-cell table has `4 × 2 = 8` entries. We
generate data with site-specific male offsets so the interaction is not
zero:

``` r

site_offset_male <- c(A = 0, B = 1.5, C = -1.0, D = 2.5)
dat5 <- data.frame(
  body_mass = rnorm(
    n,
    30 + site_mean[site] - 30 + 5 * (sex == "male") +
      site_offset_male[site] * (sex == "male"),
    3
  ),
  site = site,
  sex  = sex
)

fit5 <- drmTMB(
  drm_formula(body_mass ~ site * sex, sigma ~ 1),
  family = gaussian(),
  data   = dat5
)

sym5 <- symbolize(
  fit5,
  symbols = c(body_mass = "W_i"),
  units   = c(body_mass = "g"),
  context = "two factors interacting: site and sex"
)
```

`site * sex` expands to `site + sex + site:sex` and produces eight
coefficient columns. The first five rows:

``` r

head(expand(sym5)$X, 5)
#>   (Intercept) siteB siteC siteD sexmale siteB:sexmale siteC:sexmale
#> 1           1     0     0     1       0             0             0
#> 2           1     0     1     0       0             0             0
#> 3           1     0     1     0       0             0             0
#> 4           1     0     1     0       0             0             0
#> 5           1     0     1     0       1             0             1
#>   siteD:sexmale
#> 1             0
#> 2             0
#> 3             0
#> 4             0
#> 5             0
```

Eight columns: `(Intercept)`, `siteB`, `siteC`, `siteD`, `sexmale`,
`siteB:sexmale`, `siteC:sexmale`, `siteD:sexmale`. Two references — `A`
for site, `female` for sex — are absorbed into the intercept. The
interaction columns are products of the site dummy and the `sexmale`
dummy: a `B-male` row has 1s in both `siteB` and `siteB:sexmale`.

The coefficient table:

``` r

sym5$fixed_effects[, c("term_label", "role", "contrast_level", "estimate")]
#> # A tibble: 9 × 4
#>   term_label  role            contrast_level estimate
#>   <chr>       <chr>           <chr>             <dbl>
#> 1 (Intercept) intercept       NA               29.7  
#> 2 site        factor_contrast B                 3.66 
#> 3 site        factor_contrast C                 4.44 
#> 4 site        factor_contrast D                -2.62 
#> 5 sex         factor_contrast male              4.94 
#> 6 site:sex    interaction     B:male            0.276
#> 7 site:sex    interaction     C:male           -2.13 
#> 8 site:sex    interaction     D:male            3.16 
#> 9 (Intercept) intercept       NA                1.03
```

Reading the eight coefficients in cell terms (write \bar W\_{s,x} for
the population mean at site `s`, sex `x`):

- **Intercept** = \bar W\_{A,\mathrm{female}} — site `A`, female.
- **`siteB`**, **`siteC`**, **`siteD`** = site mean minus site `A` mean,
  *for females*: \bar W\_{B,\mathrm{female}} - \bar
  W\_{A,\mathrm{female}}, and so on.
- **`sexmale`** = male minus female *at site `A`*: \bar
  W\_{A,\mathrm{male}} - \bar W\_{A,\mathrm{female}}.
- **`siteB:sexmale`** is the part that needs the most care. It is (\bar
  W\_{B,\mathrm{male}} - \bar W\_{B,\mathrm{female}}) - (\bar
  W\_{A,\mathrm{male}} - \bar W\_{A,\mathrm{female}}).

That last line is the *difference of two differences*. The male-female
gap at site `B`, minus the male-female gap at site `A`. If
`siteB:sexmale > 0`, the male advantage is *bigger* at site `B` than at
site `A`. If it is negative, the male advantage is *smaller* (or
reversed) at `B` compared to `A`.

This is what “the effect of sex depends on site” means in coefficients.
It is also why a factor-by-factor interaction is hard to read off a
summary table without the cell-mean translation.

The biological readings
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
carries cover the intercept and the per-term contrasts; interaction-row
prose is shipped via the `interpretation-templates.csv` and
[`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md)
/
[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
gives you the cell-mean translation on demand:

``` r

parameter_interpretation(sym5, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | 95% CI | biological_reading |
|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 29.7 | 28.4, 31.1 \* | Baseline body_mass in the reference condition |
| mu | site | factor_contrast_interaction | 3.66 | 1.16, 6.15 \* | Because site interacts with another predictor, the B-vs-A difference in body_mass is not a single number: 3.66 is the difference when the interacting predictor = 0; see group_means() / group_slopes() for the marginal effect. |
| mu | site | factor_contrast_interaction | 4.44 | 2.55, 6.33 \* | Because site interacts with another predictor, the C-vs-A difference in body_mass is not a single number: 4.44 is the difference when the interacting predictor = 0; see group_means() / group_slopes() for the marginal effect. |
| mu | site | factor_contrast_interaction | -2.62 | -4.51, -0.730 \* | Because site interacts with another predictor, the D-vs-A difference in body_mass is not a single number: -2.62 is the difference when the interacting predictor = 0; see group_means() / group_slopes() for the marginal effect. |
| mu | sex | factor_contrast_interaction | 4.94 | 2.92, 6.95 \* | Because sex interacts with another predictor, the male-vs-female difference in body_mass is not a single number: 4.94 is the difference when the interacting predictor = 0; see group_means() / group_slopes() for the marginal effect. |
| mu | site:sex | interaction_factor_factor | 0.276 | -3.10, 3.65 | The site effect on body_mass differs by 0.276 between sex = male and sex = female. Call `group_means(sym, by = c("site", "sex"))` to see each cell’s expected response with confidence intervals. |
| mu | site:sex | interaction_factor_factor | -2.13 | -4.80, 0.534 | The site effect on body_mass differs by -2.13 between sex = male and sex = female. Call `group_means(sym, by = c("site", "sex"))` to see each cell’s expected response with confidence intervals. |
| mu | site:sex | interaction_factor_factor | 3.16 | 0.380, 5.95 \* | The site effect on body_mass differs by 3.16 between sex = male and sex = female. Call `group_means(sym, by = c("site", "sex"))` to see each cell’s expected response with confidence intervals. |
| sigma | (Intercept) | intercept | 1.03 | 0.905, 1.16 \* | Baseline level of unexplained individual variation in body_mass |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

Each of the three interaction rows carries its own templated
*difference-of-differences* reading;
[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
gives the cell-mean translation on demand.

**Takeaway.** A factor-by-factor interaction coefficient is a
*difference of differences*: how much the gap between two non-reference
cells differs from the corresponding gap in the reference rows. The bare
factor contrasts now apply *only* at the other factor’s reference level.

## Common pitfalls

The six steps above cover the mechanics. The six pitfalls below cover
the *readings* — every one is a sentence we have heard a biologist say
out loud about their own fit. Each pitfall has the same structure:
**Symptom** (what goes wrong), **Diagnosis** (why), a code block showing
the wrong reading then the right one, and a one-sentence **Rule of
thumb** to carry away.

### Pitfall 1: The intercept is not “the average response”

**Symptom.** A reviewer asks what the intercept means; the author
answers “the average body mass”. The number is way off compared to
`mean(dat$body_mass)`, and now everyone is confused.

**Diagnosis.** With `body_mass ~ sex + body_size`, the intercept is the
expected response *at the reference level of every factor and at zero on
every continuous predictor*. For a fit with `sex = factor(female, male)`
that means “expected `body_mass` for a FEMALE at `body_size = 0`”. It is
not the overall mean unless the sexes are balanced and `body_size` is
already centred at zero.

``` r

n_p1 <- 80
sex_p1 <- factor(sample(c("female", "male"), n_p1, replace = TRUE))
bs_p1  <- runif(n_p1, 50, 150)
dat_p1 <- data.frame(
  body_mass = rnorm(n_p1, 30 + 5 * (sex_p1 == "male") + 0.2 * bs_p1, 3),
  sex       = sex_p1,
  body_size = bs_p1
)
fit_p1 <- drmTMB(
  drm_formula(body_mass ~ sex + body_size, sigma ~ 1),
  family = gaussian(), data = dat_p1
)
sym_p1 <- symbolize(fit_p1, context = "intercept reading")

# WRONG: read the intercept as the grand mean.
#   "the average body mass is 12.0 g" -- it is not.
# RIGHT: read the intercept as the reference cell.
#   symbol_table() flags the reference level so this is auditable.
symbol_table(sym_p1)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| \mathrm{body\\mass}\_i | \mathbf{body\\mass} | body_mass | NA | response | \mathbb{R}^n | \mathbb{R}^{80} | response variable |
| \mathrm{sex}\_i | — | sex | NA | factor | column of design matrix | column of X (length 80) | factor (female \[reference\], male) |
| \mathrm{body\\size}\_i | — | body_size | NA | predictor | column of design matrix | column of X (length 80) | continuous predictor |
| \mu_i | \boldsymbol{\mu} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{80} | conditional mu of body_mass |
| \sigma_i | \boldsymbol{\sigma} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{80} | residual standard deviation |
| \beta\_{0}, \beta\_{1}, \beta\_{2} | \boldsymbol{\beta} | NA | NA | coefficient | \mathbb{R}^{p\_\mu} | \mathbb{R}^{3} | mu submodel coefficients |
| \gamma\_{0} | \boldsymbol{\gamma} | NA | NA | coefficient | \mathbb{R}^{p\_\sigma} | \mathbb{R}^{1} | sigma submodel coefficients |
| — | \mathbf{X} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\mu} | \mathbb{R}^{80 \times 3} | mu submodel design matrix |
| — | \mathbf{X}\_{\sigma} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\sigma} | \mathbb{R}^{80 \times 1} | sigma submodel design matrix |

**Rule of thumb.** *Read the intercept as the expected response at the
reference factor level and zero on every continuous predictor.*

### Pitfall 2: A factor contrast is not the group’s mean

**Symptom.** A paper sentence says “male body mass is 5 g (sexmale
coefficient)”. A reader checks `mean(body_mass[sex == "male"])` and gets
~35 g. The sentence is wrong.

**Diagnosis.** The `sexmale` coefficient is the *difference* between the
male and female cell means, not the male mean. The male mean is
`(Intercept) + sexmale`. `group_means(sym, by = "sex")` returns each
cell mean directly with a confidence band, which is what most readers
actually wanted.

``` r

n_p2 <- 80
sex_p2 <- factor(sample(c("female", "male"), n_p2, replace = TRUE))
dat_p2 <- data.frame(
  body_mass = rnorm(n_p2, 30 + 5 * (sex_p2 == "male"), 3),
  sex       = sex_p2
)
fit_p2 <- drmTMB(
  drm_formula(body_mass ~ sex, sigma ~ 1),
  family = gaussian(), data = dat_p2
)
sym_p2 <- symbolize(fit_p2, context = "contrast vs cell mean")

# WRONG: read the sexmale coefficient as the male mean.
sym_p2$fixed_effects[, c("term_label", "estimate")]
#> # A tibble: 3 × 2
#>   term_label  estimate
#>   <chr>          <dbl>
#> 1 (Intercept)    30.0 
#> 2 sex             5.35
#> 3 (Intercept)     1.02

# RIGHT: ask for the cell means directly.
group_means(sym_p2, by = "sex")
```

**Group means**

| level_combo | sex    | estimate | scale    | 95% CI        |
|:------------|:-------|:---------|:---------|:--------------|
| sex=female  | female | 30.0     | response | 29.1, 30.9 \* |
| sex=male    | male   | 35.3     | response | 34.5, 36.1 \* |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

**Rule of thumb.** *Coefficients on factor levels are differences from
the reference; use `group_means(sym)` to see the group means
themselves.*

### Pitfall 3: An interaction is not “the effect of A on B”

**Symptom.** A methods section says “the interaction tests whether sex
has an effect on body size”. That is a category error — sex does not
*have an effect on* body size; the interaction tests whether the slope
of one predictor depends on the level of the other.

**Diagnosis.** For `body_mass ~ sex * body_size`, the
`sexmale:body_size` coefficient is the *difference between the male and
female slopes of `body_size`*, not “the effect of sex on body_size”. The
honest reading is “the slope of `body_size` is X for females and X + Y
for males”. `group_slopes(sym, continuous = "body_size")` returns the
per-group slopes directly.

``` r

n_p3 <- 80
sex_p3 <- factor(sample(c("female", "male"), n_p3, replace = TRUE))
bs_p3  <- runif(n_p3, 50, 150)
dat_p3 <- data.frame(
  body_mass = rnorm(
    n_p3,
    30 + 5 * (sex_p3 == "male") + 0.2 * bs_p3 +
      0.05 * (sex_p3 == "male") * bs_p3,
    3
  ),
  sex       = sex_p3,
  body_size = bs_p3
)
fit_p3 <- drmTMB(
  drm_formula(body_mass ~ sex * body_size, sigma ~ 1),
  family = gaussian(), data = dat_p3
)
sym_p3 <- symbolize(fit_p3, context = "interaction wording")

# WRONG: "the sexmale:body_size coefficient is the effect of sex on body_size."
# RIGHT: it is the difference in body_size slopes between male and female.
group_slopes(sym_p3, continuous = "body_size")
```

**Group slopes for `body_size`**

| predictor | level_combo | sex    | estimate | scale    | 95% CI          |
|:----------|:------------|:-------|:---------|:---------|:----------------|
| body_size | sex=female  | female | 0.192    | response | 0.154, 0.230 \* |
| body_size | sex=male    | male   | 0.222    | response | 0.180, 0.265 \* |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

**Rule of thumb.** *The interaction coefficient is the difference
between the two effects, not either effect alone; use
`group_slopes(sym, continuous = ...)` to read each group’s slope.*

### Pitfall 4: Wald CIs can be too narrow with few groups

**Symptom.** A fit with `(1 | site)` and only six sites reports very
tight confidence bands on the fixed effects. The bands look more precise
than the data could justify, and a reviewer asks how they were computed.

**Diagnosis.** drmTMB’s default is `ci_method = "wald"`, which uses an
asymptotic normal approximation. When `sd(site)` is estimated from only
a handful of groups, the asymptotic regime has not kicked in, and Wald
intervals over-state precision. Profile-likelihood intervals are honest
but slower to compute. The flag lives on
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
so the choice is recorded on `x$metadata$ci_method` and propagates to
every downstream reading.

``` r

# WRONG: take the default Wald CI when only a few groups inform sd(site).
sym_wald <- symbolize(fit, ci_method = "wald")

# RIGHT: ask for a profile CI — slower, but honest.
sym_prof <- symbolize(fit, ci_method = "profile")
```

**Rule of thumb.** *When `sd(group)` is estimated from few groups, pass
`ci_method = "profile"` to
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
for an honest interval.*

### Pitfall 5: Dropping the intercept doesn’t always do what you think

**Symptom.** A user wants every cell mean directly, types
`y ~ 0 + sex + site` thinking it will give all `sex × site` cell means,
and then is surprised when the coefficients still look like contrasts.

**Diagnosis.** `y ~ 0 + sex` with one factor *does* give cell means
directly (one coefficient per level). But adding a second predictor,
e.g. `y ~ 0 + sex + site`, gives “sex cell means PLUS site contrasts
from the reference site”. The non-orthogonality between two factors
without an intercept is rarely what the reader wanted.
`group_means(sym, by = c("sex", "site"))` returns every cell mean
correctly regardless of how the formula was written.

``` r

n_p5 <- 100
sex_p5  <- factor(sample(c("female", "male"), n_p5, replace = TRUE))
site_p5 <- factor(sample(c("A", "B", "C"), n_p5, replace = TRUE))
dat_p5 <- data.frame(
  body_mass = rnorm(n_p5, 30 + 5 * (sex_p5 == "male"), 3),
  sex       = sex_p5,
  site      = site_p5
)

# WRONG: drop the intercept and hope to read all 6 cell means off the table.
fit_p5_wrong <- drmTMB(
  drm_formula(body_mass ~ 0 + sex + site, sigma ~ 1),
  family = gaussian(), data = dat_p5
)

# RIGHT: keep the intercept in, fit ~ sex * site, then use group_means().
fit_p5_right <- drmTMB(
  drm_formula(body_mass ~ sex * site, sigma ~ 1),
  family = gaussian(), data = dat_p5
)
sym_p5 <- symbolize(fit_p5_right, context = "all cell means")
group_means(sym_p5, by = c("sex", "site"))
```

**Group means**

| level_combo        | sex    | site | estimate | scale    | 95% CI        |
|:-------------------|:-------|:-----|:---------|:---------|:--------------|
| sex=female, site=A | female | A    | 29.7     | response | 28.4, 31.0 \* |
| sex=male , site=A  | male   | A    | 36.2     | response | 34.8, 37.7 \* |
| sex=female, site=B | female | B    | 29.0     | response | 27.3, 30.6 \* |
| sex=male , site=B  | male   | B    | 35.6     | response | 34.1, 37.0 \* |
| sex=female, site=C | female | C    | 30.4     | response | 28.9, 31.9 \* |
| sex=male , site=C  | male   | C    | 34.9     | response | 33.2, 36.6 \* |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

**Rule of thumb.** *With two or more factors, the safest way to get all
cell means is `group_means(sym, by = c(...))`, not a hand-built
intercept-less formula.*

### Pitfall 6: `poly(x, 2)` and `I(x^2)` are not the same

**Symptom.** A paper reports “the slope of body_size was 0.18 g/mm
(`poly(body_size, 2)1` coefficient)”. The number happens to match an
expected linear slope, so it looks fine — but the column is the *first
orthogonal polynomial of `body_size`*, not the raw linear term.

**Diagnosis.** `poly(x, 2)` produces two ORTHOGONAL columns: a
combination of x and x^2 scaled so the two columns are uncorrelated. The
first column is *not* “the slope of x”. By contrast `I(x^2)` puts the
literal x^2 column into the design matrix alongside a separate linear x
term, and now the linear coefficient *is* the slope at x = 0. The two
parameterisations carry the same information but their coefficient
*interpretations* differ. Use whichever fits your story.

``` r

n_p6 <- 80
bs_p6 <- runif(n_p6, -1, 1)
dat_p6 <- data.frame(
  body_mass = rnorm(n_p6, 30 + 0.2 * bs_p6 + 0.5 * bs_p6^2, 1),
  body_size = bs_p6
)

# WRONG: read the poly() column as a literal linear slope.
fit_p6_poly <- drmTMB(
  drm_formula(body_mass ~ poly(body_size, 2), sigma ~ 1),
  family = gaussian(), data = dat_p6
)
sym_p6_poly <- symbolize(fit_p6_poly, context = "orthogonal polynomial")

# RIGHT: use I(x^2) when you want a literal quadratic reading.
fit_p6_raw <- drmTMB(
  drm_formula(body_mass ~ body_size + I(body_size^2), sigma ~ 1),
  family = gaussian(), data = dat_p6
)
sym_p6_raw <- symbolize(fit_p6_raw, context = "raw quadratic")

symbol_table(sym_p6_poly)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| \mathrm{body\\mass}\_i | \mathbf{body\\mass} | body_mass | NA | response | \mathbb{R}^n | \mathbb{R}^{80} | response variable |
| \mathrm{body\\size}\_i | — | body_size | NA | transformation | column of design matrix | column of X (length 80) | predictor (poly-transformed) |
| \mu_i | \boldsymbol{\mu} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{80} | conditional mu of body_mass |
| \sigma_i | \boldsymbol{\sigma} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{80} | residual standard deviation |
| \beta\_{0}, \beta\_{1}, \beta\_{2} | \boldsymbol{\beta} | NA | NA | coefficient | \mathbb{R}^{p\_\mu} | \mathbb{R}^{3} | mu submodel coefficients |
| \gamma\_{0} | \boldsymbol{\gamma} | NA | NA | coefficient | \mathbb{R}^{p\_\sigma} | \mathbb{R}^{1} | sigma submodel coefficients |
| — | \mathbf{X} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\mu} | \mathbb{R}^{80 \times 3} | mu submodel design matrix |
| — | \mathbf{X}\_{\sigma} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\sigma} | \mathbb{R}^{80 \times 1} | sigma submodel design matrix |

``` r

symbol_table(sym_p6_raw)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| \mathrm{body\\mass}\_i | \mathbf{body\\mass} | body_mass | NA | response | \mathbb{R}^n | \mathbb{R}^{80} | response variable |
| \mathrm{body\\size}\_i | — | body_size | NA | predictor | column of design matrix | column of X (length 80) | continuous predictor |
| \mathrm{body\\size^2}\_i | — | body_size^2 | NA | transformation | column of design matrix | column of X (length 80) | predictor (I-transformed) |
| \mu_i | \boldsymbol{\mu} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{80} | conditional mu of body_mass |
| \sigma_i | \boldsymbol{\sigma} | NA | NA | parameter | \mathbb{R}^n | \mathbb{R}^{80} | residual standard deviation |
| \beta\_{0}, \beta\_{1}, \beta\_{2} | \boldsymbol{\beta} | NA | NA | coefficient | \mathbb{R}^{p\_\mu} | \mathbb{R}^{3} | mu submodel coefficients |
| \gamma\_{0} | \boldsymbol{\gamma} | NA | NA | coefficient | \mathbb{R}^{p\_\sigma} | \mathbb{R}^{1} | sigma submodel coefficients |
| — | \mathbf{X} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\mu} | \mathbb{R}^{80 \times 3} | mu submodel design matrix |
| — | \mathbf{X}\_{\sigma} | NA | NA | design_matrix | \mathbb{R}^{n \times p\_\sigma} | \mathbb{R}^{80 \times 1} | sigma submodel design matrix |

**Rule of thumb.** *Use `poly(x, 2)` when you want orthogonal columns
(uncorrelated polynomial terms); use `I(x^2)` when you want a literal
quadratic interpretation.*

## One call: `explain_factors()`

Steps 1–6 unpack the coding by hand. In day-to-day use you can get the
whole story in a single call.
[`explain_factors()`](https://itchyshin.github.io/symbolizer/reference/explain_factors.md)
states each factor’s coding scheme in plain language, then shows the
per-group means and the pairwise comparisons; for interactions it prints
the cells or per-group slopes directly, so you never have to add
coefficients by hand.

``` r

explain_factors(sym2)
```

## Factors

### site

`site` has 4 levels (A, B, C, D). R uses A as the baseline and adds 3
indicator column(s); each coefficient is the difference from A, not that
group’s own mean.

**Group means**

| level_combo | site | estimate | std_error | confint_low | confint_high | excludes_zero | ci_method | scale |
|:---|:---|---:|---:|---:|---:|:---|:---|:---|
| site=A | A | 30.47159 | 0.4640327 | 29.56211 | 31.38108 | TRUE | wald | response |
| site=B | B | 32.37782 | 0.6164314 | 31.16964 | 33.58601 | TRUE | wald | response |
| site=C | C | 33.87874 | 0.4018641 | 33.09110 | 34.66638 | TRUE | wald | response |
| site=D | D | 26.79645 | 0.4424378 | 25.92929 | 27.66361 | TRUE | wald | response |

**Pairwise contrasts**

| contrast | level_combo | estimate | std_error | confint_low | confint_high | excludes_zero | ci_method | scale | method | adjust | effect_type |
|:---|:---|---:|---:|---:|---:|:---|:---|:---|:---|:---|:---|
| A - B |  | -1.906230 | 0.7715659 | -3.418472 | -0.3939889 | TRUE | wald | response | pairwise | none | difference |
| A - C |  | -3.407147 | 0.6138575 | -4.610285 | -2.2040082 | TRUE | wald | response | pairwise | none | difference |
| A - D |  | 3.675143 | 0.6411533 | 2.418506 | 4.9317809 | TRUE | wald | response | pairwise | none | difference |
| B - C |  | -1.500916 | 0.7358549 | -2.943166 | -0.0586675 | TRUE | wald | response | pairwise | none | difference |
| B - D |  | 5.581374 | 0.7587746 | 4.094203 | 7.0685447 | TRUE | wald | response | pairwise | none | difference |
| C - D |  | 7.082290 | 0.5977006 | 5.910819 | 8.2537620 | TRUE | wald | response | pairwise | none | difference |

The pairwise question — *which sites differ from each **other**?*, not
just each versus the reference — is answered by
[`group_contrasts()`](https://itchyshin.github.io/symbolizer/reference/group_contrasts.md).
It reports compatibility bands and never p-values; pass
`adjust = "tukey"` for simultaneous (family-wise) intervals.

``` r

group_contrasts(sym2, by = "site")
#> 
#> ── Group contrasts (pairwise) ──
#> 
#> A - B estimate = "-1.91" (-3.42, -0.394) *
#> A - C estimate = "-3.41" (-4.61, -2.20) *
#> A - D estimate = "3.68" (2.42, 4.93) *
#> B - C estimate = "-1.50" (-2.94, -0.0587) *
#> B - D estimate = "5.58" (4.09, 7.07) *
#> C - D estimate = "7.08" (5.91, 8.25) *
#> Intervals are per-contrast, not family-wise; pass adjust = "tukey" for
#> simultaneous bands. Scale: response. CI method: wald. Adjustment: none. Rows
#> marked `*` have a 95% interval that excludes the null.
```

For a web-facing version, `as_html_factor_views(sym2)` renders the same
story as a four-tab interactive widget — coding scheme, group means,
pairwise, interactions — with Confidence-Eye uncertainty bands.

``` r

as_html_factor_views(sym2)
```

[Skip factor-views widget](#symfv-symfv-1781369753-end)

▸1. Coding scheme

▸2. Group means

▸3. Pairwise

▸4. Interactions

How each categorical predictor is entered into the model.

level ★ = reference (baseline)

site

A ★BCD

treatment coding · 3 indicator columns

`site` has 4 levels (A, B, C, D). R uses A as the baseline and adds 3
indicator column(s); each coefficient is the difference from A, not that
group’s own mean.

Each group’s expected response, with a 95% compatibility interval.

site

site=A![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMjMuNCIgeTE9IjMiIHgyPSIyMy40IiB5Mj0iMjciIGNsYXNzPSJmdi1udWxsIj48L2xpbmU+PHJlY3QgeD0iMjczLjQiIHk9IjkiIHdpZHRoPSIxNS40IiBoZWlnaHQ9IjEyIiByeD0iMyIgY2xhc3M9ImZ2LXJlZ2lvbiIgLz48Y2lyY2xlIGN4PSIyODEuMSIgY3k9IjE1IiByPSI0LjUiIGNsYXNzPSJmdi1wdCBmdi1wdC1zaWciPjwvY2lyY2xlPjwvc3ZnPg==)30.5
(29.6, 31.4) ⋆

site=B![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMjMuNCIgeTE9IjMiIHgyPSIyMy40IiB5Mj0iMjciIGNsYXNzPSJmdi1udWxsIj48L2xpbmU+PHJlY3QgeD0iMjg3IiB5PSI5IiB3aWR0aD0iMjAuNCIgaGVpZ2h0PSIxMiIgcng9IjMiIGNsYXNzPSJmdi1yZWdpb24iIC8+PGNpcmNsZSBjeD0iMjk3LjIiIGN5PSIxNSIgcj0iNC41IiBjbGFzcz0iZnYtcHQgZnYtcHQtc2lnIj48L2NpcmNsZT48L3N2Zz4=)32.4
(31.2, 33.6) ⋆

site=C![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMjMuNCIgeTE9IjMiIHgyPSIyMy40IiB5Mj0iMjciIGNsYXNzPSJmdi1udWxsIj48L2xpbmU+PHJlY3QgeD0iMzAzLjIiIHk9IjkiIHdpZHRoPSIxMy4zIiBoZWlnaHQ9IjEyIiByeD0iMyIgY2xhc3M9ImZ2LXJlZ2lvbiIgLz48Y2lyY2xlIGN4PSIzMDkuOSIgY3k9IjE1IiByPSI0LjUiIGNsYXNzPSJmdi1wdCBmdi1wdC1zaWciPjwvY2lyY2xlPjwvc3ZnPg==)33.9
(33.1, 34.7) ⋆

site=D![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMjMuNCIgeTE9IjMiIHgyPSIyMy40IiB5Mj0iMjciIGNsYXNzPSJmdi1udWxsIj48L2xpbmU+PHJlY3QgeD0iMjQyLjciIHk9IjkiIHdpZHRoPSIxNC43IiBoZWlnaHQ9IjEyIiByeD0iMyIgY2xhc3M9ImZ2LXJlZ2lvbiIgLz48Y2lyY2xlIGN4PSIyNTAiIGN5PSIxNSIgcj0iNC41IiBjbGFzcz0iZnYtcHQgZnYtcHQtc2lnIj48L2NpcmNsZT48L3N2Zz4=)26.8
(25.9, 27.7) ⋆

scale: -2.77 to 37.4

Which levels differ from each other. The dashed line is the null.

site

A -
B![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMTI4LjUiIHkxPSIzIiB4Mj0iMTI4LjUiIHkyPSIyNyIgY2xhc3M9ImZ2LW51bGwiPjwvbGluZT48cmVjdCB4PSI1MC42IiB5PSI5IiB3aWR0aD0iNjguOSIgaGVpZ2h0PSIxMiIgcng9IjMiIGNsYXNzPSJmdi1yZWdpb24iIC8+PGNpcmNsZSBjeD0iODUuMSIgY3k9IjE1IiByPSI0LjUiIGNsYXNzPSJmdi1wdCBmdi1wdC1zaWciPjwvY2lyY2xlPjwvc3ZnPg==)-1.91
(-3.42, -0.394) ⋆

A -
C![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMTI4LjUiIHkxPSIzIiB4Mj0iMTI4LjUiIHkyPSIyNyIgY2xhc3M9ImZ2LW51bGwiPjwvbGluZT48cmVjdCB4PSIyMy40IiB5PSI5IiB3aWR0aD0iNTQuOCIgaGVpZ2h0PSIxMiIgcng9IjMiIGNsYXNzPSJmdi1yZWdpb24iIC8+PGNpcmNsZSBjeD0iNTAuOSIgY3k9IjE1IiByPSI0LjUiIGNsYXNzPSJmdi1wdCBmdi1wdC1zaWciPjwvY2lyY2xlPjwvc3ZnPg==)-3.41
(-4.61, -2.20) ⋆

A -
D![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMTI4LjUiIHkxPSIzIiB4Mj0iMTI4LjUiIHkyPSIyNyIgY2xhc3M9ImZ2LW51bGwiPjwvbGluZT48cmVjdCB4PSIxODMuNiIgeT0iOSIgd2lkdGg9IjU3LjMiIGhlaWdodD0iMTIiIHJ4PSIzIiBjbGFzcz0iZnYtcmVnaW9uIiAvPjxjaXJjbGUgY3g9IjIxMi4yIiBjeT0iMTUiIHI9IjQuNSIgY2xhc3M9ImZ2LXB0IGZ2LXB0LXNpZyI+PC9jaXJjbGU+PC9zdmc+)3.68
(2.42, 4.93) ⋆

B -
C![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMTI4LjUiIHkxPSIzIiB4Mj0iMTI4LjUiIHkyPSIyNyIgY2xhc3M9ImZ2LW51bGwiPjwvbGluZT48cmVjdCB4PSI2MS40IiB5PSI5IiB3aWR0aD0iNjUuNyIgaGVpZ2h0PSIxMiIgcng9IjMiIGNsYXNzPSJmdi1yZWdpb24iIC8+PGNpcmNsZSBjeD0iOTQuMyIgY3k9IjE1IiByPSI0LjUiIGNsYXNzPSJmdi1wdCBmdi1wdC1zaWciPjwvY2lyY2xlPjwvc3ZnPg==)-1.50
(-2.94, -0.0587) ⋆

B -
D![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMTI4LjUiIHkxPSIzIiB4Mj0iMTI4LjUiIHkyPSIyNyIgY2xhc3M9ImZ2LW51bGwiPjwvbGluZT48cmVjdCB4PSIyMjEuOCIgeT0iOSIgd2lkdGg9IjY3LjgiIGhlaWdodD0iMTIiIHJ4PSIzIiBjbGFzcz0iZnYtcmVnaW9uIiAvPjxjaXJjbGUgY3g9IjI1NS43IiBjeT0iMTUiIHI9IjQuNSIgY2xhc3M9ImZ2LXB0IGZ2LXB0LXNpZyI+PC9jaXJjbGU+PC9zdmc+)5.58
(4.09, 7.07) ⋆

C -
D![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iZnYtZXllIiB2aWV3Ym94PSIwIDAgMzQwIDMwIiBwcmVzZXJ2ZWFzcGVjdHJhdGlvPSJub25lIiByb2xlPSJpbWciPjxsaW5lIHgxPSIwIiB5MT0iMTUiIHgyPSIzNDAiIHkyPSIxNSIgY2xhc3M9ImZ2LWF4aXMiPjwvbGluZT48bGluZSB4MT0iMTI4LjUiIHkxPSIzIiB4Mj0iMTI4LjUiIHkyPSIyNyIgY2xhc3M9ImZ2LW51bGwiPjwvbGluZT48cmVjdCB4PSIyNjMuMiIgeT0iOSIgd2lkdGg9IjUzLjQiIGhlaWdodD0iMTIiIHJ4PSIzIiBjbGFzcz0iZnYtcmVnaW9uIiAvPjxjaXJjbGUgY3g9IjI4OS45IiBjeT0iMTUiIHI9IjQuNSIgY2xhc3M9ImZ2LXB0IGZ2LXB0LXNpZyI+PC9jaXJjbGU+PC9zdmc+)7.08
(5.91, 8.25) ⋆

scale: -5.64 to 9.28

Where an effect depends on another predictor: the cells / slopes
directly.

No interactions in this model.

## Closing: a checklist for reading any model with factors

When you see a coefficient table from a model that contains factors,
apply this three-step audit before you interpret anything.

1.  **Identify the reference levels.** Run `symbol_table(sym)` and look
    for the `[reference]` marker in each factor’s `description`. By
    default R uses the alphabetically-first level, but
    [`relevel()`](https://rdrr.io/r/stats/relevel.html) or
    [`contrasts()`](https://rdrr.io/r/stats/contrasts.html) can shift
    that without changing the apparent variable name. The reference
    level is the silent half of every contrast.

2.  **The intercept is the reference cell.** It is the expected response
    when every factor sits at its reference level *and* every continuous
    predictor sits at zero. Centring continuous predictors makes the
    intercept biologically meaningful; until then it is the cell at
    `body_size = 0`, `temperature = 0`, and so on.

3.  **Every contrast and interaction coefficient is a difference from a
    reference.**

    - A bare factor contrast is a difference between two cells of *that*
      factor, at the reference levels of every other factor.
    - An interaction coefficient is a *difference of differences*: the
      gap at the non-reference combination, minus the gap in the
      reference rows.

    No coefficient (except possibly the intercept after centring) is a
    group mean by itself. To get a group mean, add the relevant
    intercept-plus-contrast(s) by hand.

The point of
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
is to make every layer of this translation visible: the design matrix
shows the dummies, the symbol table marks the references, and
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
reads each templated coefficient on the biological scale — including the
continuous-by-factor and factor-by-factor interaction rows.
[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
/
[`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md)
give the cell-mean and per-level-slope translations on demand.
