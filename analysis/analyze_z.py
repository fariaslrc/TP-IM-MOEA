"""Phase Z, version 2: the supporting experiments of the article rerun with the final model F (X1 with the
ordering gate and the global repair; on WFG/DTLZ with m <= 9, F is X1). Each comparison is shown for F and,
next to it, for g15 (the version in the article), with the same seeds. Read-only.
+/-/= : the variant better/worse/equal than its reference (rank-sum per instance, 5%); ratio below 1 favours
the variant; 95% cluster-bootstrap interval over problems."""
from pathlib import Path
import numpy as np, pandas as pd

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
exec(open(HERE / 'analyze_y.py', encoding='utf-8').read().split("KEY3 = ['prob'")[0])   # head2head, ...
KEY3 = ['prob', 'M', 'D']
rd = lambda f: pd.read_csv(H / f)
cfg = lambda T, c: T[T.config == c]

X1 = cfg(rd('c_X1.csv'), 'X1_TPN'); C1 = rd('c_C1.csv'); G15 = cfg(C1, 'g15')
Z = {b: rd(f'c_{b}.csv') for b in ['Z1', 'Z2', 'Z4', 'Z5', 'Z6', 'Z7', 'Z8', 'Z9']}
OLD = {'C3': rd('c_C3.csv'), 'C4': rd('c_C4.csv'), 'F1': rd('c_F1.csv'), 'G1': rd('c_G1.csv'),
       'G2': rd('c_G2.csv'), 'H1': rd('c_H1.csv'), 'I1': rd('c_I1.csv')}

def line(lab, Xf, Rf, Xg, Rg, val='IGDall', lower=True):
    a = head2head(Xf, Rf, val, lower, KEY3); b = head2head(Xg, Rg, val, lower, KEY3)
    print(f"  {lab:<26} F: {a['wlt']:>9} ratio {a['ratio']:.3f} [{a['lo']:.3f}, {a['hi']:.3f}] p={a['p']:.2g}"
          f"   | g15: {b['wlt']:>9} ratio {b['ratio']:.3f} [{b['lo']:.3f}, {b['hi']:.3f}] p={b['p']:.2g}")

print('Z1, ablation (variant against the complete model, WFG 54 instances)')
for c in sorted(Z['Z1'].config.unique()):
    line(c, cfg(Z['Z1'], c), X1, cfg(OLD['C3'], c), G15)

print('\nZ2, sensitivity (setting against the default, 8 WFG instances)')
s00f, s00g = cfg(Z['Z2'], 's00_default'), cfg(OLD['C4'], 's00_default')
for c in sorted(Z['Z2'].config.unique()):
    if c == 's00_default': continue
    line(c, cfg(Z['Z2'], c), s00f, cfg(OLD['C4'], c), s00g)

print('\nZ4, anchors permuted (against the instrumented complete model, WFG 54 instances)')
rf, rg = cfg(Z['Z4'], 'g15i'), cfg(OLD['F1'], 'g15i')
print(f"  instrumented reference equals the model: F {np.allclose(rf.sort_values(['prob','M','D','run']).IGDall.values, X1.sort_values(['prob','M','D','run']).IGDall.values)}, "
      f"g15 {np.allclose(rg.sort_values(['prob','M','D','run']).IGDall.values, G15.sort_values(['prob','M','D','run']).IGDall.values)}")
for c in ['a025', 'a050', 'a100']:
    line(c, cfg(Z['Z4'], c), rf, cfg(OLD['F1'], c), rg)

print('\nZ5, prescreening controls (WFG 54 instances)')
noPSf, noPSg = cfg(Z['Z1'], 'q04_noPre'), cfg(OLD['C3'], 'q04_noPre')
for c in ['r1', 'r2']:
    line(f'{c} vs model', cfg(Z['Z5'], c), X1, cfg(OLD['G1'], c), G15)
    line(f'{c} vs no prescreening', cfg(Z['Z5'], c), noPSf, cfg(OLD['G1'], c), noPSg)
line('r2 vs r1', cfg(Z['Z5'], 'r2'), cfg(Z['Z5'], 'r1'), cfg(OLD['G1'], 'r2'), cfg(OLD['G1'], 'r1'))

print('\nZ6, all anchors permuted on DTLZ (against the instrumented model, 30 instances)')
line('a100', cfg(Z['Z6'], 'a100'), cfg(Z['Z6'], 'g15i'), cfg(OLD['G2'], 'a100'), cfg(OLD['G2'], 'g15i'))

print('\nZ7, budget: F against g15 with the same budget (WFG, 18 instances)')
for c in ['g15_FE600', 'g15_FE1000']:
    a = head2head(cfg(Z['Z7'], c), cfg(OLD['H1'], c), 'IGDall', True, KEY3)
    print(f"  {c:<26} F vs g15: {a['wlt']:>9} ratio {a['ratio']:.3f} [{a['lo']:.3f}, {a['hi']:.3f}] p={a['p']:.2g}")

print('\nZ8, population size (against N = 50, the default of Z2/C4)')
for c in ['n030', 'n100']:
    line(c, cfg(Z['Z8'], c), s00f, cfg(OLD['I1'], c), s00g)

z9 = Z['Z9']
if 'tSolve' in z9.columns or 'runtime' in z9.columns:
    col = 'tSolve' if 'tSolve' in z9.columns else 'runtime'
    t = z9.groupby('config')[col].mean()
    print(f"\nZ9, time (same load, 4 workers): F {t.get('F', np.nan):.2f} s, g15 {t.get('g15', np.nan):.2f} s, ratio {t.get('F', np.nan)/t.get('g15', np.nan):.2f}")

for b, f in [('Z4', 'f_Z4.csv'), ('Z6', 'f_Z6.csv')]:
    if (H / f).exists():
        T = rd(f); col = [c for c in ['rhoTopo', 'rho'] if c in T.columns]
        if col:
            print(f"\n{b}, topology of the final map (mean {col[0]} by configuration): " +
                  ', '.join(f"{c} {v:.3f}" for c, v in T.groupby('config')[col[0]].mean().items()))
