# PDF rendering of a symbolized_model in three stacked sections

Paper-ready PDF counterpart to
[`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md).
The same three "views" of one fitted model, laid out vertically as three
sections on one PDF page (no tabs):

1.  **Index form** – the per-observation equations.

2.  **Matrix form** – the same equations in matrix notation.

3.  **Worked observation** – the index-form equations evaluated at
    observation i = 1 of the data, showing the coefficient estimates
    plugged in and the predicted / residual decomposition.

Rendered via
[`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html)
with `output_format = "pdf_document"`; a working LaTeX install (TinyTeX
or system TeX) is required.

The wide matrix-of-numbers view from the HTML widget's third tab is
deliberately not included – on PDF the bmatrix of n x p numbers
overflows a portrait A4 page. The worked-row at i = 1 carries the same
teaching content in a fits-on-one-page form.

## Usage

``` r
as_pdf_three_views(
  x,
  file,
  title = NULL,
  head = 5L,
  tail = 2L,
  head_cols = 5L,
  tail_cols = 2L,
  keep_tex = FALSE,
  ...
)
```

## Arguments

- x:

  A `symbolized_model`.

- file:

  Output path (`.pdf`). Required.

- title:

  Optional document title. Defaults to a short auto-title built from the
  fit's class and response.

- head:

  Number of leading rows shown in any matrix block before the `\\vdots`
  ellipsis (default `5`).

- tail:

  Number of trailing rows shown after the `\\vdots` (default `2`).

- head_cols:

  Number of leading columns shown in any matrix block with more than
  `head_cols + tail_cols` columns (default `5`). Smart-truncation
  prefers non-zero columns within the visible row band.

- tail_cols:

  Number of trailing columns shown after the `\\cdots` ellipsis (default
  `2`).

- keep_tex:

  If `TRUE`, keep the intermediate `.tex` next to the PDF for
  inspection. Default `FALSE`.

- ...:

  Passed to
  [`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html).

## Value

The path to the rendered PDF (invisibly).
