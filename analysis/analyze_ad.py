"""Phase AD, analysed as pre-registered (TP-IM-MOEA/docs/phase_AD_preregistration.md): proposals A (unreachable
niches), B (gap-aware cell read-out), A+B and the control of B, against the final model F on the same seeds.
F = X1 of phase X (WFG m 3-9), X2 of phase Y (WFG m 15/20), X1 of phase AB (DTLZ), gated_repair_global of AC4
(RWMOP). Also block Z10 (clean ablation without the SOM). Read-only."""
from pathlib import Path
import numpy as np, pandas as pd

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
exec(open(HERE / 'analyze_y.py', encoding='utf-8').read().split("KEY3 = ['prob'")[0])   # head2head, position, holm, ...
KEY3 = ['prob', 'M', 'D']
AC = pd.read_csv(H / 'c_AC.csv')
get = lambda b, p: AC[(AC.block == b) & (AC.config == p)]
X1 = pd.read_csv(H / 'c_X1.csv'); X1 = X1[X1.config == 'X1_TPN']
REF = {'AD1': X1, 'AD2': pd.read_csv(H / 'c_Y1.csv'), 'AD3': pd.read_csv(H / 'c_AB3.csv'), 'AD4': get('AC4', 'gated_repair_global')}
LAB = {'AD1': 'WFG m=3,6,9', 'AD2': 'WFG m=15,20', 'AD3': 'DTLZ m=3,6,9', 'AD4': 'RWMOP'}
P3 = ['final_A', 'final_B', 'final_AB']

res = {}
print('Each profile against F (+ = profile better; ratio below 1 favours the profile; 95% cluster-bootstrap CI)')
for b in ['AD1', 'AD2', 'AD3']:
    print(f'\n {LAB[b]}')
    profs = P3 + ['final_Brand']
    rr = {p: head2head(get(b, p), REF[b], 'IGDall', True, KEY3) for p in profs}
    ph = dict(zip(P3, holm([rr[p]['p'] for p in P3])))
    for p in profs:
        r = rr[p]; r['pHolm'] = ph.get(p, np.nan); ms = []
        for m in sorted(REF[b].M.unique()):
            rm = head2head(get(b, p)[get(b, p).M == m], REF[b][REF[b].M == m], 'IGDall', True, KEY3)
            r[f'hi_m{m}'] = rm['hi']; ms.append(f"m{m} {rm['wlt']} {rm['ratio']:.3f}[{rm['hi']:.3f}]")
        print(f"  {p:<12} {r['wlt']:>9} p={r['p']:.3g} pHolm={r['pHolm']:.3g} ratio {r['ratio']:.3f} [{r['lo']:.3f}, {r['hi']:.3f}] | {' | '.join(ms)}")
        res[(b, p)] = r

print('\n RWMOP (HV, fixed normalization)')
ref4 = REF['AD4']
for p in P3:
    X = get('AD4', p)
    r = head2head(X, ref4, 'HVnorm', False, ['prob'])
    d = X.groupby('prob').HVnorm.mean() - ref4.groupby('prob').HVnorm.mean()
    r['worst'] = d.min(); r['nloss'] = int((d < -0.01).sum())
    r['ok'] = d.min() >= -0.01 and not (r['p'] < 0.05 and not r['better'])
    big = d[d.abs() > 0.01].sort_values()
    print(f"  {p:<12} {r['wlt']:>9} p={r['p']:.3g} ({'profile' if r['better'] else 'F'} ahead); worst mean-HV change {d.min():+.4f}; "
          f"losses above 0.01: {r['nloss']}" + (f"  [{', '.join(f'{q} {v:+.3f}' for q, v in big.items())}]" if len(big) else ''))
    res[('AD4', p)] = r

print('\nPre-registered rule')
ok = {}
for p in P3:
    a = res[('AD3', p)]
    c1 = a['pHolm'] < 0.05 and a['better'] and a['hi'] < 1
    bad = [f"{LAB[b]}{'' if k == 'hi' else ' ' + k[3:]}" for b in ['AD1', 'AD2'] for k, v in res[(b, p)].items()
           if (k == 'hi' or k.startswith('hi_m')) and v >= 1.03]
    c2 = not bad and res[('AD4', p)]['ok']
    ok[p] = c1 and c2
    print(f"  {p:<12} (1) DTLZ better: {c1} (ratio {a['ratio']:.3f}, pHolm {a['pHolm']:.3g}); (2) non-inferior elsewhere: {c2}"
          f"{' (CI upper >= 1.03 in ' + ', '.join(bad) + ')' if bad else ''}{'' if res[('AD4', p)]['ok'] else ' (RWMOP fails)'}  ->  {'QUALIFIES' if ok[p] else 'no'}")
if ok['final_AB']: dec = 'final_AB'
elif ok['final_A'] or ok['final_B']: dec = min([p for p in ['final_A', 'final_B'] if ok[p]], key=lambda p: res[('AD3', p)]['ratio'])
else: dec = None
print('DECISION:', f'{dec} is adopted' if dec else 'no proposal qualifies; F remains the final model')

r = head2head(get('AD3', 'final_B'), get('AD3', 'final_Brand'), 'IGDall', True, KEY3)
print(f"\n(4) final_B vs final_Brand on DTLZ: {r['wlt']} p={r['p']:.3g} ({'B' if r['better'] else 'random cut'} ahead) ratio {r['ratio']:.3f}")

print('\n(5) DTLZ7 alone, mean IGD by m and d')
d7 = pd.concat([REF['AD3'].assign(m='F')] + [get('AD3', p).assign(m=p) for p in P3 + ['final_Brand']])
d7 = d7[d7.prob == 'DTLZ7']
print(d7.groupby(['M', 'D', 'm']).IGDall.mean().unstack().round(3).to_string())
print('  mean unreachable niches / cut edges per generation are in c_AC.csv only as run-level summaries (not exported)')

print('\nPosition against the other algorithms (analysis of the article):')
for lab, base, b, kr in [('WFG m=3,6,9', WFG, 'AD1', lambda i: i[2] == 10), ('WFG m=15,20', MO, 'AD2', None), ('DTLZ', DT, 'AD3', lambda i: i[2] == 10)]:
    for who, XX in [('F', REF[b])] + [(p, get(b, p)) for p in P3]:
        o = position(base, XX.assign(alg='OURS')[COLS], 'IGDall', True, lab, kr)
        print(f"  {lab:<12} {who:<10} rank {o['rank']:5.2f}  position {o['pos']}/{o['n']}  better than {len(o['better'])}  worse than {len(o['worse'])}"
              f"{' (' + ', '.join(o['worse']) + ')' if o['worse'] else ''}")
for who, XX in [('F', ref4)] + [(p, get('AD4', p)) for p in P3]:
    o = position(RW, XX.assign(alg='OURS', M=0, D=0)[['alg', 'prob', 'M', 'D', 'run', 'HVnorm']], 'HVnorm', False, 'RWMOP', None)
    print(f"  {'RWMOP':<12} {who:<10} rank {o['rank']:5.2f}  position {o['pos']}/{o['n']}  better than {len(o['better'])}  worse than {len(o['worse'])}")

z10 = pd.read_csv(H / 'c_Z10.csv'); k1 = pd.read_csv(H / 'c_K1.csv'); C1 = pd.read_csv(H / 'c_C1.csv')
a = head2head(z10, X1, 'IGDall', True, KEY3); g = head2head(k1, C1[C1.config == 'g15'], 'IGDall', True, KEY3)
print(f"\nZ10, clean ablation without the SOM (topo = 4) against the complete model: F {a['wlt']} ratio {a['ratio']:.3f} "
      f"[{a['lo']:.3f}, {a['hi']:.3f}] p={a['p']:.2g} | g15 {g['wlt']} ratio {g['ratio']:.3f} [{g['lo']:.3f}, {g['hi']:.3f}] p={g['p']:.2g}")
for m in (3, 6, 9):
    a = head2head(z10[z10.M == m], X1[X1.M == m], 'IGDall', True, KEY3)
    print(f"   m={m}: {a['wlt']} ratio {a['ratio']:.3f}")
