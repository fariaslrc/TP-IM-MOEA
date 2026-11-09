# Phase AC protocol: cooperation, movement, and repair in X1

*English translation of the protocol, which was written in Portuguese. Dates, rules, and thresholds are unchanged.*

Implementation version: 3 (see the next section); version 1 is kept below as a record. Date: 2026-11-04. Status: prospective protocol, written without any result of the AC campaign. This version defines hypotheses and evaluation criteria; it does not demonstrate superiority. Any change made after the results are examined must create a new version and be identified as development.

## Version 3 (2026-11-04): this section prevails over the others

Fixed before any AC run. It replaces versions 1 and 2, which remain below only as a record. Versions 1 and 2 came from a draft and were revised before any run; no AC result had been seen.

### What the revision discarded, and why

1. **Mutual-neighbor graph with k = 4 (`graphMode = 'mutual'`).** It fragments the map: with N = 50, the mean degree drops to 1.7 at m = 9, 1.6 at m = 15, and 1.3 at m = 20, with 15, 10, and 17 disconnected components, and there are nodes without neighbors at m = 9. A gain of the `cooperative` profile at m = 15/20 would come from switching cooperation off rather than improving it, and the shuffled control would keep the same fragmentation. The X1 graph of the article is kept.
2. **Neighbor mass normalized to sum exactly to 1.** The normalization also increased weights: a single neighbor with Gaussian weight 0.61 would be trained with weight 1, the same as the winner. The cap now only reduces (`sum(H) > beta`).
3. **Learned movement.** With the 300-evaluation gate, it would act only on RWMOP, it does not address any identified limitation of X1 (m = 15/20 and DTLZ, both with 300 evaluations), and it would add about 5 h of computation and a new mechanism without prior evidence. The code remains in the repository, without a profile in the campaign.
4. **Confidence weights in the read-out (`supportWeights`).** They distort the NNLS coefficients without independent justification. They are not part of the campaign.
5. **Repair modes other than `infeasible`.** Removed from the code.

### What the revision added: the geometric gate of the ordering phase

With N = 50, `UniformPoint` uses outer-layer resolution H1 = 8, 2, and 2 for m = 3, 6, and 9, and H1 = 1 for m = 15 and 20. With H1 = 1, each layer consists of the vertices of a simplex, and all directions of a layer are adjacent to one another. There is no local neighborhood to preserve, and the ordering phase becomes an almost global average. The rule (`orderGate`) applies the ordering phase only when H1 ≥ 2, and it depends only on N and m.

**Declared origin of the rule:** the loss of X1 at m = 15/20 (phase AB) motivated the investigation. The rule, however, follows from the geometry of the lattice and not from a fit to the results. The `gated` profile (X1 with the gate) coincides with X1 where H1 ≥ 2 and with X2 of phase Y where H1 = 1, on the same seeds. It is therefore not rerun: the smoke test checks exact equality on run 1, and the results of `gated` are those of phases X, AB, and Y.

### Blocks (runs 1 to 30)

| Block | Instances | Profiles | Runs |
|---|---|---|---:|
| AC1 | WFG m = 3, 6, 9 (54) | gated_transport, gated_mass, gated_direct, coop3 | 6,480 |
| AC2 | WFG m = 15, 20 (36) | the same four | 4,320 |
| AC3 | DTLZ1–4, 7, m = 3, 6, 9 (30) | the same four | 3,600 |
| AC4 | RWMOP1–35 (Kumar budgets) | coop3, gated_repair_global, gated_repair_som | 3,150 |

- `gated_transport`: transport of the objective prototypes when the ideal and nadir points change.
- `gated_mass`: total neighbor mass capped at 1 in the ordering phase (it only reduces).
- `gated_direct`: only nodes with their own solution in the current training call enter the cell read-out.
- `coop3`: the three changes together.
- `gated_repair_*`: repair of the constraints with affine models, global or supported by the SOM, only while the archive has no feasible solution.

### Hypotheses and criteria (fixed now)

Reference for every comparison: `gated` (X1 of phases X and AB where H1 ≥ 2; X2 of phase Y where H1 = 1).

- **H0, gate:** descriptive; `gated` against X1 and g15 on every suite, with the existing data.
- **H-A, cooperation (AC1 to AC3):** each of the four profiles against `gated`, with Holm's correction over the four profiles within each suite (WFG m = 3 to 9, WFG m = 15/20, DTLZ). A profile is **adopted** if (1) it improves significantly on at least one suite (signed-rank test paired by instance, Holm p < 0.05, IGD ratio with the upper bound of the 95% CI below 1) and (2) it worsens none (upper bound below 1.03 on each suite and each m). If more than one qualifies, `coop3` is preferred if it qualifies; otherwise, the one with the smallest mean ratio over the three suites.
- **H-C, repair (AC4):** on the problems where `gated` ends without a feasible solution in more than half of the runs, an increase of at least 10 percentage points in the rate of runs with a feasible final set; on the others, HV not worse (absolute margin 0.01). Attribution to the SOM: `gated_repair_som` against `gated_repair_global`. If the global version ties or wins, the gain belongs to the repair and not to the topology.
- **coop3 on RWMOP:** descriptive, to complete the table of the model in case it is adopted.

Tests: signed-rank test paired by instance with Holm's correction, ratio of geometric means with a cluster bootstrap over problems (10,000 resamples, seed 1), as in the previous phases. The RWMOP HV uses the fixed normalization of `rwmop_norm.csv`, computed as in `rescore_rwmop_y.m`, to be comparable with the numbers of the article at that time.

### Addendum of 2026-11-05: block AC5 (fixed before running)

Result of AC1 to AC4 (analysis in `analysis/analyze_ac.py`): by the rule above, `gated_mass` is adopted (DTLZ 0.973, 95% CI [0.958, 0.989], Holm p 0.013; neutral on WFG). The repair made every run of RWMOP30 to 35 feasible, and `gated_repair_som` tied with `gated_repair_global` on all 35 problems, so the repair enters in its global version. Since `gated_mass` had not been run on RWMOP, block AC5 completes the model:

| Block | Instances | Profiles | Runs |
|---|---|---|---:|
| AC5 | RWMOP1–35 | gated_mass, gated_mass_repair_global | 2,100 |

Criteria:
- **`gated_mass` on RWMOP against `gated`:** non-inferior if no problem loses more than 0.01 of mean HV and the signed-rank test is not significantly unfavorable (5%).
- **`gated_mass_repair_global` against `gated_repair_global`:** the same HV rule, and the rate of runs with a feasible final set on RWMOP30 to 35 must not decrease.
- **Final model:** if both criteria pass, the model is X1 with the ordering gate, the capped mass, and the global repair. If `gated_mass` fails on RWMOP, the capped mass is not included, and the model is X1 with the ordering gate and the global repair.

*Outcome, recorded after AC5 (analysis in `analysis/analyze_ac5.py`): `gated_mass` failed the RWMOP criterion, so the final model is X1 with the ordering gate and the global repair (profile `gated_repair_global`), as reported in Table S20 of the supplementary material.*

---

*The sections below are version 1 of the protocol, kept as a record. Where they differ from version 3, version 3 prevails.*

## Objective and permitted claims

To test whether the structure of the SOM produces a measurable benefit in learning and in reproduction, keeping the SOM at the center of the method, a design requirement of the project. The architecture may change. The competitive objective is to improve the results on the WFG strata with m = 3, 6, 9, 15, and 20, on DTLZ, and on RWMOP, without replacing evidence with a promise of universal leadership.

The ranking will always be conditioned on the set of problems, dimensionalities, budget, comparators, and metric. Winning a global average does not demonstrate leadership in every niche. The DTLZ data already examined in earlier development do not constitute an unseen validation family. New seeds reduce the reuse of the same realizations but do not eliminate adaptation to the benchmark.

## Implementations and hypotheses

All profiles use `TPIMMOEA_X`, with the parameters declared by `x1_parameters(profile,outN)`. Argument 45 enables the extensions. The historical arguments remain explicitly recorded. Argument 29 (`instr`) must be zero: diagnostics that call the true functions outside `Problem.Evaluation` would invalidate the budget.

| Profile | Change and experimental role |
|---|---|
| `g15` | Historical TP-IM-MOEA, without the X1 extensions; reference control. |
| `legacy` | Earlier X1, with neighborhood and neighborhood learning; argument 45 empty. |
| `transport` | Only the transport of the prototypes when the normalization of the objectives changes. |
| `direct` | Only the requirement of direct observations for read-out eligibility. |
| `mass` | Only the total off-diagonal mass fixed at 1; BMU weight equal to 1. |
| `sparse` | Only the mutual-neighbor graph, k = 4. |
| `cooperative` | Combines transport, direct support, controlled mass, sparse graph, and confidence in the read-out. |
| `cooperative_no_order` | Keeps eligibility by direct support; removes only the neighborhood ordering in training. |
| `cooperative_shuffled` | Permutes the adjacency before the current confidence weights; preserves the degree sequence, not all final weights. |
| `cooperative_proximity` | Read-out by proximity in the codebook with comparable cardinality; control for the need of the graph. |
| `move_node` | Learned movement using only the node. |
| `move_global` | Global learned movement, without the locality of the SOM. |
| `move_som` | Learned movement with support from the SOM. |
| `move_proximity` | Movement with grouping by proximity in decision space. |
| `move_shrink` | Control for the effect of shortening the step, without attributing a gain to the learned direction. |
| `repair_global` | Repair with global models of the individual constraints. |
| `repair_proximity` | Repair with support by proximity in decision space. |
| `repair_som` | Repair with support provided by the SOM. |
| `combined` | Cooperation, SOM movement, and SOM repair, to study the compatibility of the mechanisms. |

The five movement controls and the three repair controls start from `cooperative`. The combined control is not selected automatically. The wrappers `TPIMMOEA_X1C`, `TPIMMOEA_X1M`, `TPIMMOEA_X1F`, and `TPIMMOEA_X1CMF` allow direct use of the mechanisms, but the AC runner uses the same class name and records the profile to avoid accidental configuration differences.

H-A: transporting coordinates, distinguishing direct support, controlling mass, and restricting the graph improve cooperation without spreading information indiscriminately. The superiority of `cooperative` over `legacy` is not enough to attribute the gain to the topology: the permutation, proximity, and ordering controls are required. The four isolated variants diagnose the mechanism; they are not a full factorial design and do not identify all interactions.

H-B: local historical pairs of feasible solutions provide a useful direction of movement. The mechanism uses a chronological buffer of up to 300 evaluations, feasible pairs, mutual neighborhood, and a normalized RMS distance of at most 0.25. The effective support size is a measure of the concentration of the weights, not of statistically independent observations. This direction is not to be called a causal gradient. The controls distinguish directional information, locality of the SOM, and a simple reduction of the step.

H-C: local models of the individual constraints increase the probability of obtaining and keeping feasibility. The repair is an approximate data-driven projection, not a guarantee of true feasibility. The repaired candidate still requires a true evaluation within the budget. Insufficient support triggers the fallback behavior documented in the implementation.

Activation gates (fixed before the results): the movement acts only with `Problem.FE >= 300`, so it does not act on the 300-evaluation suites and can only be assessed on RWMOP; the repair, by default, acts only while the archive has no feasible member (feasibility restoration), with a periodic mode available as a declared variant. H-B is tested only on RWMOP, and the absence of interference on the expensive suites must be checked by exact equality with `cooperative`.

In the current integration, candidates with even indices receive a movement attempt; the repair acts on the set of candidates before prescreening. Duplicates of the archive or of other candidates revert to the original candidate. Confidence adaptation uses only movements actually chosen and evaluated; candidates that were also repaired are excluded from the radius feedback of the movement. The chronological gate of the repair is an internal diagnostic: the support is selected with access to the available X/F data, which makes the assessment transductive rather than an independent external validation. The trust box is centered on the candidate, not on the region covered by the support; the fit may extrapolate. These limitations must appear in the interpretation of the results.

## Problem matrix and budget

| Suite | Instances | Configuration |
|---|---:|---|
| Main WFG | 54 | WFG1–9 × m = {3,6,9} × d = {10,100}; N = 50; 300 evaluations. |
| Many-objective WFG | 36 | WFG1–9 × m = {15,20} × d = {m−1+10,100}; N = 50; 300 evaluations. |
| DTLZ | 30 | DTLZ1,2,3,4,7 × m = {3,6,9} × d = {10,100}; N = 50; 300 evaluations. |
| DTLZ extension (`AC_E`) | 28 | DTLZ1–7 × m = {15,20} × d = {m−1+10,100}; N = 50; 300 evaluations. |
| RWMOP | 35 | RWMOP1–35; dimensions, N, and budget of the Kumar protocol already encoded in `q_build_tasks('Q3')`. |

RWMOP keeps the number of objectives of each problem: it is not artificially converted to m = 3, 6, 9, 15, 20. Its N values are 80, 105, or 212; the budgets are 20,000, 26,250, 53,000, or 80,000 evaluations depending on the problem. The `AC_E` extension includes DTLZ with m = 15 and 20 without changing the historical matrix; DTLZ5/6 add degenerate structures. Parameters and finalists are to be frozen before the extension is opened, the reference fronts checked, and the result of this extension kept separate from the historical reproduction. Not all combinations DTLZ1–7 × m are present in the historical matrix: DTLZ5/6 with m = 3, 6, 9 remain outside this version.

Every true evaluation must go through the counter of the `PROBLEM` instance. A valid result requires `Problem.FE == maxFE`, `size(recObjs,1) == maxFE`, and `size(recCons,1) == maxFE`. An early stop or an exception is a failure, never a complete run scored with fewer evaluations. The initial design counts against the budget. The same budget also applies to the controls, including any evaluation made by auxiliary methods.

## Blocks and temporal separation

| Block | Instances | Default profiles | Default runs | Default total |
|---|---:|---:|---|---:|
| `AC_A` | 90 WFG | 10: g15, legacy, four isolated changes, and four cooperative profiles | 1:10 | 9,000 |
| `AC_B` | 35 RWMOP | 6: g15, legacy, cooperative, and three repairs | 1:10 | 2,100 |
| `AC_C` | 120 WFG + DTLZ | 8: g15, legacy, cooperative, and five movements | 1:10 | 9,600 |
| `AC_D` | 155, all suites | 3: g15, legacy, cooperative | 31:60 | 13,950 |
| `AC_E` | 28 DTLZ of the extension | 3: g15, legacy, cooperative | 31:60 | 2,520 |

1. Structural check on the development computer: static analysis, numerical tests of helpers, and construction of manifests only. No optimization.
2. Pilot on the execution machine: runs 1:10 of the required blocks. Check cost, absence of failures, budget, historical parity, and the usefulness of the signals. Run IDs already used historically do not constitute data independent of those earlier results.
3. Development on the execution machine: runs 11:30, passed explicitly to the runner. Adjustments are allowed here, but all candidates and decisions must be recorded. This set is not to be presented as an independent confirmation after parameters have been selected on it.
4. Freeze the implementation, parameters, finalist candidates, comparators, criteria, and analysis before opening `AC_D`. The source hash and the manifest document this freeze. The runner does not choose winners.
5. Confirmation on the execution machine: runs 31:60. By default, cooperative is compared with g15 and legacy; `move_som`, `repair_som`, and/or `combined` are included only through an explicit list frozen in advance. `AC_E` assesses the DTLZ m = 15/20 extension separately with frozen candidates. Running all candidates retrospectively and reporting only the best invalidates the confirmatory interpretation.

It is not necessary to launch all blocks at once. The number of profiles and runs may be explicitly reduced in the pilot to estimate cost. The budget is not to be reduced with the reduced pilot then treated as a repetition of the final protocol.

## Seeds and comparability

The base file keeps the historical g15 identity, for example `TPIMMOEA_X_g15_WFG1_M3_D10_1.mat`, and the profile is separated by the folder. The seed is exactly `mod(sum(double(name).*(1:numel(name))) + 7919*run, 2^31-1)`. The final identifier changes from `_1` to the requested run, including 31:60.

Thus, all X1 variants of the same problem and run start from the same seed. This does not mean that the whole trajectory shares random numbers: different mechanisms consume the generator in different ways. The pairing hypothesis refers to the randomized design per run, not to the identity of the populations of all generations. The historical parity of g15/legacy and of the `identity` extension is to be verified by a smoke test on the execution machine before the campaign; equality of parameters and hashes alone does not demonstrate numerical parity.

## Metrics and scored set

WFG/DTLZ: primary `IGDall`, computed on the feasible nondominated solutions of **all** recorded evaluations, against the same front `Problem.optimum`. `IGDplusAll` is secondary, to reduce ambiguities related to dominance. The file also keeps `IGDreported`. The reported population has 2N solutions in this protocol. Curves must compare common evaluation counts, never generations of different sizes.

RWMOP: primary quality measure `HVfixed`, on the final population of **N** solutions, using only feasible nondominated members and the frozen ideal and nadir points of `results/rwmop_norm.csv`. Normalize by `(f−ideal)/(nadir−ideal)` and use a fixed reference point of 1.1 on each axis; report the volume divided by `1.1^m`. The exporter compensates for the internal renormalization of `HV.m` when a solution lies below the frozen ideal point. This coincides with the historical procedure when the ideal point is not extrapolated; divergences in that condition must be stated, not hidden. For m ≥ 4, the HV of the installation uses Monte Carlo estimation with a fixed auxiliary seed 1, without changing the RNG state of the optimization. The approximate nature of the measure is to be reported.

If the fixed reference does not exist, `HVfixed = NaN` and `HVdefined = false`, including on RWMOP28. The absence of a reference is not equivalent to HV zero. With a valid reference, the absence of a feasible solution in the final population corresponds to HV zero. `HVreported` is a descriptive measure of the standard PlatEMO normalization and does not replace `HVfixed`.

Also report: the proportion of runs that obtain some feasible solution (`everFeasible`); the proportion with a feasible final set (`finalFeasible`); the final number of feasible solutions; the first feasible evaluation; the smallest final aggregate violation; the smallest evaluated violation. A missing first feasible evaluation is censored at the budget, not converted to zero. The sum of violations has problem-dependent units and must only be compared within a problem; no raw mean of the violation across problems is to be produced.

Separate the feasibility gain from the quality gain conditional on feasibility. A mean HV over successful runs only hides failures; the primary measure therefore includes the zeros of infeasibility when the HV is defined. Conditional analyses are secondary and explicitly labeled. Rows of missing or invalid runs are exported, not silently removed; no confirmatory table is considered complete before the audit.

## External comparators and scope of the delivery

The AC runner implements the TPIMMOEA_X variants and the g15/legacy controls. The external algorithms in the repository remain available through the C/D/P builders, but **they are not automatically rerun on runs 31:60 by AC**. Before claiming leadership against the literature, the list of applicable comparators is to be frozen and their 30 new runs generated with the same budget, declared initialization, reference front, archive/population protocol, and failure policy. A comparison with the old runs 1:30 is descriptive evidence, not the new independent confirmatory test.

Include the strong competitors already used in the manuscript per suite; exclude a comparator only for an applicability reason defined before the results. Document K-RVEA in particular: with a linear trend, the initial design must support d + 1 terms. Its d = 10 stratum must be shown separately; nonexistent results at d = 100 are not to be filled with zeros or artificially worse values. N = 50 and a budget of 300 do not justify ignoring an initialization requirement. An adaptation of K-RVEA to another stratum is a different protocol and must be identified.

## Decision criteria to be frozen before the confirmatory run

The thresholds below are design choices proposed in this version, not theoretical properties of the method. Any adjustment must precede the opening of the confirmation data.

* Mandatory integrity: zero invalid results; exact budget; no true call outside the counter; expected dimensions and population size; configuration and source identity verified. Failures are reported and investigated before competitive conclusions.
* Cooperation: on WFG, require a benefit against legacy and evidence against at least the shuffled and proximity controls. An improvement of at least 2% in the geometric mean of the IGDall ratio candidate/control, with the upper bound of the 95% CI below 1 and a significant adjusted test, is the proposed threshold of practical superiority. Distinguish the m strata; an improvement at m = 3 must not hide a loss at m = 20.
* Movement: require a benefit against cooperative and against move_shrink. Compare move_som with move_global, move_node, and move_proximity to justify the need for SOM support. If the reduction of the step alone explains the gain, that is the conclusion.
* Repair: on problems with feasibility failures in the control, a proposed target of an absolute increase of at least 10 percentage points in final success, with the CI of the difference above zero, or a shorter time to feasibility with censoring correctly handled. On problems already consistently feasible, require preservation of the HV and investigate quality; do not claim a feasibility gain against a ceiling of 100%. With 30 runs, the CI may prevent claiming this target: report the uncertainty, without relaxing the criterion after observing the data.
* Protection against regression: upper bound of the CI of the IGDall ratio candidate/control below 1.03 in each declared stratum. For HV, specify before the test an absolute margin of 0.01 on the normalized volume scale, in addition to no deterioration of the feasibility rate. Zero HV prevents the use of log-ratios of HV; no constants chosen after the results are to be added.
* Combination: compare combined with cooperative, move_som, and repair_som. A combined gain does not demonstrate additivity. Use the separate profiles to detect antagonism or redundancy.

These criteria are strict and may remain inconclusive with 30 runs. The correct scientific decision in that case is to extend the evidence through a new protocol or to report inconclusiveness, not to declare the model "number 1" on the basis of the best seed.

## Statistical analysis and multiplicity

Unit of replication: a run within an instance. Unit of generalization across problems: the benchmark function, keeping its m/d configurations grouped. 30 runs × 90 instances are not to be treated as thousands of independent functions. Report medians, interquartile ranges, differences or ratios of interest, and CIs, in addition to p-values.

For AC variants with paired seeds, the confirmatory test will be the paired sign-flip permutation test, two-sided, with 20,000 permutations and analysis seed 20261104. Statistic: mean of the per-instance differences, with p = (1 + number of permuted statistics at least as extreme)/20,001, ties included. Also report the fraction of positive, negative, and null differences. For comparators with historically different seeds, no retrospective pairing is imposed: use the two-sided rank-sum test and the A12 effect size with ties. Tests are not to be switched according to which one yields significance.

Freeze the families of hypotheses before opening AC_D: H-A (cooperation and its controls), H-B (movement and its controls), H-C (feasibility/HV of the repairs), and H-D (final candidate versus external comparators per suite/stratum). Apply Holm's correction to all declared confirmatory contrasts within each family; include all finalist candidates and examined strata in the adjustment set. Separate families must correspond to separate claims, not artificially split one leadership claim to reduce the correction.

Friedman ranks and post-hoc comparisons may summarize the algorithms with complete data on the same instances, but they do not replace effects and CIs. For means of IGD ratios, work on the log scale. If any member of a comparison has an IGD of exactly zero in a stratum, the log-ratio of that stratum is not computed: report the zeros and the paired differences, without claiming that the relative 2%/3% criterion was demonstrated. No epsilon is added. The bootstrap must respect blocks of runs and families of problems. WFG has only nine functions and the historical DTLZ set five: CIs that aim to generalize to new functions will be substantially limited, even with many seeds. For the first feasible evaluation, use survival analysis with right censoring at maxFE and show success rates together with the curve.

## Computational cost and diagnostics

Record `tSolve` separately from the total time. Parallel runs serve the collection of quality data; rigorous time comparisons must use the same machine, MATLAB version, number of threads, execution mode, and load, preferably one task at a time. Local models may cost more CPU even when they save evaluations. Report both.

The mechanism statistics (effective support, radius distribution, fallback frequency, proposed and accepted repairs, chosen movements) must be derived from data already available. No diagnostic may evaluate the problem to check a candidate rejected by prescreening. The learning buffer of 300 records keeps the cost bounded on the long RWMOP runs but introduces forgetting: assess this trade-off as a prospective sensitivity, without using the identity of the problem to choose the buffer.

## Execution and audit

Install the overlay of this repository over a complete and compatible PlatEMO distribution. Load the complete distribution first and then the overlay, so that the modified `PROBLEM.m` and `TPIMMOEA_X.m` take precedence. Confirm with `which ... -all`; the runner records the resolved paths and rejects a copy of TPIMMOEA_X different from the one that accompanies it.

```matlab
% Safe on any computer: no evaluation and no parallel pool.
addpath(genpath(fullfile(pwd,'PlatEMO'))); % run from the TP-IM-MOEA root
report = run_check_x1_installation(false);
plan = run_ac('AC_A');                   % dryRun = true by default
plan = run_ac('AC_D',true,{'g15','legacy','cooperative'},31:60,1);
extension = run_ac('AC_E');              % DTLZ m = 15/20; plan only
```

Real execution requires the environment variable `TPIMMOEA_EXECUTION_HOST` to name the computer (its `COMPUTERNAME`), a guard against starting a long campaign by mistake.

```matlab
setenv('TPIMMOEA_EXECUTION_HOST',getenv('COMPUTERNAME'));
run_check_x1_installation(true);
test_x1_integration;                     % smoke and parity checks
run_ac('AC_A',false,[],1:10,4);          % this block only
% Development, when explicitly decided:
% run_ac('AC_A',false,{'g15','legacy','cooperative'},11:30,4);
% Confirmation, only after the finalists are frozen:
% run_ac('AC_D',false,{'g15','legacy','cooperative'},31:60,4);
audit = verify_ac_results('AC_A',[],1:10);
addpath(fullfile(pwd,'analysis'));        % repository root
T = export_ac('AC_A',[],1:10);
```

Results are stored in `PlatEMO/Data_AC/<block>/<profile>/`. Before execution, the JSON manifest records each task, parameters, seed, budget, protocol, SHA-256 of the identity, and hashes of the files **resolved on the path**. It includes the problem classes, the algorithm, the X1 helpers, the builders, the PlatEMO core, and relevant utilities. It also records the MATLAB version and toolboxes. Workers check their sources against the manifest.

Resumption accepts only a `COMPLETE` file with identical identity and sources, exact budget, and valid sizes. The digest includes the MATLAB version, platform, and toolbox versions, in addition to the files. An incompatible file is rejected; it is neither overwritten nor used as a completed run. For a new version, create a versioned copy of the overlay or campaign folder and keep the previous one. The first failure is logged and stops the campaign, cancelling pending futures; it does not produce a complete result. Writing uses a temporary file in the same folder and a final move. Records are kept in double precision, and the X1 diagnostics and the source manifest accompany each result. Two controllers must not be started for the same set of tasks.

The exporter keeps `MISSING`/`INVALID` rows and the hashes of the sources and of the normalization. `verify_ac_results` checks the evaluation records and recomputes the feasibility indicators. The delivery of this implementation does not include launching campaigns and does not claim that the criteria have been met.
