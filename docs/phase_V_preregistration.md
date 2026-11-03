# Phase V: the reference directions of the map (pre-registration)

Registered on 2026-11-02, before any run of this phase. This file fixes the hypotheses, the design, the measures and the decision rule; none of them is changed after the results are seen.

## Motivation

The map of TP-IM-MOEA has one node per reference direction, and the same directions define the niches of the prescreening by decomposition and of the selection for m ≥ 4. The final configuration (g15) takes the Das-Dennis directions of PlatEMO (`UniformPoint`). With N = 50 they give fewer than N nodes, and none inside the simplex for m = 9.

| m | Das-Dennis directions | Inside the simplex | Angle to the nearest direction |
|---|---|---|---|
| 3 | 45 | 21 | 8° to 16° |
| 6 | 42 | 21 (inner layer) | 18° to 20° |
| 9 | 45 | 0 (9 vertices, 36 midpoints of edges) | 45° |

The weight vectors of MOEA/D-UR (Farias and Araújo, *Swarm and Evolutionary Computation*, 2022) work as follows:

- They start from the M vertices and the centroid of the simplex.
- They then add, one at a time, the candidate farthest from the chosen set among 5,000 random points of the simplex.
- This gives exactly N directions for any m. With N = 50, 47, 44 and 41 of them lie inside the simplex for m = 3, 6 and 9.

Phase V tests whether these directions improve the map and the search. The PlatEMO implementation draws the candidates as normalized uniforms, which are not uniform on the simplex, so a variant with candidates uniform on the simplex (normalized exponentials, Dirichlet(1)) is also tested.

## Hypotheses

- **H1 (coverage and resolution).** Directions that cover the inside of the simplex, with exactly N nodes, improve the search. The largest effect is expected for m = 9.
- **H2 (scope).** The effect comes from the map (the regions of training and reproduction) rather than from the niches of the prescreening and the selection.
- **H3 (candidates).** The distribution of the candidates makes no difference, because the farthest-point selection sets the spacing.

## Design

Each variant changes only the switches `refGen` and `refScope` of `TPIMMOEA_X`; every other component is that of g15. The directions are drawn with a fixed seed of their own and the random stream is restored, so they are the same in every run and the run is not otherwise affected.

| Variant | Directions of the map | Directions of the prescreening and the selection |
|---|---|---|
| V0_DasDennis | Das-Dennis (g15) | Das-Dennis |
| V1_URmap | MOEA/D-UR | Das-Dennis |
| V2_URall | MOEA/D-UR | MOEA/D-UR |
| V3_URDmap | MOEA/D-UR, Dirichlet candidates | Das-Dennis |
| V4_URDall | MOEA/D-UR, Dirichlet candidates | MOEA/D-UR, Dirichlet candidates |

The map graph links each direction to its 2(m − 1) angularly nearest directions for every set. One hop reaches about 10%, 24% and 40% of the other nodes for m = 3, 6 and 9 with the new directions, against 11%, 31% and 40% with Das-Dennis.

**Unavoidable confound.** The new directions also raise the number of nodes from 45, 42 and 45 to 50. No Das-Dennis set gives directions inside the simplex for m = 9 with N = 50, so coverage and number of nodes cannot be separated in this phase.

## Protocol

- **Problems:** WFG1 to WFG9 with m ∈ {3, 6, 9} and d ∈ {10, 100} (54 instances).
- **Settings:** N = 50, hard budget of 300 evaluations, 30 runs, 8,100 runs in all.
- **Score:** IGD of the nondominated solutions among all evaluations.
- **Pairing:** every run keeps the output name of the corresponding g15 run of block C1, hence its seed.
- **Instrumentation:** every run is instrumented (`instr = 1`, which draws no random number).

## Measures

- **Primary:** IGD.
- **Secondary:**
  - the topology of the final map: the rank correlation ρ between lattice and decision-prototype distances, and the neighborhood overlap against its random expectation;
  - the fraction of nodes trained at least once;
  - the time relative to V0, run on the same PC.

## Decision rule

**Check.** V0 must reproduce the IGD of C1 g15 in every run.

**Stage 1, WFG.** Each of V1 to V4 is compared with g15, as in phase T:

- Wilcoxon rank-sum test per instance (5%), reported as better, worse and similar counts, overall and per m.
- Wilcoxon signed-rank test over the 54 instance means, with Holm's correction over the four variants.

A variant qualifies only if both conditions hold:

1. It is significantly better after Holm's correction.
2. Within no group of m is it significantly worse (signed-rank, 5%).

If several variants qualify, the one with the smallest Holm-adjusted p-value is chosen. Equivalent variants are ordered by simplicity: map only before all, normalized uniforms before Dirichlet.

**Stage 2, confirmation.** As in phase T: RWMOP1 to RWMOP35 and WFG with m ∈ {15, 20}, with no significant loss (Holm over the two suites). The held-out DTLZ suite is reported only. For RWMOP, the problem's own N sets the number of directions, so the variant changes the number of nodes there as well.

**Secondary comparisons, reported without a decision:**

- H2: V1 against V2, and V3 against V4.
- H3: V1 against V3, and V2 against V4.
- The groups of m. A variant better only for m = 9 does not replace g15; it motivates a design with directions that depend on m, to be tested separately.

**No variant qualifies.** The Das-Dennis directions remain, and phase V is reported as the test of the resolution of the map.
