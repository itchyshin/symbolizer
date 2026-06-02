# Clear the template cache

Internal helper. Useful in tests that modify templates between calls.

## Usage

``` r
clear_template_cache()
```

## Value

Invisibly returns `NULL`; called for its side effect of emptying the
per-session template cache.
