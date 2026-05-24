# Reading factors, dummies, and interactions

A biologist sees `body_mass ~ sex + temperature` and the model fits. The
output table lists a coefficient for `sexmale`. The obvious reading is
“average male body mass” — and the obvious reading is wrong. The
`sexmale` coefficient is something else. This vignette unpacks the
something else, then builds up to interactions, where the unpacking
becomes essential.

We walk through five steps that build on each other. Each step fits a
small `drmTMB` model, looks at the first few rows of the design matrix,
and asks
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
to read each coefficient on the biological scale. The point is to make
the dummy-variable, contrast, and interaction machinery concrete enough
that a reader can apply the same logic to their own fits.

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
| $`W_i`$ | $`\mathbf{w}`$ | body_mass | g | response | $`\mathbb{R}^n`$ | $`\mathbb{R}^{120}`$ | response variable |
| sex_i | — | sex | NA | factor | column of design matrix | column of X (length 120) | factor (female \[reference\], male) |
| $`\mu_i`$ | $`\boldsymbol{\mu}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{120}`$ | conditional mu of body_mass |
| $`\sigma_i`$ | $`\boldsymbol{\sigma}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{120}`$ | conditional sigma of body_mass |
| $`\beta_{0}, \beta_{1}`$ | $`\boldsymbol{\beta}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{2}`$ | mu submodel coefficients |
| $`\gamma_{0}`$ | $`\boldsymbol{\gamma}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\sigma}`$ | $`\mathbb{R}^{1}`$ | sigma submodel coefficients |
| — | $`\mathbf{X}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{120 \times 2}`$ | mu submodel design matrix |
| — | $`\mathbf{Z}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\sigma}`$ | $`\mathbb{R}^{120 \times 1}`$ | sigma submodel design matrix |

Look at the `sex [factor]` row’s description:
`factor (female [reference], male)`. That `[reference]` marker is the
single most important piece of context for reading every coefficient
that follows.

Now the readings:

``` r

parameter_interpretation(sym1, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | biological_reading |
|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 29.8 | Baseline body_mass in the reference condition |
| mu | sex | factor_contrast | 4.99 | Average body_mass differs between male and female by 4.99 |
| sigma | (Intercept) | intercept | 0.898 | Baseline level of unexplained individual variation in body_mass |

Two coefficients on the mu submodel:

- The **intercept** estimate (29.81) is the expected `body_mass` for the
  **reference level**, i.e. females. It is *not* the overall mean of
  `body_mass` — if the sexes were unbalanced the overall mean would
  differ from the female mean.
- The **`sexmale` contrast** estimate (4.99) is the **difference**
  between male and female means. It is *not* the male mean. To get the
  male mean you add:
  `intercept + sexmale = r round(sum(sym1$fixed_effects$estimate[1:2]), 2)`.

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
| $`W_i`$ | $`\mathbf{w}`$ | body_mass | g | response | $`\mathbb{R}^n`$ | $`\mathbb{R}^{120}`$ | response variable |
| site_i | — | site | NA | factor | column of design matrix | column of X (length 120) | factor (A \[reference\], B, C, D) |
| $`\mu_i`$ | $`\boldsymbol{\mu}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{120}`$ | conditional mu of body_mass |
| $`\sigma_i`$ | $`\boldsymbol{\sigma}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{120}`$ | conditional sigma of body_mass |
| $`\beta_{0}, \beta_{1}, \beta_{2}, \beta_{3}`$ | $`\boldsymbol{\beta}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{4}`$ | mu submodel coefficients |
| $`\gamma_{0}`$ | $`\boldsymbol{\gamma}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\sigma}`$ | $`\mathbb{R}^{1}`$ | sigma submodel coefficients |
| — | $`\mathbf{X}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{120 \times 4}`$ | mu submodel design matrix |
| — | $`\mathbf{Z}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\sigma}`$ | $`\mathbb{R}^{120 \times 1}`$ | sigma submodel design matrix |

The `site [factor]` row reads `factor (A [reference], B, C, D)`. And the
coefficients are:

``` r

parameter_interpretation(sym2, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | biological_reading |
|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 30.5 | Baseline body_mass in the reference condition |
| mu | site | factor_contrast | 1.91 | Average body_mass differs between B and A by 1.91 |
| mu | site | factor_contrast | 3.41 | Average body_mass differs between C and A by 3.41 |
| mu | site | factor_contrast | -3.68 | Average body_mass differs between D and A by -3.68 |
| sigma | (Intercept) | intercept | 0.933 | Baseline level of unexplained individual variation in body_mass |

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
| $`W_i`$ | $`\mathbf{w}`$ | body_mass | g | response | $`\mathbb{R}^n`$ | $`\mathbb{R}^{120}`$ | response variable |
| sex_i | — | sex | NA | factor | column of design matrix | column of X (length 120) | factor (female \[reference\], male) |
| $`L_i`$ | — | body_size | mm | predictor | column of design matrix | column of X (length 120) | continuous predictor |
| $`\mu_i`$ | $`\boldsymbol{\mu}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{120}`$ | conditional mu of body_mass |
| $`\sigma_i`$ | $`\boldsymbol{\sigma}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{120}`$ | conditional sigma of body_mass |
| $`\beta_{0}, \beta_{1}, \beta_{2}`$ | $`\boldsymbol{\beta}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{3}`$ | mu submodel coefficients |
| $`\gamma_{0}`$ | $`\boldsymbol{\gamma}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\sigma}`$ | $`\mathbb{R}^{1}`$ | sigma submodel coefficients |
| — | $`\mathbf{X}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{120 \times 3}`$ | mu submodel design matrix |
| — | $`\mathbf{Z}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\sigma}`$ | $`\mathbb{R}^{120 \times 1}`$ | sigma submodel design matrix |

Look for the `(design_matrix)` row at the bottom:
`dimension: R^{n × p_mu} (= R^{120 × 3})`. Three coefficients, three
columns.

The coefficient readings:

``` r

parameter_interpretation(sym3, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | biological_reading |
|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 29.9 | Baseline body_mass in the reference condition |
| mu | sex | factor_contrast | 5.26 | Average body_mass differs between male and female by 5.26 |
| mu | body_size | slope | 0.197 | A unit change in body_size shifts the expected body_mass by 0.197 |
| sigma | (Intercept) | intercept | 1.17 | Baseline level of unexplained individual variation in body_mass |

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

Four coefficients to read. Let us call them $`\beta_0`$ (intercept),
$`\beta_1`$ (`sexmale`), $`\beta_2`$ (`body_size`), $`\beta_3`$
(`sexmale:body_size`). The model is

``` math
\mathrm{E}(W_i) = \beta_0 + \beta_1 \cdot \mathrm{male}_i + \beta_2 \cdot L_i + \beta_3 \cdot \mathrm{male}_i \cdot L_i.
```

Split it into the two regression lines by setting the `sexmale` dummy to
0 or 1:

- **Females** (`sexmale = 0`):
  $`\mathrm{E}(W_i) = \beta_0 + \beta_2 L_i`$. Intercept $`\beta_0`$,
  slope $`\beta_2`$.
- **Males** (`sexmale = 1`): $`\mathrm{E}(W_i) = (\beta_0 + \beta_1) +
  (\beta_2 + \beta_3) L_i`$. Intercept $`\beta_0 + \beta_1`$, slope
  $`\beta_2 + \beta_3`$.

So:

- $`\beta_2`$ is the **female slope on `body_size`**.
- $`\beta_2 + \beta_3`$ is the **male slope**.
- $`\beta_3`$ — the interaction coefficient — is the **difference
  between the two slopes**, not the male slope itself.
- $`\beta_1`$ — the `sexmale` contrast — is the **difference in
  intercepts** at `body_size = 0`. It is no longer “the average male
  mass” *or* “the male-female mass difference at average body size”.

[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
reads the three templated rows it knows about, but v0.1 does not yet
ship an interaction template, so the interaction row is silent:

``` r

parameter_interpretation(sym4, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | biological_reading |
|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 30.9 | Baseline body_mass in the reference condition |
| mu | sex | factor_contrast | 3.04 | Average body_mass differs between male and female by 3.04 |
| mu | body_size | slope | 0.198 | A unit change in body_size shifts the expected body_mass by 0.198 |
| mu | sex:body_size | interaction_cont_factor | 0.0669 | The effect of body_size on body_mass differs by 0.0669 between male and female |
| sigma | (Intercept) | intercept | 1.11 | Baseline level of unexplained individual variation in body_mass |

Read the prose above in place of a templated row. The interaction is
ecologically the most interesting coefficient in the fit — the slope of
`body_mass` on `body_size` *depends on* `sex`, which is exactly what
“interaction” means.

**Takeaway.** A continuous-by-factor interaction lets each factor level
have its own slope. The interaction coefficient is the *difference in
slopes* between the non-reference level and the reference. The bare
factor contrast is now the difference in intercepts at zero of the
continuous predictor.

## Step 5: Factor-by-factor interaction (`body_mass ~ site * sex`)

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
#> 1 (Intercept) intercept       NA               30.6  
#> 2 site        factor_contrast B                 1.59 
#> 3 site        factor_contrast C                 3.77 
#> 4 site        factor_contrast D                -3.72 
#> 5 sex         factor_contrast male              3.42 
#> 6 site:sex    interaction     B:male            4.75 
#> 7 site:sex    interaction     C:male            0.355
#> 8 site:sex    interaction     D:male            5.26 
#> 9 (Intercept) intercept       NA                1.04
```

Reading the eight coefficients in cell terms (write $`\bar W_{s,x}`$ for
the population mean at site `s`, sex `x`):

- **Intercept** = $`\bar W_{A,\mathrm{female}}`$ — site `A`, female.
- **`siteB`**, **`siteC`**, **`siteD`** = site mean minus site `A` mean,
  *for females*:
  $`\bar W_{B,\mathrm{female}} - \bar W_{A,\mathrm{female}}`$, and so
  on.
- **`sexmale`** = male minus female *at site `A`*:
  $`\bar W_{A,\mathrm{male}} -
  \bar W_{A,\mathrm{female}}`$.
- **`siteB:sexmale`** is the part that needs the most care. It is
  $`(\bar W_{B,\mathrm{male}} - \bar W_{B,\mathrm{female}}) -
   (\bar W_{A,\mathrm{male}} - \bar W_{A,\mathrm{female}})`$.

That last line is the *difference of two differences*. The male-female
gap at site `B`, minus the male-female gap at site `A`. If
`siteB:sexmale > 0`, the male advantage is *bigger* at site `B` than at
site `A`. If it is negative, the male advantage is *smaller* (or
reversed) at `B` compared to `A`.

This is what “the effect of sex depends on site” means in coefficients.
It is also why a factor-by-factor interaction is hard to read off a
summary table without the cell-mean translation.

The biological readings v0.1 carries cover only intercept and
non-interaction contrasts:

``` r

parameter_interpretation(sym5, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | biological_reading |
|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 30.6 | Baseline body_mass in the reference condition |
| mu | site | factor_contrast | 1.59 | Average body_mass differs between B and A by 1.59 |
| mu | site | factor_contrast | 3.77 | Average body_mass differs between C and A by 3.77 |
| mu | site | factor_contrast | -3.72 | Average body_mass differs between D and A by -3.72 |
| mu | sex | factor_contrast | 3.42 | Average body_mass differs between male and female by 3.42 |
| mu | site:sex | interaction_factor_factor | 4.75 | The site effect on body_mass differs by 4.75 between sex = male and sex = female |
| mu | site:sex | interaction_factor_factor | 0.355 | The site effect on body_mass differs by 0.355 between sex = male and sex = female |
| mu | site:sex | interaction_factor_factor | 5.26 | The site effect on body_mass differs by 5.26 between sex = male and sex = female |
| sigma | (Intercept) | intercept | 1.04 | Baseline level of unexplained individual variation in body_mass |

Three interaction rows are again silent. Read the cell-mean translations
above in their place.

**Takeaway.** A factor-by-factor interaction coefficient is a
*difference of differences*: how much the gap between two non-reference
cells differs from the corresponding gap in the reference rows. The bare
factor contrasts now apply *only* at the other factor’s reference level.

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
reads each templated coefficient on the biological scale. The
interaction layer is on the template roadmap; until it lands, the
cell-mean translation in this vignette is the manual fallback.
