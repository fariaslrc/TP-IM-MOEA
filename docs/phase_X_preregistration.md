# Phase X: TPN, the topology of the map in training and in reproduction (pre-registration)

Registered on 2026-11-03, before any run of this phase. The design was fixed before the results of phase V (delivered on 2026-11-03 at 00:43 and not yet opened) and of phase W (running) were examined. This file fixes the hypotheses, the design, the measures and the decision rule; none of them is changed after the results are seen.

## Motivation

In the final configuration (g15), the decision prototype of a node is, in practice, the mean of the current nondominated decisions of its region, and reproduction reads a single node. The map therefore acts as a regional codebook. Phase T gave three results that shape this phase:

| Comparison (phase T, same seeds as g15) | Result |
|---|---|
| Ordering phase alone (A2B0) against g15 | ρ from 0.335 to 0.373; IGD 2/5/47 (better/worse/similar) |
| Neighbors of the winner as base points, winner-only training (A0B1), against g15 | 1/11/6, 1/11/6 and 1/13/4 for m = 3, 6, 9 |
| The same with the ordering phase (A2B1) against A0B1 | 14/2/2 for m = 3 (signed-rank p = 0.009); 4/6/8 and 3/5/10 for m = 6, 9 |

Cooperative training is what makes the neighbors useful in reproduction for m = 3, as the classical two-phase SOM predicts. The form used in phase T is, however, defective: a neighbor replaced the base point in two of every three candidates, drawn at random, even when the parent lay on the anchor of its own node. That acts like a partial permutation of the anchors, which degrades the search (25% of the anchors: 0/22/32; 50%: 1/32/21).

TPN keeps the ordering phase and replaces the random choice by a read-out that is continuous in the objective space. This is a piecewise-linear inverse model over the cell of the parent.

## Method (TPN)

Every component not named here is that of g15. This includes the BMU by angle, the DE, the kNN prescreening by decomposition and the selection.

**Training.** Each training call has an ordering phase in its first 20% of the epochs: a Gaussian neighborhood on the reference graph, with a radius falling from 1 to 0.5 hops (variant A2 of phase T). The remaining epochs update the winner only. Nodes without data receive updates from their neighbors in the ordering phase.

**Reproduction.**

1. For a parent with BMU j, the cell is j and the m − 1 graph neighbors of j angularly nearest to the parent, among the nodes updated in the current training call.
2. The weights λ are the convex weights (nonnegative, summing to 1) whose combination of the objective prototypes of the cell best reproduces the parent's normalized objective vector. They are computed by nonnegative least squares, and the residual is recorded.
3. The base point is the same combination of the decision prototypes.

When the parent lies at the center of its region, λ concentrates on j and the read-out is that of g15. A neighbor contributes in proportion to the displacement of the parent toward it. For m = 3, the cell is the winner and its two nearest neighbors.

## Design

| Variant | Training | Read-out | Purpose |
|---|---|---|---|
| X1_TPN | Ordering phase | Cell on the graph | The method |
| X2_TPN_noOrd | Winner only | Cell on the graph | Is cooperative training necessary for the read-out? |
| X3_TPN_shuf | Ordering phase | Cell on the graph | The same with the graph of training and read-out permuted once per run: is the correct topology necessary? |
| X4_Prox | Winner only | Cell of the m − 1 nodes nearest to the parent in objective space, without the graph | Codebook control: does the map add anything to a regional codebook? |

**Existing references with the same seeds.** g15 (block C1), A2B0 and A2B1 (block T1) are not rerun.

**Soft controls.** In X3 and X4, the convex weights can reduce the influence of distant partners, so these controls tend toward g15 rather than toward a damaged read-out.

**Random numbers.** The permutation of X3 is drawn with a seed derived from the run's seed, and the random stream is restored.

## Protocol

- **Problems:** WFG1 to WFG9 with m ∈ {3, 6, 9} and d ∈ {10, 100} (54 instances).
- **Settings:** N = 50, hard budget of 300 evaluations, 30 runs, 6,480 runs in all.
- **Score:** IGD of the nondominated solutions among all evaluations.
- **Pairing:** every run keeps the output name of the corresponding g15 run of block C1, hence its seed.
- **Instrumentation:** every run is instrumented (`instr = 1`, which draws no random number).

## Measures

- **Primary:** IGD.
- **Effect size:** the geometric mean over instances of the ratio of instance means, variant / g15.
- **Intervals:** 95% intervals by a cluster bootstrap that resamples the nine WFG problems (10,000 resamples, seed 1, percentile interval), because the 54 instances are not independent.
- **Mechanism (`metric.cellLog`), per generation:** the weight on the neighbors (1 − λ_j), the residual of the convex fit, and the size of the cell.
- **Topology of the final map:** ρ, neighborhood overlap against its random expectation, and the adjacent/nonadjacent distance ratio.
- **Time:** relative to V0 of phase V, run on the same PC.

## Decision rule

**Primary comparison: X1 against g15.** It is a single comparison, so no correction is needed. X1 is **superior** if all three conditions hold:

1. It is significantly better (Wilcoxon signed-rank over the 54 instance means, 5%).
2. The effect is at least a 2% reduction of the IGD (ratio ≤ 0.98), with the upper bound of its interval below 1.
3. In every group of m, the upper bound of the interval of the ratio is below 1.03 (non-inferiority margin of 3%).

**Attribution.** X1 is compared with X2, X3 and X4 (signed-rank, Holm over the three). The topology is **necessary** for the method if X1 is significantly better than all three.

**Outcomes.**

| Result on WFG | Decision |
|---|---|
| Superior, and the topology necessary | TPN replaces g15, subject to the confirmation below |
| Not superior, but non-inferior (upper bound below 1.03 overall and in every group of m) and the topology necessary | TPN may replace g15 as the final configuration, because it uses the topology explicitly and necessarily. The article then states that it does not improve on g15, subject to the confirmation below |
| Any other result | g15 remains the final configuration, and phase X is reported as the test of the topological read-out |

**Confirmation.** It uses suites not used to design the method:

- RWMOP1 to RWMOP35 (HV, ratio g15 / TPN);
- WFG with m ∈ {15, 20} (IGD).

TPN must be non-inferior on both, with the upper bound of the interval below 1.03; the interval is a cluster bootstrap over problems. The held-out DTLZ suite is reported only.

**Secondary comparisons, reported without a decision:**

- X1 against A2B1 (the same training with neighbors drawn at random) and against A2B0 (ordering only);
- all comparisons by group of m and of d;
- the mechanism and topology measures.

**Expectation, stated in advance but not part of the rule:** a gain for m = 3 and non-inferiority for m ≥ 6, where adjacent directions are 18° to 45° apart and the interpolation has little room.
