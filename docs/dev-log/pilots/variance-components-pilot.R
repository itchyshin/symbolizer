# PILOT (review artifact, NOT shipped) — "variance components speak biology".
#
# Standalone demonstration of the proposed Gaussian-first variance-components
# surface on a REAL fit, so the maintainer can see what it looks like and how
# it would integrate with explain() / model_card() / the three-views widget
# BEFORE any of it is wired into the package or the pkgdown articles.
#
# This script writes docs/dev-log/pilots/variance-components-pilot.html.
# It changes NOTHING in R/ or inst/ and emits to dev-log (not docs/articles/),
# so it never reaches the live site. Exploratory prototype: the production
# version will be rebuilt test-first after approval.

suppressMessages({ library(symbolizer); library(lme4) })

## ---- a real, biologically resonant Gaussian mixed model -------------------
## Repeatability of a behaviour: boldness scored 4x on each of 30 lizards,
## with assay temperature as a fixed covariate. The canonical biological use
## of the ICC is exactly this -- among-individual variance / total = repeatability.
set.seed(7)
n_ind <- 30; reps <- 4
ind <- factor(rep(seq_len(n_ind), each = reps), labels = sprintf("liz%02d", seq_len(n_ind)))
assay_temp <- round(rnorm(n_ind * reps, 24, 3), 1)
u <- rnorm(n_ind, 0, 1.2)[as.integer(ind)]
boldness <- 2.0 + 0.08 * assay_temp + u + rnorm(n_ind * reps, 0, 0.8)
dat <- data.frame(boldness, assay_temp, ind)
fit <- lmer(boldness ~ assay_temp + (1 | ind), data = dat)
sym <- symbolize(fit)

fmtv <- function(v) formatC(v, digits = 3, format = "g")
pct  <- function(p) formatC(100 * p, digits = 3, format = "g")

## ---- the proposed variance_partition() accessor (pilot implementation) ----
## Mirrors the group_means()/group_slopes() pattern in R/marginal-estimates.R:
## a small derived-quantity computation over numbers already on the object.
## Gaussian-identity single-random-intercept only (the honest ICC case).
variance_partition_pilot <- function(sym) {
  vc <- sym$variance_components
  fam <- sym$model$family
  link <- "identity"  # pilot: read from submodels in production
  gaussian_ok <- identical(tolower(as.character(fam)), "gaussian")
  re_rows  <- vc[vc$parameter != "residual", , drop = FALSE]
  res_rows <- vc[vc$parameter == "residual", , drop = FALSE]
  single_intercept <- nrow(re_rows) == 1L && grepl("Intercept", re_rows$term[[1L]])
  total <- sum(vc$var_estimate)
  out <- data.frame(
    component  = c(re_rows$group, "within (residual)"),
    sd         = c(re_rows$sd_estimate, res_rows$sd_estimate),
    variance   = c(re_rows$var_estimate, res_rows$var_estimate),
    pct        = c(re_rows$var_estimate, res_rows$var_estimate) / total,
    stringsAsFactors = FALSE
  )
  icc <- if (gaussian_ok && single_intercept)
    re_rows$var_estimate[[1L]] / total else NA_real_
  list(table = out, icc = icc, group = re_rows$group[[1L]],
       gaussian_ok = gaussian_ok, single_intercept = single_intercept)
}
vp <- variance_partition_pilot(sym)

## ---- proposed CSV-templated prose (shown verbatim so the maintainer sees
## ---- that prose lives in a template, not string-spliced in R) -------------
resp <- sym$model$response
group <- vp$group
between_pct <- vp$table$pct[match(group, vp$table$component)]
within_pct  <- vp$table$pct[vp$table$component == "within (residual)"]
partition_sentence <- sprintf(
  "Of the total variation in %s, about %s%% sits between %ss and about %s%% within them.",
  resp, pct(between_pct), group, pct(within_pct))
icc_sentence <- sprintf(
  paste0("Repeatability (ICC) = %s. Two boldness scores from the same %s are ",
         "correlated about this strongly; %ss account for %s%% of the variation. ",
         "(Single random intercept, Gaussian — the case where this is a true ",
         "proportion of variance.)"),
  fmtv(vp$icc), group, group, pct(between_pct))
shrinkage_caption <- sprintf(
  paste0("Each û(%s) is <em>partially pooled</em>: the model nudged it toward the ",
         "overall mean rather than using the raw %s mean — %ss with fewer or noisier ",
         "observations are pulled harder. That borrowing of strength is what ",
         "<code>(1|%s)</code> does."),
  group, group, group, group)

## ---- capture CURRENT explain() output (to show the integration gap) -------
explain_now <- tryCatch(
  paste(utils::capture.output(explain(fit)), collapse = "\n"),
  error = function(e) paste("explain() error:", conditionMessage(e)))
explain_has_vc <- grepl("variation|variance compon|repeatab|ICC", explain_now, ignore.case = TRUE)

## ---- stacked bar (plain divs; no JS; survives PDF) ------------------------
bar <- sprintf(
  paste0('<div style="display:flex;height:34px;border-radius:6px;overflow:hidden;',
         'font:600 13px/34px -apple-system,sans-serif;color:#fff;max-width:680px">',
         '<div style="width:%s%%;background:#9a3b3b;text-align:center">between %ss %s%%</div>',
         '<div style="width:%s%%;background:#c9a96b;text-align:center;color:#3a2a10">within %s%%</div>',
         '</div>'),
  pct(between_pct), group, pct(between_pct), pct(within_pct), pct(within_pct))

vc_rows <- paste(apply(sym$variance_components, 1L, function(r)
  sprintf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
          r[["group"]], r[["term"]], fmtv(as.numeric(r[["sd_estimate"]])),
          fmtv(as.numeric(r[["var_estimate"]])))), collapse = "\n")
vp_rows <- paste(apply(vp$table, 1L, function(r)
  sprintf("<tr><td>%s</td><td>%s</td><td>%s</td><td><strong>%s%%</strong></td></tr>",
          r[["component"]], fmtv(as.numeric(r[["variance"]])),
          fmtv(as.numeric(r[["sd"]])), pct(as.numeric(r[["pct"]])))), collapse = "\n")

css <- "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;max-width:900px;margin:2rem auto;padding:0 1rem;color:#1a1a1a;line-height:1.55}
h1{font-size:1.5rem}h2{font-size:1.15rem;margin-top:2rem;border-bottom:2px solid #9a3b3b;padding-bottom:.2rem}
.pilot{background:#fff4e5;border:1px solid #e0a85a;border-radius:8px;padding:.7rem 1rem;font-size:.92rem}
.card{background:#faf7f5;border:1px solid #e7ddd7;border-radius:8px;padding:1rem 1.2rem;margin:.8rem 0}
.bio{color:#1f6feb;background:#f0f5ff;border-left:3px solid #1f6feb;padding:.55rem .8rem;font-style:italic;margin:.6rem 0}
table{border-collapse:collapse;width:100%;font-size:.92rem;margin:.5rem 0}
th,td{border:1px solid #ddd;padding:.35rem .6rem;text-align:left}th{background:#f3ece8}
pre{background:#f6f8fa;border:1px solid #e1e4e8;border-radius:6px;padding:.8rem;font-size:.82rem;overflow-x:auto}
.gap{background:#fdecec;border-left:3px solid #c0392b;padding:.4rem .7rem;font-size:.9rem}
.add{background:#e9f7ef;border-left:3px solid #27ae60;padding:.4rem .7rem;font-size:.9rem}
.note{color:#555;font-size:.86rem}"

html <- paste0(
'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">',
'<meta name="viewport" content="width=device-width, initial-scale=1">',
'<title>PILOT: variance components speak biology</title>',
'<script>window.MathJax={tex:{inlineMath:[["$","$"]]}};</script>',
'<script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>',
'<style>', css, '</style></head><body>',

'<h1>PILOT &mdash; &ldquo;Variance components speak biology&rdquo;</h1>',
'<div class="pilot"><strong>Review artifact, not shipped.</strong> This page lives in ',
'<code>docs/dev-log/pilots/</code> (never in <code>docs/articles/</code>), changes nothing in the ',
'package, and is here only so you can see what the surface looks like and how it would integrate ',
'before approving. Numbers are from a real <code>lmer</code> fit. Prose shown is what the new ',
'<code>inst/extdata/variance-readings.csv</code> would hold (templated, not string-spliced in R).</div>',

'<div class="bio">The model: boldness scored 4&times; on each of 30 lizards, ',
'<code>boldness ~ assay_temp + (1 | lizard)</code>. A biologist fitting this wants one thing above all: ',
'<em>how repeatable is boldness?</em> &mdash; i.e. how much of the variation is between lizards vs within.</div>',

'<h2>1. What symbolizer extracts today (but never shows the biologist)</h2>',
'<div class="card"><table><tr><th>group</th><th>term</th><th>SD</th><th>variance</th></tr>',
vc_rows, '</table>',
'<div class="gap">These numbers are computed and sit on <code>sym$variance_components</code> &mdash; but ',
'<code>explain()</code> and <code>model_card()</code> omit the table entirely, and there is no ICC / ',
'partition / repeatability prose anywhere. The payoff of the mixed model is dropped on the floor.</div></div>',

'<h2>2. Proposed: <code>variance_partition(sym)</code> accessor</h2>',
'<div class="card">A new derived-quantity accessor (same S3 / family-gate / honest-print pattern as the ',
'existing <code>group_means()</code> / <code>group_slopes()</code>):',
'<table><tr><th>component</th><th>variance</th><th>SD</th><th>% of total</th></tr>', vp_rows, '</table>',
'<p><strong>Where does the variation live?</strong></p>', bar,
'<p style="margin-top:.7rem">', partition_sentence, '</p></div>',

'<h2>3. Proposed: ICC / repeatability line</h2>',
'<div class="card"><div class="bio">', icc_sentence, '</div>',
'<p class="note">Formula shown to the reader on hover/caption: ',
'$R = \\dfrac{\\sigma^2_{\\mathrm{', group, '}}}{\\sigma^2_{\\mathrm{', group, '}} + \\sigma^2_{\\varepsilon}} ',
'= \\dfrac{', fmtv(vp$table$variance[1]), '}{', fmtv(sum(vp$table$variance)), '} = ', fmtv(vp$icc), '$</p></div>',

'<h2>4. Proposed: prose-only shrinkage caption (beside the worked-row BLUP)</h2>',
'<div class="card"><div class="bio">', shrinkage_caption, '</div>',
'<p class="note">Prose only &mdash; no new numbers. Numeric shrinkage % deferred (unstable near zero; honest ',
'only for Gaussian intercept-only).</p></div>',

'<h2>5. How it integrates with the existing functions</h2>',
'<div class="card"><p><strong><code>explain(sym)</code> &mdash; current output:</strong></p>',
'<pre>', gsub("<", "&lt;", explain_now), '</pre>',
'<div class="', if (explain_has_vc) "add" else "gap", '">',
if (explain_has_vc) "explain() already mentions variation." else
"&#9656; The new &ldquo;How the variation splits&rdquo; panel (bar + sentence + ICC line) would slot in HERE, after the random effects, reusing the existing knit_print for the table.",
'</div>',
'<div class="add">&#9656; <code>model_card(sym)</code> gains the same panel under its variance section.</div>',
'<div class="add">&#9656; Three-views widget, <strong>Index tab</strong>: the stacked bar + one sentence render ',
'beneath the random-effects glossary (plain CSS divs &mdash; no JS, survives PDF export).</div>',
'<div class="add">&#9656; <code>variance_partition(sym)</code> is a new public accessor alongside ',
'<code>group_means()</code> / <code>group_slopes()</code> &mdash; same family-gate + honest-print contract.</div></div>',

'<h2>6. Honesty contract (the guardrails)</h2>',
'<div class="card"><ul>',
'<li><strong>Gaussian-identity only</strong> for the % and ICC. This fit qualifies (',
if (vp$gaussian_ok && vp$single_intercept) "gaussian + single random intercept &check;" else "would be refused", ').</li>',
'<li>For a <strong>GLMM</strong> (Poisson/binomial), the data-scale % is <em>refused</em> &mdash; there is no ',
'residual variance on the data scale, so the percentage would be meaningless. The table still shows; the bar does not.</li>',
'<li>Every reading carries a <strong>point-estimate-only</strong> caveat and reuses the existing ',
'<code>few_re_levels</code> / <code>few_groups_wald</code> warnings.</li>',
'<li>All prose comes from <code>variance-readings.csv</code> &mdash; none string-spliced in R.</li>',
'</ul></div>',

'</body></html>')

outdir <- "docs/dev-log/pilots"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
writeLines(html, file.path(outdir, "variance-components-pilot.html"))
cat("WROTE", file.path(outdir, "variance-components-pilot.html"), "\n")
cat("repeatability ICC =", fmtv(vp$icc), " between% =", pct(between_pct), " within% =", pct(within_pct), "\n")
