# TP-IM-MOEA

**Topology-preserving inverse-modeling multi-objective evolutionary algorithm**

This repository contains the implementation of TP-IM-MOEA and everything needed to reproduce the experiments of the article:

> L. R. C. de Farias and A. F. R. Araújo, "Topology-Preserving Inverse Modeling in Multi-Objective Evolutionary Optimization," under review.

TP-IM-MOEA organizes the inverse model, which maps the objective space to the decision space, as a self-organizing map (SOM) whose prototypes are ordered over the objective space. Each node is anchored to a reference direction and summarizes the nondominated solutions of its region of the Pareto front, so that adjacent regions are reconstructed from adjacent prototypes. Candidates are reconstructed from the prototypes of sparsely covered regions, refined by budget-adaptive differential evolution, and screened by an instance-based predictor before any evaluation is spent. No surrogate model of the objectives is fitted, and a run with 300 evaluations takes about half a second.

## Contents

| Folder | Content |
|---|---|
| `PlatEMO/` | Files to copy over PlatEMO 4.16: the algorithm, the changes to the platform used in the experiments, and the experiment scripts |
| `analysis/` | Scripts that turn the runs into the tables, statistical tests, and figure of the article |
| `results/` | Per-run results of every experiment of the article (CSV) |
| `docs/` | Pre-registration of the experiments in progress |

## Requirements

- [PlatEMO 4.16](https://github.com/BIMK/PlatEMO/releases/tag/v4.16)
- MATLAB (the experiments used R2026b) with the Statistics and Machine Learning Toolbox. The experiment scripts also use the Parallel Computing Toolbox, and CSEA, REMO, PIEA, ADSAPSO, and SFA-DE require the Deep Learning Toolbox.
- Python 3.10 or later with NumPy, pandas, and SciPy, plus Matplotlib for the figure.

## Installation

1. Download PlatEMO 4.16 and extract it.
2. Copy the contents of `PlatEMO/` from this repository into the `PlatEMO/` folder of the installation, merging folders and replacing files.
3. In MATLAB, from the PlatEMO folder, run the installation check (about one minute):

```matlab
run_check_tpimmoea
```

It runs TP-IM-MOEA on WFG4 and DTLZ2 with the seeds of the article and checks that the IGD matches the published runs within 10<sup>-12</sup>.

## Usage

TP-IM-MOEA is called like any PlatEMO algorithm:

```matlab
platemo('algorithm',@TPIMMOEA,'problem',@WFG4,'M',3,'D',10,'N',50,'maxFE',300);
```

Its parameters follow Table I of the article, in this order:

| Parameter | Default | Meaning |
|---|---|---|
| `eta0` | 0.2 | Initial learning rate of the SOM |
| `B0` | 10 | Base batch size of real evaluations |
| `F0` | 0.5 | Base scaling factor of DE |
| `CR0` | 0.9 | Base crossover rate of DE |
| `K` | 5 | Screening factor: K·B candidates are generated per generation |
| `k` | 3 | Number of neighbors of the kNN predictor |
| `theta` | 5 | Penalty of the PBI function |
| `Theta` | 1000 | Evaluation budget above which the batch size is adapted |
| `outN` | 0 | 1 returns N solutions chosen by the environmental selection instead of the archive of 2N |

For example, the real-world problems of the article are solved with `outN = 1`:

```matlab
platemo('algorithm',{@TPIMMOEA,[],[],[],[],[],[],[],[],1},'problem',@RWMOP1);
```

`TPIMMOEA_X` is the research implementation used in all experiments. `TPIMMOEA` runs it with the final configuration of the article, and both give identical runs from the same random stream. The other switches of `TPIMMOEA_X` are documented in its header and serve the ablation study and the control experiments.

## Changes to PlatEMO 4.16

Every other file of the platform, including all compared algorithms, is used as distributed in PlatEMO 4.16.

| File | Change | Reason |
|---|---|---|
| `Problems/PROBLEM.m` | Optional hard budget (`capFE`) and record of every evaluation (`recObjs`, `recCons`); inactive by default | Every algorithm runs under the same hard budget and is scored on all of its evaluations |
| `Problems/.../RWMOPs/RWMOP1.m` to `RWMOP35.m` | Two lines in `Evaluation` | These problems override `Evaluation`, so the budget and the record are applied explicitly |
| `Algorithms/.../CSEA/CSEA.m` | Network training on the CPU | GPU training failed when several parallel workers shared one GPU |
| `Algorithms/.../IM-MOEA-D/Operator.m` | With fewer than three variables, all of them are modeled, as in IM-C-MOEA/D | The operator draws three variables, which fails on the RWMOP problems with two |
| `Algorithms/.../K-RVEA/KRVEANI.m` | New file: K-RVEA with the size of the initial design as a parameter | Control experiment with an initial design of N = 50 samples |

## Reproducing the experiments

The experiments are organized in phases. Each phase has a task list (`<phase>_build_tasks.m`), a resumable parallel executor (`run_<phase>.m`), and an audit of the results (`verify_<phase>_results.m`). The seed of each run is derived from its output file name and run number, so every run can be repeated exactly. A phase writes its runs to `Data_<phase>/` inside the PlatEMO folder.

```matlab
run_c('C1')                 % one block
run_c([],true)              % dry run: list the tasks without running them
verify_c_results            % audit of the completed runs
```

| Article | Blocks |
|---|---|
| WFG comparison (Sections V-A and V-B) | C1; K-RVEA in P3; MCEA/D and AVG-SAEA in P7; CSEA in P8; PIEA, ADSAPSO, SFA-DE, and REMO in B1 to B4; EGES in D5; K-RVEA with a smaller initial design in F2; optimization time in D1 |
| Held-out DTLZ suite (Section V-C) | D2, D4 (REMO), and G3 |
| Real-world problems (Section V-D) | C5, C8, and E1 |
| Ablation study (Section V-E) | C3, with the variant without the SOM in reproduction in K1; anchor permutation and map topology in F1 and G2; prescreening controls in G1 |
| Sensitivity analysis (Section V-F) | C4 and C5 (parameters), I1 (population size), H1 to H3 (budget) |
| Many objectives (Section V-G) | C2, C7 (PIEA), and D3 (EGES) |

The task lists of phases P3 and Q also define configurations of the preliminary design study, which are not reported in the article; phase C reuses their output names, and hence their seeds.

Phase T (`t_build_tasks.m`, `run_t.m`, and `verify_t_results.m`) tests the use of the map neighborhood in training and in reproduction. Its hypotheses, design, and decision rule are fixed in [`docs/phase_T_preregistration.md`](docs/phase_T_preregistration.md) before any of its runs. Phase U (`u_build_tasks.m`, `run_u.m`, and `verify_u_results.m`) tests why the decision prototype of the parent's region is a better base point than the parent itself, as fixed in [`docs/phase_U_preregistration.md`](docs/phase_U_preregistration.md). Phase V (`v_build_tasks.m`, `run_v.m`, and `verify_v_results.m`) replaces the Das-Dennis directions of the map by the weight vectors of MOEA/D-UR, which give exactly N directions for any number of objectives, as fixed in [`docs/phase_V_preregistration.md`](docs/phase_V_preregistration.md). Phase W (`w_build_tasks.m`, `run_w.m`, and `verify_w_results.m`) tests two uses of the topology of the map in reproduction, gap filling from neighboring regions and a piecewise-linear read-out of the inverse model, each against a control without the topology, as fixed in [`docs/phase_W_preregistration.md`](docs/phase_W_preregistration.md). Phase X (`x_build_tasks.m`, `run_x.m`, and `verify_x_results.m`) tests TPN, which adds to the final configuration an ordering phase in training and a read-out on the cell of the parent in reproduction, against three controls, as fixed in [`docs/phase_X_preregistration.md`](docs/phase_X_preregistration.md). Phase Y (`y_build_tasks.m`, `run_y.m`, and `verify_y_results.m`) confirms X2, the cell read-out with winner-only training, on RWMOP, on WFG with 15 and 20 objectives, and on DTLZ, as fixed in [`docs/phase_Y_preregistration.md`](docs/phase_Y_preregistration.md). Phase AA (`aa_build_tasks.m`, `run_aa.m`, and `verify_aa_results.m`) tests one evaluation per generation under small budgets and an archive of capacity 300, as fixed in [`docs/phase_AA_preregistration.md`](docs/phase_AA_preregistration.md).

## Regenerating the tables

The CSV files in `results/` hold every value reported in the article. The tables and statistical tests are regenerated from them, without running any algorithm:

```bash
python analysis/make_tables_c.py      # main and supplementary tables
python analysis/posthoc_c.py          # Friedman, Holm, and Vargha-Delaney tests (Table S16)
python analysis/make_table_f.py       # anchor permutation and map topology (Table V)
python analysis/analyze_f.py          # anchor permutation, map topology, and prescreening accuracy on WFG
python analysis/analyze_g.py          # prescreening controls, and map topology on DTLZ
python analysis/make_table_rwnorm.py  # normalization of the hypervolume on RWMOP (Table S17)
python analysis/analyze_h.py          # budget and population size (Table S18)
python analysis/plot_conv_c.py        # convergence curves (Fig. S1)
```

The tables are written to `analysis/tables/`. To rebuild the CSV files from new runs, use the MATLAB scripts of `analysis/` (`export_c`, `export_f`, `rescore_wfg`, `rescore_rwmop`, and `conv_c`), after setting the PlatEMO folder:

```matlab
setenv('PLATEMO_ROOT','C:\PlatEMO\PlatEMO')
export_c({'C1'})
```

The raw run files are not included because of their size. They are available from the authors on request.

## Citation

If you use this code, please cite the article above. A BibTeX entry will be added on publication. Since TP-IM-MOEA runs on PlatEMO, please also cite:

> Y. Tian, R. Cheng, X. Zhang, and Y. Jin, "PlatEMO: A MATLAB platform for evolutionary multi-objective optimization [educational forum]," *IEEE Computational Intelligence Magazine*, vol. 12, no. 4, pp. 73–87, 2017.

## License

The code written for this repository is released under the [MIT License](LICENSE). The files derived from PlatEMO (`PROBLEM.m`, the RWMOP problems, `CSEA.m`, `Operator.m` of IM-MOEA/D, and `KRVEANI.m`) keep the terms of PlatEMO stated in their headers: free use for research purposes, with acknowledgment of PlatEMO.

Questions and suggestions are welcome through the [issue tracker](../../issues).
