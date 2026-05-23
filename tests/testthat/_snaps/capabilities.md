# capability_check() rejects drmTMB/gaussian/zi (Planned)

    Code
      symbolizer:::capability_check("drmTMB", "gaussian", "zi")
    Condition
      Error in `symbolizer:::capability_check()`:
      ! `symbolize()` cannot handle class "drmTMB" / family "gaussian" / component "zi": status is "Planned or reserved".
      i See `symbolizer_capabilities()` or the roadmap at <https://itchyshin.github.io/symbolizer/>.

# capability_check() rejects brmsfit/gaussian/mu via wildcard

    Code
      symbolizer:::capability_check("brmsfit", "gaussian", "mu")
    Condition
      Error in `symbolizer:::capability_check()`:
      ! `symbolize()` cannot handle class "brmsfit" / family "gaussian" / component "mu": status is "Planned or reserved".
      i See `symbolizer_capabilities()` or the roadmap at <https://itchyshin.github.io/symbolizer/>.

# capability_check() errors when no entry exists at all

    Code
      symbolizer:::capability_check("nonexistent", "weird", "thing")
    Condition
      Error in `symbolizer:::capability_check()`:
      ! No capability entry for class "nonexistent" / family "weird" / component "thing".
      i Add a row to 'inst/extdata/capabilities.csv' before exporting a method.

