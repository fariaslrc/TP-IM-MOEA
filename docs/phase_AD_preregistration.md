# Phase AD: disconnected and irregular fronts (proposals A and B)

*English translation of the preregistration, which was written in Portuguese. Dates, rules, and thresholds are unchanged.*

Date: 2026-11-05. Preregistered before any run of phase AD.

## Motivation

The final model F (X1 with the geometric gate of the ordering phase and the global repair, profile `gated_repair_global`) ranks 7th of 15 on DTLZ. The largest losses are on DTLZ7, whose front is disconnected: F ranks 13th to 14th with m = 6 and 9, and its IGD is 4 to 14 times that of the best competitor. A geometric measurement made before this phase, without optimization: with N = 50, the front of DTLZ7 reaches only 60%, 52%, and 82% of the reference directions for m = 3, 6, and 9 (WFG3, with a degenerate front, 24%, 31%, and 78%; DTLZ2, WFG2, and WFG4, 100%). On DTLZ7 with d = 10, the cell read-out worsens the result relative to g15 with m = 6 and 9.

**Use of DTLZ.** The proposals were motivated by DTLZ results, so DTLZ stops being an independent validation suite. If a proposal is adopted, the article must validate it on a new suite, run once with the model and criteria fixed (proposed: MaF), and state that DTLZ became a development suite.

## Proposals

- **A, unreachable niches (`nicheReach`).** A direction that receives 2 evaluated candidates aimed at it as an empty niche (by niche filling or by the empty-niche priority of prescreening), none of which lands in it, is treated as unreachable for 5 generations: it leaves niche filling and loses the empty-niche priority in prescreening. Any evaluated solution that lands in it reactivates it immediately. Inspiration: adaptive reference vectors for irregular fronts.
- **B, gap-aware read-out (`gapRead`).** A neighbor k of the parent's node j enters the cell only if some nondominated archive member lies on the arc between the directions of j and k (angle to the bisector at most half the j–k angle). The cell thus does not mix regions separated by a gap in the front.
  - **Declared design adjustment, made before any run:** the first version used a quarter of the angle. A geometric test with samples of the true front (50 to 100 nondominated points) showed that it cut most edges also on continuous fronts (DTLZ2 with m = 3: 26% to 48% of the edges kept). With half the angle, continuous fronts keep 85% to 93% of the edges with m = 3 and 6 and about 60% with m = 9, against 30% to 60% on DTLZ7.
- **Control for B (`final_Brand`).** In each generation, it cuts the same number of edges that the test of B would cut, chosen at random, with a private generator that does not alter the main generator.

## Blocks (runs 1 to 30, the same seeds as the article)

| Block | Instances | Profiles | Runs |
|---|---|---|---:|
| AD1 | WFG m = 3, 6, 9 (54) | final_A, final_B, final_AB, final_Brand | 6,480 |
| AD2 | WFG m = 15, 20 (36) | the same four | 4,320 |
| AD3 | DTLZ1–4, 7, m = 3, 6, 9 (30) | the same four | 3,600 |
| AD4 | RWMOP1–35 | final_A, final_B, final_AB | 3,150 |

Reference for every comparison: F (X1 of phase X on WFG m ≤ 9, X2 of phase Y on WFG m = 15/20, X1 of phase AB on DTLZ, `gated_repair_global` of block AC4 on RWMOP). The smoke test checks that the new code does not change F.

## Criteria (fixed now)

1. **Improvement on DTLZ:** signed-rank test paired by instance against F, with Holm's correction over final_A, final_B, and final_AB; Holm p < 0.05 in favor of the proposal, and IGD ratio with the upper bound of the 95% CI below 1 (cluster bootstrap over problems, 10,000 resamples, seed 1).
2. **Non-inferiority on the other suites:** upper bound of the CI below 1.03 on WFG m = 3 to 9, on WFG m = 15/20, and on each m; on RWMOP, no problem with a loss of mean HV above 0.01 and a signed-rank test not significantly unfavorable (5%).
3. **Choice:** if final_AB meets 1 and 2, it is adopted; otherwise, between final_A and final_B, the one that meets 1 and 2 with the smallest ratio on DTLZ; if none does, F remains.
4. **Attribution of B to continuity:** final_B against final_Brand on DTLZ (signed-rank, 5%). If the control ties, the gain of B comes from cutting edges, not from the continuity test, and the text must say so.
5. **Reported separately:** DTLZ7 alone, by m and d, and the position against the 15 algorithms on every suite.

*Outcome, recorded after the runs (analysis in `analysis/analyze_ad.py`): no proposal met criteria 1 and 2, so F remains the final model (Table S20 of the supplementary material).*
