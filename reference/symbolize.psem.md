# Symbolize a piecewiseSEM `psem` fit

Walks the per-node fits inside a
[`piecewiseSEM::psem()`](https://rdrr.io/pkg/piecewiseSEM/man/psem.html)
object and delegates each to `symbolize.<class>()`, returning a
`symbolized_psem` collator that bundles the per-node `symbolized_model`
objects, the node names (response variables, in declared order), and any
declared `%~~%` residual covariance arcs.

## Usage

``` r
# S3 method for class 'psem'
symbolize(fit, symbols = NULL, units = NULL, context = NULL, ...)
```

## Arguments

- fit:

  A
  [`piecewiseSEM::psem()`](https://rdrr.io/pkg/piecewiseSEM/man/psem.html)
  fit.

- symbols:

  Optional named character vector mapping variable names to
  user-supplied LaTeX symbols, e.g.
  `c(body_mass = "W_i", temperature = "T_i")`.

- units:

  Optional named character vector mapping variable names to units, e.g.
  `c(body_mass = "g", temperature = "C")`.

- context:

  Optional short character description of the model, e.g.
  `"avian body-size location-scale model"`.

- ...:

  Reserved for method-specific extra arguments.

## Value

A `symbolized_psem` object with elements `parts` (list of per-node
`symbolized_model`s, named by response variable), `node_names`
(character), `cov_arcs` (character, declared `%~~%` arcs as `"a ~~ b"`
strings), and `metadata`.

## Details

Each node is mean-structure only by construction. For distributional
(location-scale) or multivariate structural equations, use the `drm_sem`
path in the drmSEM package.
