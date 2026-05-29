# PILOT v2 (review artifact, NOT shipped) — "variance components speak biology".
#
# Standalone demo on REAL fits so the maintainer can see the surface and how it
# would integrate BEFORE anything is wired into the package or the pkgdown site.
# Writes docs/dev-log/pilots/variance-components-pilot.html. Changes NOTHING in
# R/ or inst/. Exploratory prototype; production version is rebuilt test-first.
#
# v2 review feedback folded in:
#   - show BOTH visual options for the variance panel (maintainer picks)
#   - label the quantity "ICC" (repeatability as a secondary gloss)
#   - add the BINOMIAL latent-scale ICC now (residual variance is the known
#     constant: pi^2/3 for logit, 1 for probit). General latent-scale ICC
#     (Poisson etc., needs the log-normal / trigamma approximation) stays later.

suppressMessages({ library(symbolizer); library(lme4) })
fmtv <- function(v) formatC(v, digits = 3, format = "g")
pct  <- function(p) formatC(100 * p, digits = 3, format = "g")

## ---- Example 1: Gaussian random intercept (repeatability) -----------------
set.seed(7)
n_ind <- 30; reps <- 4
ind <- factor(rep(seq_len(n_ind), each = reps), labels = sprintf("liz%02d", seq_len(n_ind)))
assay_temp <- round(rnorm(n_ind * reps, 24, 3), 1)
ug <- rnorm(n_ind, 0, 1.2)[as.integer(ind)]
boldness <- 2.0 + 0.08 * assay_temp + ug + rnorm(n_ind * reps, 0, 0.8)
fitG <- lmer(boldness ~ assay_temp + (1 | ind), data = data.frame(boldness, assay_temp, ind))
symG <- symbolize(fitG)
vcG <- symG$variance_components
var_g <- vcG$var_estimate[vcG$parameter != "residual"][1]
var_e <- vcG$var_estimate[vcG$parameter == "residual"][1]
totG  <- var_g + var_e
iccG  <- var_g / totG
pbG   <- var_g / totG; pwG <- var_e / totG

## ---- Example 2: binomial (Bernoulli) random intercept — latent-scale ICC ---
set.seed(11)
n_nest <- 40; chicks <- 6
nest <- factor(rep(seq_len(n_nest), each = chicks))
temp <- round(rnorm(n_nest * chicks, 20, 4), 1)
ub <- rnorm(n_nest, 0, 1.3)[as.integer(nest)]
surv <- rbinom(n_nest * chicks, 1, plogis(-0.2 + 0.10 * temp + ub))
fitB <- glmer(surv ~ temp + (1 | nest), data = data.frame(surv, temp, nest), family = binomial())
symB <- symbolize(fitB)
vcB <- symB$variance_components
var_nest <- vcB$var_estimate[1]
lat_logit  <- pi^2 / 3                 # logistic latent residual variance
icc_logit  <- var_nest / (var_nest + lat_logit)
icc_probit <- var_nest / (var_nest + 1)

## ---- visual helpers --------------------------------------------------------
# Option A: one horizontal stacked bar (compact; best for 2 components).
bar_stacked <- function(parts) {
  cols <- c("#9a3b3b", "#c9a96b", "#5b7a8c", "#7a9a5b")
  segs <- vapply(seq_along(parts), function(i) {
    p <- parts[[i]]
    sprintf('<div style="width:%s%%;background:%s;text-align:center;%s">%s %s%%</div>',
            pct(p$pct), cols[(i - 1) %% 4 + 1],
            if (i %% 2 == 0) "color:#3a2a10" else "color:#fff",
            p$label, pct(p$pct))
  }, character(1L))
  paste0('<div style="display:flex;height:34px;border-radius:6px;overflow:hidden;',
         'font:600 13px/34px -apple-system,sans-serif;max-width:680px">',
         paste(segs, collapse = ""), '</div>')
}
# Option B: one labelled bar per component (a small bar chart; scales to
# 3+ variance components, e.g. site + plot + residual).
bar_rows <- function(parts) {
  cols <- c("#9a3b3b", "#c9a96b", "#5b7a8c", "#7a9a5b")
  rows <- vapply(seq_along(parts), function(i) {
    p <- parts[[i]]
    sprintf(paste0('<div style="display:flex;align-items:center;gap:.6rem;margin:.25rem 0">',
                   '<div style="width:150px;text-align:right;font-size:.9rem">%s</div>',
                   '<div style="flex:1;background:#eee;border-radius:4px;max-width:430px">',
                   '<div style="width:%s%%;background:%s;height:22px;border-radius:4px"></div></div>',
                   '<div style="width:120px;font-size:.9rem"><strong>%s%%</strong> ',
                   '<span style="color:#888">(&sigma;&sup2;=%s)</span></div></div>'),
            p$label, pct(p$pct), cols[(i - 1) %% 4 + 1], pct(p$pct), fmtv(p$var))
  }, character(1L))
  paste0('<div style="max-width:740px">', paste(rows, collapse = ""), '</div>')
}

partsG <- list(list(label = "between lizards", pct = pbG, var = var_g),
               list(label = "within (residual)", pct = pwG, var = var_e))
partsB_latent <- list(list(label = "between nests", pct = icc_logit, var = var_nest),
                      list(label = "latent residual (&pi;&sup2;/3)", pct = 1 - icc_logit, var = lat_logit))

explain_now <- tryCatch(paste(utils::capture.output(explain(fitG)), collapse = "\n"),
                        error = function(e) paste("explain() error:", conditionMessage(e)))
explain_has_vc <- grepl("variation|variance compon|repeatab|ICC", explain_now, ignore.case = TRUE)

css <- "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;max-width:920px;margin:2rem auto;padding:0 1rem;color:#1a1a1a;line-height:1.55}
h1{font-size:1.5rem}h2{font-size:1.15rem;margin-top:2rem;border-bottom:2px solid #9a3b3b;padding-bottom:.2rem}
h3{font-size:1rem;color:#9a3b3b;margin:1rem 0 .3rem}
.pilot{background:#fff4e5;border:1px solid #e0a85a;border-radius:8px;padding:.7rem 1rem;font-size:.92rem}
.card{background:#faf7f5;border:1px solid #e7ddd7;border-radius:8px;padding:1rem 1.2rem;margin:.8rem 0}
.opt{border:1px dashed #b08; border-radius:8px;padding:.7rem 1rem;margin:.7rem 0;background:#fcfaff}
.opt b{color:#90b}
.bio{color:#1f6feb;background:#f0f5ff;border-left:3px solid #1f6feb;padding:.55rem .8rem;font-style:italic;margin:.6rem 0}
.lat{color:#7a4; background:#f3fbef;border-left:3px solid #4a8; padding:.55rem .8rem;margin:.6rem 0;font-size:.93rem}
table{border-collapse:collapse;width:100%;font-size:.92rem;margin:.5rem 0}
th,td{border:1px solid #ddd;padding:.35rem .6rem;text-align:left}th{background:#f3ece8}
pre{background:#f6f8fa;border:1px solid #e1e4e8;border-radius:6px;padding:.8rem;font-size:.8rem;overflow-x:auto}
.gap{background:#fdecec;border-left:3px solid #c0392b;padding:.4rem .7rem;font-size:.9rem}
.add{background:#e9f7ef;border-left:3px solid #27ae60;padding:.4rem .7rem;font-size:.9rem}
.note{color:#555;font-size:.86rem}"

html <- paste0(
'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">',
'<meta name="viewport" content="width=device-width, initial-scale=1">',
'<title>PILOT v2: variance components speak biology</title>',
'<script>window.MathJax={tex:{inlineMath:[["$","$"]]}};</script>',
'<script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>',
'<style>', css, '</style></head><body>',

'<h1>PILOT v2 &mdash; &ldquo;Variance components speak biology&rdquo;</h1>',
'<div class="pilot"><strong>Review artifact, not shipped.</strong> Lives in <code>docs/dev-log/pilots/</code> ',
'(never <code>docs/articles/</code>); changes nothing in the package. Numbers from real <code>lmer</code> / ',
'<code>glmer</code> fits. This v2 folds in your review: <strong>both visual options</strong> shown for you to ',
'pick, quantity labelled <strong>ICC</strong>, and the <strong>binomial latent-scale ICC</strong> added ',
'(π²/3 logit, 1 probit). General latent-scale ICC (Poisson etc.) stays for later.</div>',

'<h2>A. Gaussian random intercept &mdash; repeatability of boldness</h2>',
'<div class="bio">boldness scored 4&times; on each of 30 lizards: <code>boldness ~ assay_temp + (1 | lizard)</code>.</div>',
'<div class="card"><table><tr><th>component</th><th>variance</th><th>SD</th><th>% of total</th></tr>',
'<tr><td>between lizards</td><td>', fmtv(var_g), '</td><td>', fmtv(sqrt(var_g)), '</td><td><strong>', pct(pbG), '%</strong></td></tr>',
'<tr><td>within (residual)</td><td>', fmtv(var_e), '</td><td>', fmtv(sqrt(var_e)), '</td><td><strong>', pct(pwG), '%</strong></td></tr></table>',

'<h3>Where does the variation live? &mdash; two visual options, pick one</h3>',
'<div class="opt"><b>Option A &mdash; single stacked bar</b> (compact; ideal for between/within):<br><br>', bar_stacked(partsG), '</div>',
'<div class="opt"><b>Option B &mdash; one bar per component</b> (a small bar chart; scales to 3+ components, e.g. site + plot + residual in nested designs):', bar_rows(partsG), '</div>',
'<p>', sprintf("Of the total variation in boldness, about %s%% sits between lizards and about %s%% within them.", pct(pbG), pct(pwG)), '</p>',

'<h3>ICC line</h3>',
'<div class="bio"><strong>ICC = ', fmtv(iccG), '</strong>. Lizards account for ', pct(pbG),
'% of the variation; two boldness scores from the same lizard are correlated about this strongly. ',
'(In a single-random-intercept Gaussian design the ICC <em>is</em> the repeatability.)</div>',
'<p class="note">$\\mathrm{ICC} = \\dfrac{\\sigma^2_{\\mathrm{lizard}}}{\\sigma^2_{\\mathrm{lizard}} + \\sigma^2_{\\varepsilon}} = \\dfrac{',
fmtv(var_g), '}{', fmtv(totG), '} = ', fmtv(iccG), '$ &mdash; a true proportion of variance because the Gaussian residual is on the same (data) scale.</p>',
'<div class="bio">Each û(lizard) is <em>partially pooled</em> &mdash; nudged toward the overall mean; lizards with fewer/noisier scores pulled harder. That borrowing of strength is what <code>(1|lizard)</code> does. <span class="note">(prose only; numeric shrinkage deferred)</span></div></div>',

'<h2>B. Binomial random intercept &mdash; latent-scale ICC (NEW: feasible now)</h2>',
'<div class="bio">nestling survival (0/1), 6 chicks in each of 40 nests: <code>surv ~ temp + (1 | nest)</code>, logit link.</div>',
'<div class="card"><table><tr><th>component</th><th>variance (logit scale)</th><th>SD</th></tr>',
'<tr><td>between nests</td><td>', fmtv(var_nest), '</td><td>', fmtv(sqrt(var_nest)), '</td></tr>',
'<tr><td>latent residual (fixed: π²/3)</td><td>', fmtv(lat_logit), '</td><td>', fmtv(sqrt(lat_logit)), '</td></tr></table>',
'<h3>Latent-scale ICC (logit link)</h3>',
bar_stacked(partsB_latent),
'<div class="lat"><strong>Latent-scale ICC = ', fmtv(icc_logit), '</strong> (logit scale). On the unobserved logit scale, nests account for ',
pct(icc_logit), '% of the variation. The residual variance on this scale is the <em>known</em> logistic constant ',
'$\\pi^2/3 \\approx 3.29$ (it would be $1$ for a probit link &rarr; ICC = ', fmtv(icc_probit), '). ',
'<strong>This is NOT a proportion of variance in the observed 0/1 survival</strong> &mdash; a Bernoulli response has ',
'no single data-scale residual variance, so only the latent-scale reading is honest here.</div>',
'<p class="note">$\\mathrm{ICC}_{\\mathrm{latent}} = \\dfrac{\\sigma^2_{\\mathrm{nest}}}{\\sigma^2_{\\mathrm{nest}} + \\pi^2/3} = \\dfrac{',
fmtv(var_nest), '}{', fmtv(var_nest + lat_logit), '} = ', fmtv(icc_logit), '$</p></div>',

'<h2>C. How it integrates with the existing functions</h2>',
'<div class="card"><p><strong><code>explain(fit)</code> &mdash; current output (excerpt):</strong></p>',
'<pre>', substr(gsub("<", "&lt;", explain_now), 1, 900), '</pre>',
'<div class="', if (explain_has_vc) "add" else "gap", '">',
if (explain_has_vc) "explain() already mentions variation." else
"&#9656; The new &ldquo;How the variation splits&rdquo; panel (chosen bar + ICC line) slots in HERE, after the random effects, reusing the existing knit_print for the table.",
'</div>',
'<div class="add">&#9656; <code>model_card(fit)</code> gains the same panel.</div>',
'<div class="add">&#9656; Three-views widget, <strong>Index tab</strong>: the chosen bar + one sentence beneath the random-effects glossary (plain CSS divs &mdash; no JS, survives PDF).</div>',
'<div class="add">&#9656; <code>variance_partition(sym)</code> &amp; <code>icc(sym)</code>: new accessors beside <code>group_means()</code> / <code>group_slopes()</code> (same family-gate + honest-print contract).</div></div>',

'<h2>D. Honesty contract</h2>',
'<div class="card"><ul>',
'<li><strong>Gaussian-identity</strong> single random intercept &rarr; data-scale ICC &amp; % (a true variance proportion). &check;</li>',
'<li><strong>Binomial (logit/probit)</strong> &rarr; <strong>latent-scale</strong> ICC with the fixed residual ($\\pi^2/3$ or $1$), always explicitly labelled &ldquo;latent scale, not a proportion of observed-outcome variance.&rdquo; &check; (this v2)</li>',
'<li><strong>Poisson / other GLMMs</strong> &rarr; deferred (need the log-normal / trigamma distribution-specific variance). Table shows; ICC line withheld with a one-line &ldquo;not yet on this scale&rdquo; note. &mdash;</li>',
'<li>Every reading: point-estimate-only caveat + reuse <code>few_re_levels</code> / <code>few_groups_wald</code> warnings; all prose from <code>variance-readings.csv</code>.</li>',
'</ul></div>',

'</body></html>')

outdir <- "docs/dev-log/pilots"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
writeLines(html, file.path(outdir, "variance-components-pilot.html"))
cat("WROTE", file.path(outdir, "variance-components-pilot.html"), "\n")
cat(sprintf("Gaussian ICC=%s (between %s%%)  |  Binomial latent ICC logit=%s probit=%s\n",
            fmtv(iccG), pct(pbG), fmtv(icc_logit), fmtv(icc_probit)))
