# Index vs matrix notation bridge

Returns the educator-facing translation table that pairs each piece of
the model in index (scalar / element-wise) notation with its matrix-form
counterpart, together with its dimension. This is the surface that lets
readers learn to read both notations side by side without having to
translate by hand.

Columns:

- `concept`: short label, e.g. `"response"`, `"mu_linear_predictor"`.

- `index`: scalar / element-wise LaTeX (e.g.
  `\mu_i = \beta_0 + \beta_1 T_i`).

- `matrix`: bold matrix-form LaTeX (e.g.
  `\boldsymbol{\mu} = \mathbf{X}\boldsymbol{\beta}`).

- `dimension`: LaTeX-formatted shape (e.g. `\mathbb{R}^n`,
  `\mathbb{R}^{n \times p_\mu}`, `scalar`).

## Usage

``` r
notation_bridge(x, ...)
```

## Arguments

- x:

  A `symbolized_model`.

- ...:

  Reserved for future use.

## Value

A tibble with columns `concept`, `index`, `matrix`, `dimension`.
