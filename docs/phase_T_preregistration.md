# Phase T: use of the map neighborhood in TP-IM-MOEA (pre-registration)

Registered on 2026-11-02, before any run of this phase. This file fixes the hypotheses, the design, the measures and the decision rule; none of them is changed after the results are seen.

## Motivation

In the final configuration of TP-IM-MOEA (g15), the ordering of the map comes from anchoring its nodes to reference directions, and training updates the winner only. The neighborhood of the map is therefore not used, neither in training nor in reproduction. Earlier tests of the neighborhood (variant NB) applied it during 90% of the epochs of every training call and bundled it with interpolation and niche filling. Phase T tests the neighborhood as a self-organizing map is usually trained: a short ordering phase followed by a winner-only convergence phase. It also tests explicit uses of the neighborhood in reproduction, and reruns, on the final model and under the protocol of the article, the variants examined on the previous version on 2026-10-26.

## Hypotheses

- **H1.** A short neighborhood phase at the start of training improves the map and the search.
- **H2.** Using the decision prototypes of the lattice neighbors of the winner in reproduction improves the search.
- **H3.** The two effects add up.

## Design

Every variant changes only the switches named below of `TPIMMOEA_X` (g15 otherwise). The switches keep the training lattice apart from the reproduction lattice, so a training neighborhood never activates interpolation or niche filling, and they draw no random number when they are 0.

| Factor | Level | Definition |
|---|---|---|
| A, training | A0 | Winner only (g15) |
| | A1 | Gaussian neighborhood on the lattice in the first 10% of the epochs of each training call, radius from 1 to 0.5 hops; winner only afterwards |
| | A2 | The same with 20% of the epochs |
| | A3 | Neighborhood in every epoch during the first 20% of the search budget, radius falling linearly from 1 hop to 0; winner only afterwards |
| B, reproduction | B0 | Decision prototype of the winner as base point (g15) |
| | B1 | Base point drawn among the winner and its 2 nearest trained lattice neighbors; prescreening chooses among the candidates |
| | B2 | Second difference between the decision prototypes of those 2 neighbors: v = x_proto + F(x_r1 − x_r2) + 0.5F(w_k1 − w_k2) |
| | B3 | Second difference between 2 of the 5 archive members nearest to the base point in decision space |

The full factorial gives 16 configurations; A0B0 is g15. Four more variants rerun the questions of 2026-10-26 on the final model:

- **R1 (NeighborDE):** both difference vectors are drawn from the 5 nearest archive members.
- **R2 (DecisionSOM):** the training BMU is chosen by the decision part of the prototypes, and reproduction reads the node with the nearest objective prototype.
- **R3:** R2 with the second difference of B3.
- **R4:** the initial learning rate of each training call falls with the search progress, from η0 to 0.1η0.

A0B3 is the variant NeighborDE_DualF of 2026-10-26.

## Protocol

- **Problems:** WFG1 to WFG9 with m ∈ {3, 6, 9} and d ∈ {10, 100} (54 instances).
- **Settings:** N = 50, hard budget of 300 evaluations, 30 runs.
- **Score:** IGD of the nondominated solutions among all evaluations.
- **Pairing:** every run keeps the output name of the corresponding g15 run of block C1, hence its seed, so each variant is paired run by run with the published g15 runs.
- **Instrumentation:** every run is instrumented (`instr = 1`, which draws no random number).

## Measures

- **Primary:** IGD.
- **Secondary:** the topology of the trained map (rank correlation ρ between lattice and decision-prototype distances, neighborhood overlap, adjacent/nonadjacent distance ratio), the number of nodes never trained, and the optimization time.

## Decision rule

**Stage 1, WFG.** For each of the 19 variants, against g15:

- Wilcoxon rank-sum test per instance (5%), reported as better, worse and similar counts, overall and per m.
- Wilcoxon signed-rank test over the 54 instance means, with Holm's correction over the 19 variants.

A variant qualifies only if both conditions hold:

1. It is significantly better after Holm's correction.
2. Within no group of m (18 instances each) is it significantly worse (signed-rank, 5%).

If several variants qualify, the one with the smallest Holm-adjusted p-value is chosen. Equivalent variants are ordered by simplicity: B only, then A only, then A and B, then R.

**Stage 2, confirmation of the chosen variant.** The chosen variant is run on:

- RWMOP1 to RWMOP35, scored by the HV of N final solutions with the normalization of the article;
- WFG with m ∈ {15, 20};
- the held-out DTLZ suite.

It replaces g15 only if it is not significantly worse than g15 on RWMOP and on m ∈ {15, 20} (Holm over the two suites). The DTLZ suite is not used in the decision and is reported as it comes.

**No variant qualifies.** g15 remains the final configuration, and phase T is reported in the supplementary material as the test of the use of the map neighborhood.

If the final configuration changes, every result of TP-IM-MOEA in the article is regenerated with it; the results of the compared algorithms do not change.
