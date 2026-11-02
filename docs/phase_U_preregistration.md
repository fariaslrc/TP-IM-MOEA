# Phase U: why the prototype is a better base point than the parent (pre-registration)

Registered on 2026-11-02, before any run of this phase. This file fixes the hypotheses, the design, the measures and the analysis; none of them is changed after the results are seen.

## Motivation

In the ablation of the article (block K1), replacing the decision prototype of the parent's region by the parent itself worsens TP-IM-MOEA on 36 of the 54 WFG instances. In the final configuration (g15), the prototype of a region is updated only by the current nondominated (ND) members whose objective vectors fall in that region, the parent included, with a learning rate falling from 0.19 to 0.07 over the 20 epochs of each training call. A region with a single member keeps about 7% of its previous prototype per call. The prototype is therefore close to a running mean of the current ND members of its region, with a short memory of earlier generations. Phase U separates the possible reasons for its advantage over the parent.

## Hypotheses

- **H1 (averaging).** The gain comes from averaging the ND members of the parent's region.
- **H2 (training).** The trained prototype carries information beyond the plain mean of the current members: memory of earlier generations and the weighting introduced by the order of presentation.
- **H3 (another point).** The gain comes from moving the base point from the parent to another point of its region, without averaging.

## Design

Only the base point of reproduction changes; every other component is that of g15. The variants are selected by the switch `baseMode` of `TPIMMOEA_X` (and `topo` for U3), which draws no random number when it is 0.

| Variant | Base point |
|---|---|
| U0_Prototype | Decision prototype of the parent's region (g15) |
| U1_RegionMean | Mean of the decision vectors of the current ND members of the region, the parent included |
| U2_RegionMember | Another ND member of the region drawn at random; the parent when it is alone in the region |
| U3_Parent | The parent itself (`topo = 4`, the variant of block K1) |

## Protocol

- **Problems:** WFG1 to WFG9 with m ∈ {3, 6, 9} and d ∈ {10, 100} (54 instances).
- **Settings:** N = 50, hard budget of 300 evaluations, 30 runs, 6,480 runs in all.
- **Score:** IGD of the nondominated solutions among all evaluations.
- **Pairing:** every run keeps the output name of the corresponding g15 run of block C1, hence its seed, so the four variants are paired run by run with each other and with the published g15 runs.
- **Instrumentation:** every run is instrumented (`instr = 1`, which draws no random number).

## Measures

- **Primary:** IGD.
- **Secondary:** per generation, over all candidates and over the evaluated ones (`metric.protoLog`):
  - the number of ND members in the parent's region and the fraction of parents alone in it;
  - the distances from the prototype to the parent, from the prototype to the region mean, and from the region mean to the parent, in the normalized decision space and divided by the square root of d.

## Analysis

**Checks.**

- U0 must reproduce the IGD of C1 g15 in every run.
- U3 is expected to reproduce the direction of K1, worse than g15 on most instances.

**Comparisons.** Each comparison uses the Wilcoxon signed-rank test over the 54 instance means, with Holm's correction over the four comparisons. Per-instance rank-sum counts (better, worse, similar, 5%) are reported overall and per m.

| | Comparison | Question |
|---|---|---|
| C1 | U1 vs U3 | Does averaging the region beat the parent? (H1) |
| C2 | U0 vs U1 | Does the trained prototype add to the plain mean? (H2) |
| C3 | U2 vs U3 | Does another point of the region beat the parent? (H3) |
| C4 | U1 vs U2 | Does averaging beat a single other member? |

**Reading.**

- H1 is supported if U1 is significantly better than U3 in C1.
- H2 is supported if U0 is significantly better than U1 in C2. If C2 is not significant, the article states that the decision prototype acts as the mean of the current ND decisions of its region, and claims no role for training beyond it.
- H3 is supported if U2 is significantly better than U3 in C3 and C4 is not significant. If U1 is significantly better than U2 in C4, averaging matters beyond moving away from the parent.
- The secondary measures say how often the parent is alone in its region, in which case the prototype is close to the parent, and how far each base point lies from it.

**If U1 is significantly better than U0,** the plain region mean is a better base point than the trained prototype. This is reported as it comes. A change of the final configuration would follow the confirmation stage of phase T: RWMOP and WFG with m ∈ {15, 20}, with no significant loss.

**If phase T changes the final configuration,** phase U is repeated on the new configuration, because a training neighborhood makes each prototype depend on the neighboring regions as well.
