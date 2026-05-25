# Simulation recipe for a symbolized model

Returns a structured recipe – pseudocode + runnable R code – explaining
how to simulate data *from* a fitted model. The recipe is family-aware:
it picks the right RNG (`rnorm`, `rbinom`, `rpois`, `rgamma`, `rnbinom`,
...) and lists the draws in the right order (random effects first, then
linear predictor, then response).

The returned object is an S3 list with `pseudocode` (character vector,
one element per step) and `r_code` (single character string, ready to
`eval(parse(text = ...))`).
[`print()`](https://rdrr.io/r/base/print.html) formats it for the
console; `knit_print()` formats it as a fenced R code block plus a
numbered pseudocode list.

This is a teaching surface: the recipe shows the **generative model**,
not the inferential machinery. For a real simulation that round-trips
through the fitted-model object's internals (sampling from posterior,
properly propagating uncertainty), the relevant package's own
[`simulate()`](https://rdrr.io/r/stats/simulate.html) /
`posterior_predict()` /
[`predict()`](https://rdrr.io/r/stats/predict.html) interface is the
right tool.

## Usage

``` r
simulate_recipe(x, n = NULL, seed = NULL, ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).

- n:

  Optional integer; if supplied, the R code uses `n` observations.
  Defaults to `sym$model$n_obs`.

- seed:

  Optional integer; if supplied, the R code begins with
  `set.seed(seed)`.

- ...:

  Reserved for future use.

## Value

A list of class `symbolizer_simulation_recipe` with `pseudocode` and
`r_code` character slots, plus `metadata` for the family and submodel
decomposition.
