# Three-views HTML rendering of a symbolized_model

Returns a single self-contained HTML string with three tabs over the
same fit:

1.  **Equation** – matrix-form structural equations.

2.  **Index** – per-observation equations.

3.  **Matrix (with data)** – the actual numeric arrays from the fit,
    with head + tail rows visible and `...` in the middle.

Designed to be [`cat()`](https://rdrr.io/r/base/cat.html)-ed inside an
Rmd / Quarto chunk with `results = 'asis'`. The host document supplies
math rendering (MathJax / KaTeX via pandoc); this function emits
semantic HTML, inline CSS, and a small tab-switching script.

## Usage

``` r
as_html_three_views(x, head = 5L, tail = 2L, id = "sym", ...)
```

## Arguments

- x:

  A `symbolized_model` with `$expanded` populated.

- head:

  Number of leading rows to show in the matrix view (default 5).

- tail:

  Number of trailing rows to show in the matrix view (default 2).

- id:

  A short identifier so multiple panels can co-exist on one page.

- ...:

  Reserved for future use.

## Value

A character vector (HTML), invisible.
