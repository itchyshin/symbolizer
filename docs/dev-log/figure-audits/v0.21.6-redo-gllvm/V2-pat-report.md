# V2 Pat-lens audit — symbolizer-gllvm.html (v0.21.6-redo)

Audit date: 2026-05-28
Auditor: V2 Pat-lens (reader flow + pedagogy)
Target: http://localhost:8767/articles/symbolizer-gllvm.html
Slice: v0.21.6-redo

## Summary verdict

NEEDS FIXES

## One-sentence takeaway per section (the reader's perspective)

- §1 — Biology named before symbols; Takeaway callout clear: "syndromes = between, plasticity = within, one GLLVM." Clear.
- §2 — "40 fish × 3 sessions × 5 traits, two-axis between + one-axis within." Clear.
- §3 — "Univariate R = σ²_u/(σ²_u+σ²_e) is what the GLLVM generalises to T×T matrices per tier." R_t1 = 0.751 concrete. Clear.
- §4 — "Factor-analytic Λ Λ^T + Ψ drops 15 → 9 params for T=5, justifying the structure for small-N studies." Clear.
- §5 — Long/wide side-by-side is good. But full two-tier equations appear here before Widget 1 introduces the simpler fit — weakens the build-up (see F-V2-1).
- §6 — "Widget 1 fits only Σ_B; within-individual residual stays scalar σ_ε." Labelled 'syndromes'. Clear.
- §7 — "Widget 2 adds Λ_W, Ψ_W; σ_ε auto-suppresses." Auto-suppression explained. Clear.
- §8 — "c², ψ*, R_t, and phenotypic-correlation decomposition from the same two matrices." Numbers concrete. Trait names not mapped back to communality output (see F-V2-3).
- §9 — "Λ is identified only up to rotation/sign; Σ is invariant; use varimax." Biologist can absorb. Clear.
- §10 — "Same math in glmmTMB syntax." Syntax table readable. Clear.
- §11 — "Gaussian two-tier shipped; non-Gaussian, uncertainty on Λ, rank selection planned." Clear.

## Widget standalone-readability

### Widget 1 (syndromes only)

- Index tab: Caption is generic — "Each observation is normally distributed around a group-specific mean; the random-effect SD captures how much groups vary." No syndromes or between-individual biology.
- Matrix tab: Same generic biology sentence. No syndrome language.
- Equations-with-data tab: Σ_B numerical decomposition; underbrace labels "between-individual implied covariance." Biologically anchored.
- Can the reader state the biology from just Widget 1? **N.** Only Tab 3 is anchored; Tabs 1–2 use shared GLMM boilerplate.

### Widget 2 (two-tier)

- Index tab: **Identical text and equations to Widget 1 Index.** Neither Λ_W nor Σ_W appears.
- Matrix tab: **Identical to Widget 1 Matrix.** Two-tier matrix form absent.
- Equations-with-data tab: Σ_B and Σ_W blocks + per-trait repeatability [0.747, 0.555, 0.836, 0.62, 0.785] with label "share of trait t's total variance at the between-individual tier." Standalone-readable.
- Can the reader state the biology from just Widget 2? **N.** Tabs 1 and 2 are byte-identical to Widget 1. A reader tabbing between the two widgets on Tab 1 or Tab 2 sees no change.

## Flow breaks (numbered)

- F-V2-1: §5 shows the full two-tier equations (both Λ_B and Λ_W) before Widget 1 introduces the between-only fit. The §6 → §7 step-up is weakened because the reader already saw both tiers in §5.
- F-V2-2: Widget 2 Tabs 1 and 2 are identical to Widget 1 — the sym-biology sentence is the same six-word boilerplate in all six tab slots. A reader on Widget 2 Tab 1 cannot tell which model they are looking at.
- F-V2-3: §8 drops all trait names. extract_communality() returns t1–t5 with no mapping to boldness/exploration/aggression/activity/shelter-use. The loop from §1 is not closed.

## Bugs found (numbered)

- B-V2-1: **Widget 2 Index and Matrix tabs render the Widget-1 (between-only) model.** `sym-twotier-...-panel-idx` and `sym-twotier-...-panel-eq` are character-identical to the Widget 1 panels; neither Λ_W, z_{W,ij}, nor Σ_W appears. The spec (design §4.1–4.2) requires Widget 2 Index to show the full two-tier index equation and Widget 2 Matrix to show Σ_W replacing σ²_ε I_T. This is a structural rendering defect in both Tabs 1 and 2 of Widget 2.
- B-V2-2: All six sym-biology slots carry the identical sentence: "Each observation is normally distributed around a group-specific mean; the random-effect SD captures how much groups vary, and the residual SD captures within-group variation." This is lme4 boilerplate. Per the "Named concept before symbol" principle, each tab needs a biology line specific to its tier and widget.
- B-V2-3: Ψ_B has near-zero entries (3.2e-08, 3.9e-16 in Widget 1; 4.24e-08, 6.51e-16 in Widget 2) with no explanation. A biologist may read these as model failure. A one-sentence callout is needed: t2 and t5 have between-individual variance fully absorbed by the shared loadings.
