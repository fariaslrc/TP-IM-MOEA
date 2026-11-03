# Phase AA: one evaluation per generation and a larger archive (pre-registration)

Registered on 2026-11-03, before any run of this phase. This file fixes the hypotheses, the design, the measures and the decision rule; none of them is changed after the results are seen.

## Motivation

With 300 evaluations and a batch of B0 = 10, the final configuration (g15) updates its map only 25 times. PIEA, its closest competitor, evaluates one solution per iteration and refits its model after each evaluation, and it beats g15 on most WFG instances with m = 3. In the sensitivity analysis of the article, a smaller batch tends to help: against B0 = 10, B0 = 5 obtained 2/0/6 (better/worse/similar, IGD ratio 0.987) and B0 = 20 obtained 0/2/6 (1.010), on eight instances.

The archive has a capacity of 2N = 100. The IGD is computed on all evaluations, so the capacity does not change the score directly. It does change the search: which nondominated solutions train the map, and what the environmental selection discards.

## Hypotheses

- **H1 (batch).** One evaluation per generation improves the search under small budgets.
- **H2 (archive).** An archive that keeps every evaluated solution, so that the map is trained on every nondominated solution found, improves the search.
- **H3.** The two effects combine.

## Design

Every variant changes only the switches `batchOne` and `arcCap` of `TPIMMOEA_X`; every other component is that of g15.

| Variant | Evaluations per generation | Archive capacity |
|---|---|---|
| AA0_g15 | 10 (g15) | 2N = 100 (g15) |
| AA1_batch1 | 1 | 100 |
| AA2_arc300 | 10 | 300 |
| AA3_both | 1 | 300 |

**batchOne.** The variant applies only when the budget does not exceed Θ = 1000, the threshold below which g15 does not adapt its batch. One evaluation is then made per generation. It is chosen by the prescreening among the same pool of K × B0 = 50 candidates generated with the base batch, so the pool is not reduced. With larger budgets, as on RWMOP, nothing changes.

**arcCap = 300.** With 300 evaluations, no solution is ever discarded. The map is trained, as in g15, on the nondominated members of the archive, which are then all the nondominated solutions found. Dominated solutions remain available to the DE and to the kNN predictor.

**AA0.** It reruns g15 on the same PC, without instrumentation. Its IGD must equal that of block C1 run by run, and its time is the reference for the times of this block.

## Protocol

- **Problems:** WFG1 to WFG9 with m ∈ {3, 6, 9} and d ∈ {10, 100} (54 instances).
- **Settings:** N = 50, hard budget of 300 evaluations, 30 runs, 6,480 runs in all.
- **Score:** IGD of the nondominated solutions among all evaluations.
- **Pairing:** every run keeps the output name of the corresponding g15 run of block C1, hence its seed.

## Measures

- **Primary:** IGD.
- **Effect size:** the geometric mean over instances of the ratio of instance means, with a 95% cluster-bootstrap interval over the nine WFG problems (10,000 resamples, seed 1).
- **Time:** relative to AA0.
- **Secondary:** the position against the other algorithms with the analysis of the article, overall and for m = 3.

## Decision rule

**Check.** AA0 must reproduce the IGD of C1 g15 in every run.

**Primary comparisons.** AA1, AA2 and AA3 are each compared with g15 (signed-rank over the 54 instance means, Holm over the three). A variant is **superior** if all three conditions hold:

1. It is significantly better after Holm's correction.
2. Its IGD ratio is at most 0.98, with the upper bound of its interval below 1.
3. In every group of m, the upper bound of its interval is below 1.03.

If several variants are superior, the simplest is chosen: AA1 or AA2 before AA3, and between AA1 and AA2 the one with the smaller ratio.

**Factorial reading, reported without a decision:**

- the batch effect: AA1 against g15 and AA3 against AA2;
- the archive effect: AA2 against g15 and AA3 against AA1.

**Confirmation of a superior variant.** It runs on the suites that took no part in the selection, with the tasks and seeds of the article:

- WFG with m ∈ {15, 20};
- DTLZ (300 evaluations);
- RWMOP, for variants with arcCap only. With batchOne alone, RWMOP is unchanged by construction.

The variant replaces g15 only if it is non-inferior on each of these suites, with the upper bound of the interval below 1.03. On RWMOP, the HV ratio is computed on the problems in which both algorithms find a feasible final set in at least half of the runs. This rule is fixed here because, in phase Y, problems with almost no feasible set made the ratio undefined.

**No variant is superior.** g15 remains, and phase AA is reported as the test of the batch size and of the archive.
