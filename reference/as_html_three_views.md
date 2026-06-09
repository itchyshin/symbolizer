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
as_html_three_views(
  x,
  head = 5L,
  tail = 2L,
  head_cols = 5L,
  tail_cols = 2L,
  id = "sym",
  standalone = FALSE,
  file = NULL,
  ...
)

# S3 method for class 'symbolized_model_set'
as_html_three_views(
  x,
  head = 5L,
  tail = 2L,
  head_cols = 5L,
  tail_cols = 2L,
  id = "sym",
  standalone = FALSE,
  file = NULL,
  ...
)
```

## Arguments

- x:

  A `symbolized_model` with `$expanded` populated.

- head:

  Number of leading **rows** to show in the matrix view (Tab 3
  "Equations with data") before the `\\vdots` ellipsis. Default `5`.
  Reasonable range 2–10; larger values produce taller widgets.

- tail:

  Number of trailing **rows** to show in the matrix view after the
  `\\vdots`. Default `2`. Together with `head`, controls how much
  per-observation data is visible: total rows shown = `head + tail + 1`
  ellipsis row (or fewer if `n_obs` is small enough to show all rows).

- head_cols:

  Number of leading **columns** to show in any matrix that has more than
  `head_cols + tail_cols` columns (e.g. the `Z`-matrix for a 60-species
  fit). Default `5`. Smart-truncation prefers non-zero columns within
  the visible row band.

- tail_cols:

  Number of trailing **columns** to show after the `\\cdots` ellipsis.
  Default `2`.

- id:

  A short identifier so multiple panels can co-exist on one page.

- standalone:

  If `TRUE`, wrap the fragment in a full HTML document with a MathJax
  CDN bootstrap so the file renders math when opened directly in a
  browser (`file://...`). Default `FALSE` returns the bare fragment for
  embedding in an Rmd / pkgdown / Quarto page where the host document
  already loads MathJax.

- file:

  If non-`NULL`, also write the HTML to this path. Returned value is
  unchanged.

- ...:

  Reserved for future use.

## Value

A character vector (HTML), invisible.

## Details

For a multi-node structural equation model (a `symbolized_model_set`,
the shared parent of `piecewiseSEM`'s `symbolized_psem` and drmSEM's
`symbolized_drm_sem`), the per-node three-views widget is rendered for
each node and stacked under a `<h2>Node: <name></h2>` header. Nodes are
read from `names(x$parts)`, so the same method serves either collator.
