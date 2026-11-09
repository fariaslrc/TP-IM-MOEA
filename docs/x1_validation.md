# Verification of the X1 implementation

## Development computer, 2026-11-04

Environment: MATLAB R2026b, Windows. The complete PlatEMO distribution was loaded, followed by the overlay of this repository. No benchmark objective function was evaluated in this verification.

| Check | Result |
|---|---|
| `test_x1_core` | Passed: graph, off-diagonal mass, coordinate transport, buffer, profiles, and RNG preservation. |
| `test_x1_movement` | Passed: pairs, feasibility, direction, controls, support, radius, fallback, and feedback. |
| `test_x1_repair` | Passed: affine models, chronological validation, rank and conditioning, QP, bounds, zero constraints, and RNG preservation. |
| `run_check_x1_installation(true)` | Passed: complete distribution, overlay, AC_A–AC_E grids, parameters, historical seeds, and SHA-256 identities. |
| `test_ac_resume` | Passed: eight synthetic integrity cases, including a different configuration, missing or truncated records, a missing source, and invalid final objectives. No algorithm was run. |
| Metaclass loading | Passed for X1C, X1M, X1F, X1CMF, and the synthetic fixture, without instantiating the algorithms. |
| `checkcode` | No syntax errors in the files of the extension, runner, tests, exporter, and integration. Style and array-growth warnings do not prevent execution. |
| `git diff --check` | Passed. |

The first repair test found a synthetic fixture with insufficient rank in the local pools. The gate correctly rejected those models; the fixture was replaced by a deterministic sample from a private random stream. The explicit rank-deficiency test was kept, and the full suite passed after the correction.

## Execution machine, before the campaigns

`test_x1_integration` passed on the machine that ran the experiments, as part of the phase AC smoke test (2026-11-04): 19 profiles, the parity of `identity` with the historical path, the compatibility of the 44 earlier parameters, and the four wrappers. The same smoke test reproduced exactly the published run 1 of g15 and of the earlier X1 profile on WFG4 (m = 3 and 15), DTLZ2, and RWMOP1, and of the gated profile on WFG4 (m = 3 and 15) and RWMOP1, and it confirmed that the repair restores feasibility on RWMOP30.

The installation check of the public class, `run_check_tpimmoea`, passed all five of its checks on the same machine (see the README).

These results demonstrate properties of the components and the consistency of the installation. They do not by themselves demonstrate improvements in IGD or HV, feasibility on RWMOP, or superiority over comparators; those conclusions rest on the experimental campaigns and the [experimental protocol](phase_AC_protocol.md).
