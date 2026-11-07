"""Phase AB: X1 (TPN, 20% ordering + cell read-out) on the suites of phase Y, against g15 and X2 (same tasks
and seeds), and its position against the other algorithms. AB1 WFG m in {15, 20} (IGD), AB2 RWMOP (HV, fixed
normalization of the article), AB3 DTLZ (IGD). The RWMOP ratio is also given on the problems where g15 finds
a feasible set in at least half of the runs, since a zero HV makes the ratio undefined (flaw of phase Y)."""
from pathlib import Path
import numpy as np, pandas as pd

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
exec(open(HERE / 'analyze_y.py', encoding='utf-8').read().split("KEY3 = ['prob'")[0])   # head2head, position, ...

KEY3 = ['prob', 'M', 'D']
C2 = pd.read_csv(H / 'c_C2.csv'); D2 = pd.read_csv(H / 'c_D2.csv')
hv = pd.read_csv(H / 'rwmop_hv.csv')
G = {'AB1': C2[C2.config == 'g15'], 'AB2': hv[hv.config == 'g15'], 'AB3': D2[D2.config == 'g15']}
X2 = {'AB1': pd.read_csv(H / 'c_Y1.csv'), 'AB2': pd.read_csv(H / 'rwmop_hv_y.csv'), 'AB3': pd.read_csv(H / 'c_Y3.csv')}
X1 = {'AB1': pd.read_csv(H / 'c_AB1.csv'), 'AB2': pd.read_csv(H / 'rwmop_hv_ab.csv'), 'AB3': pd.read_csv(H / 'c_AB3.csv')}
assert [len(X1[k]) for k in G] == [1080, 1050, 900]
feas = G['AB2'].groupby('prob').HVnorm.apply(lambda s: (s > 0).mean() >= 0.5)
feas = set(feas[feas].index)
spec = {'AB1': ('WFG m=15,20 (IGD)', 'IGDall', True, KEY3), 'AB2': ('RWMOP (HV)', 'HVnorm', False, ['prob']),
        'AB3': ('DTLZ (IGD)', 'IGDall', True, KEY3)}

for who, A, B in [('X1 vs g15', X1, G), ('X1 vs X2', X1, X2), ('X2 vs g15', X2, G)]:
    print(f'\n{who} (+ = first better; ratio below 1 favours the first; 95% cluster-bootstrap interval over problems)')
    for k, (lab, val, lower, key) in spec.items():
        r = head2head(A[k], B[k], val, lower, key)
        print(f"  {lab:<20} n={r['n']:>2}  +/-/= {r['wlt']:>8}  signed-rank p={r['p']:.3g} ({who.split()[0 if r['better'] else 2]} ahead)"
              f"  ratio {r['ratio']:.3f} [{r['lo']:.3f}, {r['hi']:.3f}]")
        if k == 'AB2':
            r = head2head(A[k][A[k].prob.isin(feas)], B[k][B[k].prob.isin(feas)], val, lower, key)
            print(f"  {'  feasible (g15>=50%)':<20} n={r['n']:>2}  +/-/= {r['wlt']:>8}  signed-rank p={r['p']:.3g}"
                  f"  ratio {r['ratio']:.3f} [{r['lo']:.3f}, {r['hi']:.3f}]")
        for m in sorted(A[k].M.unique()) if k != 'AB2' else []:
            r = head2head(A[k][A[k].M == m], B[k][B[k].M == m], val, lower, key)
            print(f"     m={m:<16} n={r['n']:>2}  +/-/= {r['wlt']:>8}  signed-rank p={r['p']:.3g}  ratio {r['ratio']:.3f} [{r['lo']:.3f}, {r['hi']:.3f}]")
    rw = pd.concat([A['AB2'].assign(s='a'), B['AB2'].assign(s='b')])
    d = rw.groupby(['s', 'prob']).HVnorm.mean().unstack(0)
    big = (d.a - d.b).abs().sort_values(ascending=False).head(4)
    print('  RWMOP largest mean-HV gaps: ' + ', '.join(f"{p} {d.a[p]:.3f} vs {d.b[p]:.3f}" for p in big.index))

print('\nPosition against the other algorithms (analysis of the article):')
for lab, base, k, val, lower, kr in [('WFG m=15,20', MO, 'AB1', 'IGDall', True, None), ('RWMOP', RW, 'AB2', 'HVnorm', False, None),
                                     ('DTLZ', DT, 'AB3', 'IGDall', True, lambda i: i[2] == 10)]:
    for who, XX in [('g15', None), ('X2', X2[k]), ('X1', X1[k])]:
        if XX is not None:
            XX = XX.assign(alg='OURS', M=0, D=0)[['alg', 'prob', 'M', 'D', 'run', 'HVnorm']] if k == 'AB2' else XX.assign(alg='OURS')[COLS]
        o = position(base, XX, val, lower, lab, kr)
        print(f"  {lab:<12} {who:<4} rank {o['rank']:5.2f}  position {o['pos']}/{o['n']}  sig. better than {len(o['better'])}"
              f"  sig. worse than {len(o['worse'])}{' (' + ', '.join(o['worse']) + ')' if o['worse'] else ''}  equal: {', '.join(o['equal'])}")
