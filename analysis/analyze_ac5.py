"""Phase AC, block AC5, analysed as fixed in the addendum of 2026-11-05 (docs/phase_AC_protocol.md):
(1) gated_mass on RWMOP against gated (X1 of phase AB): no problem with a mean-HV loss above 0.01 and
no significantly unfavourable signed-rank (5%); (2) gated_mass_repair_global against gated_repair_global:
the same HV rule, and no drop of the final-feasible rate on RWMOP30-35. Read-only."""
from pathlib import Path
import numpy as np, pandas as pd

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
exec(open(HERE / 'analyze_y.py', encoding='utf-8').read().split("KEY3 = ['prob'")[0])   # head2head, position, ...

AC = pd.read_csv(H / 'c_AC.csv')
ab = pd.read_csv(H / 'rwmop_hv_ab.csv'); ab = ab.assign(finalFeasible=(ab.nBest > 0).astype(float))
get = lambda b, p: AC[(AC.block == b) & (AC.config == p)]
M5, MR = get('AC5', 'gated_mass'), get('AC5', 'gated_mass_repair_global')
RG = get('AC4', 'gated_repair_global')
assert len(M5) == 1050 and len(MR) == 1050 and len(RG) == 1050
HARD = [f'RWMOP{i}' for i in range(30, 36)]

def check(lab, X, Y, hard_feas):
    r = head2head(X, Y, 'HVnorm', False, ['prob'])
    d = X.groupby('prob').HVnorm.mean() - Y.groupby('prob').HVnorm.mean()
    worst = d.idxmin()
    unfav = r['p'] < 0.05 and not r['better']
    ok = d.min() >= -0.01 and not unfav
    line = (f"{lab}: HV {r['wlt']} signed-rank p={r['p']:.3g} ({'first' if r['better'] else 'second'} ahead); "
            f"worst mean-HV change {d.min():+.4f} ({worst}); losses above 0.01 in {int((d < -0.01).sum())}")
    if hard_feas:
        fx = X.groupby('prob').finalFeasible.mean()[HARD]; fy = Y.groupby('prob').finalFeasible.mean()[HARD]
        drop = (fx < fy - 1e-12).any(); ok = ok and not drop
        line += f"; feasible on RWMOP30-35 {fx.mean()*100:.0f}% vs {fy.mean()*100:.0f}%"
    print(line + f"  ->  {'PASS' if ok else 'FAIL'}")
    big = d[d.abs() > 0.005].sort_values()
    if len(big): print('     problems with |mean-HV change| > 0.005: ' + ', '.join(f'{p} {v:+.4f}' for p, v in big.items()))
    return ok

c1 = check('(1) gated_mass vs gated', M5, ab, False)
c2 = check('(2) gated_mass_repair_global vs gated_repair_global', MR, RG, True)
print('DECISION:', 'final model = X1 + ordering gate + mass cap + global repair' if (c1 and c2)
      else ('final model = X1 + ordering gate + global repair (the mass cap does not enter)' if not c1
            else 'mass cap passes alone but not with the repair: review before deciding'))

print('\nPosition on RWMOP against the other algorithms (analysis of the article):')
for who, XX in [('gated (X1)', ab), ('gated_repair_global', RG), ('gated_mass', M5), ('gated_mass_repair_global', MR)]:
    o = position(RW, XX.assign(alg='OURS', M=0, D=0)[['alg', 'prob', 'M', 'D', 'run', 'HVnorm']], 'HVnorm', False, 'RWMOP', None)
    print(f"  {who:<26} rank {o['rank']:5.2f}  position {o['pos']}/{o['n']}  better than {len(o['better'])}  worse than {len(o['worse'])}")
print('  solve time (s, mean): ' + ', '.join(f'{p} {X.tSolve.mean():.1f}' for p, X in
      [('gated_repair_global', RG), ('gated_mass', M5), ('gated_mass_repair_global', MR)]))
