# Phase Y: confirmation of X2, the cell read-out (pre-registration)

Registered on 2026-11-03, before any run of this phase. This file fixes the candidate, the suites, the measures and the decision rule; none of them is changed after the results are seen.

## Origin of the candidate

X2 was a control of phase X: the final configuration (g15) with the read-out on the cell of the parent and winner-only training. The base point is the convex combination of the decision prototypes of the parent's node j and of the m − 1 graph neighbors of j angularly nearest to the parent, among the nodes updated in the current training call. The weights are those whose objective prototypes best reproduce the parent.

On WFG (54 instances, the seeds of block C1), X2 obtained these results:

- against g15: 17/3/34 (better/worse/similar), signed-rank p = 0.037, IGD ratio 0.982;
- against the other algorithms: the best Friedman rank (2.19). It was the only variant of phases T to X significantly better than both PIEA and EGES after Holm.

Because X2 was singled out after these results were seen, WFG cannot confirm it. Phase Y tests it on the three suites of the article that took no part in its selection.

## Candidate

X2 = g15 with `cellRead = 1`. Every other component and parameter is that of g15, including winner-only training and the Das-Dennis directions. Runs are not instrumented.

## Suites

Every task is a g15 task of the article with the same output name, hence the same seed.

| Block | Suite | Settings | Score | Runs |
|---|---|---|---|---|
| Y1 | WFG1 to WFG9 with m ∈ {15, 20}, d ∈ {(m − 1) + 10, 100} | N = 50, 300 evaluations (block C2) | IGD of the nondominated solutions among all evaluations | 1,080 |
| Y2 | RWMOP1 to RWMOP35 | N, m, d and budget of Kumar et al. (block C5) | HV of the final population of size N | 1,050 |
| Y3 | DTLZ1 to DTLZ4 and DTLZ7 with m ∈ {3, 6, 9}, d ∈ {10, 100} | N = 50, 300 evaluations (block D2) | IGD of the nondominated solutions among all evaluations | 900 |

**RWMOP normalization.** The HV is computed with the normalization of the article: the ideal and nadir points of `rwmop_norm.csv`, fixed before this phase and not recomputed with the new runs.

## Measures

- **Effect size:** for each suite, the geometric mean over problems or instances of the ratio of the mean scores. On WFG and DTLZ this is the IGD ratio X2/g15; on RWMOP it is the HV ratio g15/X2. In both cases a value below 1 favors X2.
- **Intervals:** 95% intervals by a cluster bootstrap over problems (10,000 resamples, seed 1, percentile interval).
- **Tests:**
  - Wilcoxon signed-rank test over the instance or problem means;
  - Wilcoxon rank-sum counts per instance (5%);
  - the position against the other algorithms of each suite, with the analysis of the article (Friedman rank, signed-rank with Holm, Vargha-Delaney A12).

## Decision rule

X2 replaces g15 as the final configuration only if both conditions hold:

1. On RWMOP (Y2) and on WFG with m ∈ {15, 20} (Y1), X2 is non-inferior: the upper bound of the interval of the ratio is below 1.03.
2. On neither of these two suites is X2 significantly worse than g15 (signed-rank, Holm over the two suites).

The DTLZ suite (Y3) is reported as it comes and does not take part in the decision, as in phases T to X. A significant loss there is reported and discussed.

**Superiority claims.** If X2 replaces g15, the article may claim superiority over g15 only on a suite where X2 is significantly better (signed-rank, 5%) and the upper bound of its interval is below 1. Elsewhere it claims non-inferiority.

**If the rule is not met,** g15 remains the final configuration. Phase X, including X2, is reported as the test of the topological read-out.

## Consequence if X2 is adopted

Every result of TP-IM-MOEA in the article is regenerated with X2: the ablation, the sensitivity analysis, the budget and population-size studies, the time, and the convergence curves. The results of the compared algorithms do not change.
