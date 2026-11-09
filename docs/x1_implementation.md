# X1 experimental implementation (phase AC)

Status: revised draft (version 3), implemented for evaluation. The protocol and decision rules are in [phase_AC_protocol.md](phase_AC_protocol.md). The final configuration of the article uses this extension through the profile `gated_repair_global` and is run by the class `TPIMMOEA`; the other profiles below are research controls.

## Available algorithms

| PlatEMO class | Profile | Additional mechanism |
|---|---|---|
| `TPIMMOEA_X1C` | `cooperative` | Transport of the normalization, sparse graph, capped cooperative mass, and read-out with direct support |
| `TPIMMOEA_X1M` | `move_som` | X1C with a local field of movements, shared through the SOM in training and in the read-out |
| `TPIMMOEA_X1F` | `repair_som` | X1C with individual affine models of the constraints and a projection with slacks |
| `TPIMMOEA_X1CMF` | `combined` | Experimental combination; to be selected only after the ablations |

The files are in `PlatEMO/Algorithms/Multi-objective optimization/TPIMMOEA_X1/`. Each class takes `outN` as its only parameter: 0 reports the search archive of up to 2N solutions; 1 reports N solutions chosen by the existing environmental selection. In the RWMOP experiments, the runner sets `outN = 1`.

The single integration point is `TPIMMOEA_X.m`. Its parameter 45, `x1Options`, is optional. Left empty, it keeps the historical path; the 44 earlier parameters keep their positions. `x1_parameters` builds the profiles and sets `instr = 0`: the new routines make no call to `CalObj`/`CalCon` outside the budget.

## Cooperation and support

`x1_graph` builds a mutual graph of the four angularly nearest neighbors. Disconnected components remain disconnected. The permutation control uses a private random stream and preserves the random sequence of the optimizer. The historical graph is returned without reconstruction in the `identity` control.

If `c_j` is the number of direct BMUs of region j in the training call, the confidence is `q_j = c_j/(c_j+2)`. Updates received from neighbors do not count as direct evidence. During the ordering phase, the winner keeps weight 1. The Gaussian weights of the other nodes are multiplied by `sqrt(q_b*q_j)` and normalized to sum to 1 when there is support; without support, their sum is zero. This budget refers to each presentation of a sample, not to the whole training.

The read-out uses one-hop neighbors with direct support. The convex coefficients obtained by the existing NNLS are adjusted by the same reliability between regions and renormalized. After this adjustment, they are therefore not the exact minimizer of the original NNLS. The proximity control replaces the graph neighbors by the prototypes nearest in objective space, keeping the eligible number of neighbors.

The objective prototypes are transported between normalizations by `W_new = (W_old*s_old + ideal_old - ideal_new)/s_new`. The decision part remains normalized by the bounds of the problem. The historical `LDis` of the generation is preserved, so the new neighborhood does not accidentally activate the earlier niche filling.

## Movement learning

A separate chronological buffer keeps the last 300 solutions actually evaluated. It neither replaces nor enlarges the selection archive. In each generation, `x1_movement_fit` extracts feasible pairs in the same reference region, with mutual neighborhood in decision space and a normalized RMS distance of at most 0.25. Each pair is oriented by the improvement in PBI, with the same normalization and reference direction for both ends.

The `node`, `global`, `som`, and `proximity` controls use the same pair extraction. The SOM mode shares the vectors through the graph in the fit and again in the read-out. The confidence derives from the coefficients of the original pairs; its algebraic effective support is not a count of independent observations. The proximity rule reduces jumps between distant regions but does not prove that distinct branches were separated.

At the eligible even indices of the pool, the proposed candidate is `base + learned_vector + 0.25*(DE - base)`, bounded by an RMS radius and by the decision bounds. The radius starts at 0.1, stays in [0.005, 0.25], and receives feedback only from candidates actually changed and evaluated. Candidates later repaired are excluded from this feedback. The `move_shrink` control applies the same reduction of the DE step and the radius limit, without a learned vector. Without support, the original DE candidate is kept exactly.

## Activation gates

The mechanisms have gates fixed before any AC result (`x1_options`). A mechanism that is off is neither fitted nor applied and draws no random numbers; the run follows exactly the profile without it. The state of each generation is stored in `Algorithm.metric.x1GateLog` (evaluations, movement on, repair on).

* **Movement:** acts only when `Problem.FE >= moveMinFE` (default 300). With the budget of 300 evaluations (the expensive regime: WFG and DTLZ), it never acts, and `move_*` coincides with `cooperative`. On RWMOP, it starts after the first 300 evaluations, when the 300-record buffer is already full.
* **Repair:** a single mode, `repairTrigger = 'infeasible'`: it acts only while the feasible fraction of the archive is at most `repairFeasTarget` (default 0), that is, as a feasibility-restoration phase. It never acts on a problem without observed violation.
* **Ordering (`orderGate`):** the ordering phase is applied only when the outer layer of `UniformPoint(N,m)` has resolution H1 ≥ 2. With H1 = 1 (for N = 50, from m = 10 on; m = 15 and 20 among the cases studied), all directions of a layer are adjacent to one another, and there is no local neighborhood.

Revision of 2026-11-04 (version 3 of the protocol): the mutual graph (`graphMode = 'mutual'`), the confidence weights (`supportWeights`), and the movement are not part of the campaign; the cooperative mass cap now only reduces. See [phase_AC_protocol.md](phase_AC_protocol.md).

## Constraint repair

`x1_repair_fit` fits an affine function to each observed constraint. It uses an internal chronological split to check the error, rank, and conditioning before refitting with all the data of the pool. The `global`, `proximity`, and `som` modes separate the effect of a global model from the contribution of the topology. The SOM mode does not cross disconnected components to complete a pool.

`x1_repair_apply` solves a quadratic projection with L1 slacks, error margins, decision bounds, and a trust box around the candidate. It knows neither the identity nor the formulas of the problem. A rejected model or a numerical failure keeps the candidate unchanged. Constraints observed to be identically zero receive no artificial margin. After the projection, duplicates of the archive or of any other candidate revert to the previous proposal.

The gate is an internal, partly transductive validation: the pools and associations may use X/F data already observed. The box bounds the displacement from the candidate, not the distance to the training support. The repair may therefore extrapolate, and feasibility is only confirmed after the true evaluation. With large d, a small budget, or nonaffine constraints, rejection of the model is expected behavior.

## Controls and diagnostics

In addition to the four algorithms, `x1_parameters` offers: `g15`, `legacy` (historical X1), `identity`, `transport`, `direct`, `mass`, `sparse`, `cooperative_no_order`, `cooperative_shuffled`, `cooperative_proximity`, `move_node`, `move_global`, `move_som`, `move_proximity`, `move_shrink`, `repair_global`, `repair_proximity`, and `repair_som`, as well as the gated profiles of version 3 (`gated`, `gated_transport`, `gated_mass`, `gated_direct`, `coop3`, `gated_repair_global`, `gated_repair_som`, `gated_mass_repair_global`) and the phase AD profiles (`final_A`, `final_B`, `final_AB`, `final_Brand`).

`Algorithm.metric.x1GraphLog` records the evaluations, number of nodes, mean degree, nodes with direct support, nodes reached in training, and mean confidence. `x1Diagnostics` records generated and evaluated candidates, movements and repairs actually used, displacements, mean radius, active repair models, and reasons for fallback. Computational cost and activation frequency should accompany the quality metrics.

## Validation and execution

`run_x1_unit_tests` runs array-level tests only: cooperative mass, disconnection, transport, buffer, profiles, learning, controls, radius, feasibility, regression, rank, holdout, QP, and RNG preservation. It does not instantiate a benchmark problem. `run_check_x1_installation` checks lattices, seeds, hashes, and budget without evaluations.

`test_x1_integration`, protected by the host guard (`ac_check_host`), checks class contracts, budget, and parity between `legacy` and `identity` on a synthetic fixture. It passed on the execution machine before the campaigns (see [x1_validation.md](x1_validation.md)). The local component tests do not demonstrate parity of complete trajectories, performance gains, or scientific superiority.

Load a complete PlatEMO installation first and then this overlay, so that `which TPIMMOEA_X -all` and `which PROBLEM -all` show the correct versions. The complete distribution and the Statistics and Optimization toolboxes are required. The commands and the host guard are described in [phase_AC_protocol.md](phase_AC_protocol.md).
