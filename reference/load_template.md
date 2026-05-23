# Load a template CSV from inst/extdata

Internal helper. Loads a CSV file from the installed `inst/extdata/`
directory. Caches per session in `.symbolizer_template_cache`.

## Usage

``` r
load_template(name)
```

## Arguments

- name:

  File name without extension, e.g. `"interpretation-templates"`.

## Value

A tibble.
