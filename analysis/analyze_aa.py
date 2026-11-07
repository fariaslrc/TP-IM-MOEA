"""Phase AA, analysed as pre-registered (TP-IM-MOEA/docs/phase_AA_preregistration.md), plus the position
of each variant against the other algorithms (overall and for m = 3)."""
from pathlib import Path
import numpy as np, pandas as pd

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
exec(open(HERE / 'analyze_v.py', encoding='utf-8').read().split("C1 = pd.read_csv(H / 'c_C1.csv')")[0])

C1 = pd.read_csv(H / 'c_C1.csv'); G15 = C1[C1.config == 'g15']
A = pd.read_csv(H / 'c_AA1.csv'); assert len(A) == 6480
AA = {c: A[A.config == c] for c in A.config.unique()}
a0 = AA['AA0_g15'].merge(G15[KEY + ['run', 'IGDall']], on=KEY + ['run'], suffixes=('', '_g'))
print(f"Check: AA0 equal to C1 g15 in {(a0.IGDall == a0.IGDall_g).sum()} of {len(a0)} runs; "
      f"300 evaluations in {(A.nRecorded == 300).mean():.0%}")

cand = ['AA1_batch1', 'AA2_arc300', 'AA3_both']
rows = []
for v in cand:
    r = compare(AA[v], G15); r['name'] = v; rows.append(r)
for r, pa in zip(rows, holm([r['all_p'] for r in rows])): r['pHolm'] = pa
print('\nPrimary comparisons against g15, Holm over the three:')
table(rows, 'g15')
print()
sup = []
for r in rows:
    ci = {k: ratio_ci(AA[r['name']], G15, s) for k, s in [('all', None), ('m3', lambda d: d.M == 3), ('m6', lambda d: d.M == 6), ('m9', lambda d: d.M == 9)]}
    c1 = r['pHolm'] < 0.05 and r['all_dir'] > 0; c2 = ci['all'][0] <= 0.98 and ci['all'][2] < 1; c3 = all(ci[k][2] < 1.03 for k in ['m3', 'm6', 'm9'])
    print(f"  {r['name']:<11} " + ' | '.join(f'{k} {e:.3f} [{lo:.3f}, {hi:.3f}]' for k, (e, lo, hi) in ci.items())
          + f"  ->  (1) {c1} (2) {c2} (3) {c3}: {'SUPERIOR' if c1 and c2 and c3 else 'not superior'}")
    if c1 and c2 and c3: sup.append(r['name'])
print('\nSuperior under the rule:', ', '.join(sup) or 'none')

print('\nFactorial reading (no decision):')
fr = []
for name, a, b in [('batch: AA1 vs g15', 'AA1_batch1', None), ('batch: AA3 vs AA2', 'AA3_both', 'AA2_arc300'),
                   ('archive: AA2 vs g15', 'AA2_arc300', None), ('archive: AA3 vs AA1', 'AA3_both', 'AA1_batch1')]:
    q = compare(AA[a], G15 if b is None else AA[b]); q['name'] = name; q['pHolm'] = q['all_p']; fr.append(q)
table(fr, 'the second')

t0 = AA['AA0_g15'].runtime.mean()
print('\nWall time per run relative to AA0 (same PC): ' + ', '.join(f'{c} {AA[c].runtime.mean() / t0:.2f} ({AA[c].runtime.mean():.2f} s)' for c in AA))

src = open(HERE / 'compare_all_variants.py', encoding='utf-8').read().split("C3 = pd.read_csv")[0]
exec(src)
print('\nPosition against the other algorithms (WFG, 15 algorithms, Holm):')
W3 = WFG[WFG.M == 3]
for lab, X in [('g15', None)] + [(c, AA[c]) for c in cand]:
    o = position(WFG, X, 'IGDall', True, 'WFG', lambda i: i[2] == 10)
    o3 = position(W3, None if X is None else X[X.M == 3], 'IGDall', True, 'WFG3', lambda i: i[2] == 10)
    print(f"  {lab:<11} all: rank {o['rank']:.2f} ({o['pos']}/{o['n']}), better than {len(o['better'])}, worse than {o['worse']}, "
          f"equal {o['equal']} | m=3: rank {o3['rank']:.2f} ({o3['pos']}/{o3['n']}), vs PIEA {o3['counts']['PIEA']}, equal {o3['equal']}")
