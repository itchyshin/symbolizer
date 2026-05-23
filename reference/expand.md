# Expand a symbolized_model to its underlying numeric arrays

`expand()` returns the actual numeric pieces that make up the fitted
model: the response vector, design matrix per submodel, coefficient
vectors, random-effect indicator matrix and BLUPs (when present),
residuals, and the fitted conditional mean and SD vectors. This is the
data side of the
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
surface — the symbolic and matrix views show *what shape* the model has;
`expand()` shows *what numbers* actually flow through it.

Returned object is classed `c("symbolized_expanded", "list")` so it has
a compact [`print()`](https://rdrr.io/r/base/print.html) method.

## Usage

``` r
expand(x, ...)
```

## Arguments

- x:

  A `symbolized_model`.

- ...:

  Reserved for future use.

## Value

A list with elements (NULL when not applicable to this fit):

- `y` response vector of length n

- `X` mu-submodel design matrix (n x p_mu)

- `beta` mu coefficient vector (p_mu)

- `X_sigma` sigma-submodel design matrix (n x p_sigma)

- `gamma` sigma coefficient vector (p_sigma)

- `Z_g` random-effect indicator matrix (n x G), if RE present

- `u` random-effect BLUPs (G), if RE present

- `e` residuals (n)

- `mu_hat` fitted conditional mean (n)

- `sigma_hat` fitted per-observation SD (n)
