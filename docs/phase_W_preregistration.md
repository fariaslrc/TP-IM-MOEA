# Phase W: uses of the topology of the map in reproduction (pre-registration)

Registered on 2026-11-02, before any run of this phase. This file fixes the hypotheses, the design, the measures and the decision rule; none of them is changed after the results are seen.

## Motivation

Phases T and U showed how the final configuration (g15) uses the map:

- Reproduction reads a single node, the node of the parent's region.
- The decision prototype of that node is, in practice, the mean of the current nondominated decisions of the region.
- The map therefore acts as a piecewise-constant inverse model, the role a codebook such as k-means could also play.
- A better-ordered map does not give a better search: the rank correlation between the topology measure ρ and the IGD is about 0.

The topology can matter only if reproduction uses the relations between nodes. Phase W tests two such uses, each with a control that removes the topology.

1. **Gap filling.** A map on a fixed lattice defines a model for regions without data, from their neighbors. A codebook has no units where there are no data, so it cannot do this.
2. **Piecewise-linear read-out.** The base point is interpolated between adjacent prototypes instead of being the prototype of one region. For a smooth inverse map on a mesh of size h, the approximation error falls from O(h) to O(h²). A codebook can also interpolate between its nearest centroids, so a proximity control is needed.

**Earlier evidence.**

- The bundled neighborhood variant NB beats its shuffled control NB-sh (21/4/29).
- NB beats g15 for m = 3 (14/4/0), with gains concentrated on WFG3 and WFG9, and loses for m ≥ 6.
- Phase T excluded the training neighborhood and the neighbors as base points as the source of that gain. Gap filling and interpolation remain.
- For m ≥ 6, one hop of the reference graph reaches 31% to 40% of the nodes, so the neighborhood is not local.

## Hypotheses

- **H1 (gap filling).** Filling empty niches from their occupied neighbors on the graph improves the search, and the gain requires the correct graph.
- **H2 (piecewise-linear read-out).** Interpolating the inverse model at the parent improves the search, and the gain requires the correct graph.
- **H3 (lattice versus proximity).** The read-out of H2 on the lattice is at least as good as the same read-out on the nearest nodes in objective space.
- **H4 (locality).** Gap filling restricted to 1 hop, with a guard against jumps in decision space, avoids the losses for m ≥ 6.

## Design

Every variant changes only the switches `fill`, `interp` and `graphShuf` of `TPIMMOEA_X`; every other component is that of g15. The graph of gap filling and interpolation is the reference graph (each direction linked to its 2(m − 1) angularly nearest directions), kept apart from training, which stays winner-only.

| Variant | Mechanism | Control for |
|---|---|---|
| W1_Fill | With probability 0.5 per candidate, when there are empty niches, the base point of an empty niche is the mean of the representatives of its occupied neighbors within 2 hops, with weights 1/hop | H1 |
| W1s_FillShuf | W1 with the graph permuted once per run | H1 |
| W2_Interp | The base point is the convex combination of the decision prototypes of the parent's node and of its trained 1-hop neighbors. The weights are those whose objective prototypes best reproduce the parent (nonnegative least squares, summing to 1) | H2 |
| W2s_InterpShuf | W2 with the graph permuted once per run | H2 |
| W2p_InterpProx | W2 with as many trained nodes, the nearest in objective space, instead of the graph neighbors (codebook control) | H3 |
| W3_FillLocal | Gap filling within 1 hop, equal weights, without a representative farther than twice the median distance from the others in decision space | H4 |
| W3s_FillLocalShuf | W3 with the graph permuted once per run | H4 |
| W4_InterpFillLocal | W2 and W3 together | Combination |

**Random numbers.**

- g15 already draws the random numbers of the niche branch, but never fills a niche, because its graph is cut. W1 and W3 use those same draws.
- The permutation of the shuffled controls is drawn with a seed derived from the run's seed, and the random stream is then restored.

**The read-out control is a soft control.** With a permuted graph, the convex weights tend to ignore distant partners, so W2s tends toward g15. If W2 beats W2s, the gain requires the correct adjacency.

## Protocol

- **Problems:** WFG1 to WFG9 with m ∈ {3, 6, 9} and d ∈ {10, 100} (54 instances).
- **Settings:** N = 50, hard budget of 300 evaluations, 30 runs, 12,960 runs in all.
- **Score:** IGD of the nondominated solutions among all evaluations.
- **Pairing:** every run keeps the output name of the corresponding g15 run of block C1, hence its seed.
- **Instrumentation:** every run is instrumented (`instr = 1`).

## Measures

- **Primary:** IGD.
- **Secondary:**
  - the topology of the final map (ρ, neighborhood overlap against its random expectation, adjacent/nonadjacent distance ratio);
  - the number of nodes trained;
  - the time relative to V0 of phase V, run on the same PC.

## Decision rule

**Stage 1, WFG.** The candidates are W1, W2, W2p, W3 and W4; the shuffled variants are controls only. Each candidate is compared with g15, as in phase T:

- Wilcoxon rank-sum test per instance (5%), reported as better, worse and similar counts, overall and per m.
- Wilcoxon signed-rank test over the 54 instance means, with Holm's correction over the five candidates.

A candidate qualifies only if both conditions hold:

1. It is significantly better after Holm's correction.
2. Within no group of m is it significantly worse (signed-rank, 5%).

**Attribution to the topology.** A qualifying candidate is reported as a topological mechanism only if it is significantly better than its shuffled control (signed-rank, 5%): W1 against W1s, W2 against W2s, W3 against W3s; W4 requires both W2 against W2s and W3 against W3s. For the read-out:

- It is reported as specific to the lattice only if W2 is also significantly better than W2p.
- If W2 and W2p do not differ, the gain is reported as interpolation over objective-space proximity, which a codebook also offers.

**Choice and confirmation.** If several candidates qualify, the one with the smallest Holm-adjusted p-value is chosen, preferring a topological mechanism and, among equivalent ones, the simpler. The chosen candidate then goes through the confirmation stage of phase T: RWMOP1 to RWMOP35 and WFG with m ∈ {15, 20}, with no significant loss (Holm over the two suites); the held-out DTLZ suite is reported only.

**No candidate qualifies.** g15 remains the final configuration, and phase W is reported as the test of the topological uses of the map.

**If phase V changes the directions of the map,** phase W is repeated with the new directions, which change the resolution of the graph.
