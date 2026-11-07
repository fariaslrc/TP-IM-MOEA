"""Statistical position of every TP-IM-MOEA variant run under the protocol of the article, each one
placed alone in the comparison with the other algorithms, scenario by scenario, with the analysis of
posthoc_c.py: Friedman mean rank on the instance means, Wilcoxon signed-rank test over the instances
against each algorithm with Holm over the algorithms of the scenario (K-RVEA on d = 10, unadjusted),
and the per-instance rank-sum counts. Read-only: writes no table of the manuscript.

Variants by scenario (only those with runs on the full instance set of the scenario):
  WFG (54)    g15 (C1); ablation C3 (with K1 for noSOM); anchors F1; prescreening controls G1;
              phases T, U, V (and W, X when their CSVs exist)
  DTLZ (30)   g15 (D2) and all anchors permuted (G2, a100)
  RWMOP (35)  g15 only
"""
from pathlib import Path
import numpy as np, pandas as pd
from scipy.stats import ranksums

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
src = open(HERE / 'posthoc_c.py', encoding='utf-8').read()
src = src.split('ABL = pd.concat')[0].replace("H = Path(__file__).parent", "H = Path(r'%s')" % H)
exec(src)                                     # WFG, DT, RW, scenario, c, COLS (data assembly of the article)


def tag(x, y, lower):
    if np.allclose(x, x[0]) and np.allclose(y, y[0]) and np.isclose(x[0], y[0]): return '='
    if ranksums(x, y).pvalue >= 0.05: return '='
    return '+' if ((x.mean() < y.mean()) if lower else (x.mean() > y.mean())) else '-'


def position(base, X, val, lower, label, kr):
    D = base if X is None else pd.concat([base[base.alg != 'OURS'], X.assign(alg='OURS')[COLS if val == 'IGDall' else ['alg', 'prob', 'M', 'D', 'run', val]]], ignore_index=True)
    R = pd.DataFrame(scenario(D, val, lower, label, kr), columns=['scenario', 'alg', 'rank', 'pHolm', 'A12', 'large', 'n'])
    rk = R.set_index('alg')['rank'].dropna().sort_values()
    G = {k: g[val].values for k, g in D.groupby(['alg', 'prob', 'M', 'D'])}
    out = {'rank': rk['OURS'], 'pos': list(rk.index).index('OURS') + 1, 'n': len(rk), 'better': [], 'worse': [], 'equal': [], 'counts': {}}
    sgn = 1 if lower else -1
    for _, r in R[R.alg != 'OURS'].iterrows():
        inst = sorted(k[1:] for k in G if k[0] == r.alg and ('OURS',) + k[1:] in G)
        mo = np.array([sgn * G[('OURS',) + i].mean() for i in inst]); ma = np.array([sgn * G[(r.alg,) + i].mean() for i in inst])
        d = ma - mo; nz = d[d != 0]; rr = pd.Series(np.abs(nz)).rank().values
        ours_better = rr[nz > 0].sum() > rr[nz < 0].sum()
        if r.pHolm < 0.05:
            (out['better'] if ours_better else out['worse']).append(r.alg)
        else:
            out['equal'].append(r.alg)
        t = [tag(G[('OURS',) + i], G[(r.alg,) + i], lower) for i in inst]
        out['counts'][r.alg] = f"{t.count('+')}/{t.count('-')}/{t.count('=')}"
    return out


C3 = pd.read_csv(H / 'c_C3.csv'); K1 = pd.read_csv(H / 'c_K1.csv'); F1 = pd.read_csv(H / 'c_F1.csv'); G1 = pd.read_csv(H / 'c_G1.csv')
blocks = [('Article', [('g15 (final configuration)', None)])]
blocks.append(('Ablation C3', [(c, C3[C3.config == c]) for c in sorted(C3.config.unique()) if c != 'q06_noSOM']
               + [('K1 noSOM (topo 4)', K1)]))
blocks.append(('Anchors F1, controls G1', [(c, F1[F1.config == c]) for c in ['a025', 'a050', 'a100']]
               + [(c, G1[G1.config == c]) for c in sorted(G1.config.unique())]))
for b, f, skip in [('Phase T', 'c_T1.csv', []), ('Phase U', 'c_U1.csv', ['U0_Prototype']), ('Phase V', 'c_V1.csv', ['V0_DasDennis']),
                   ('Phase W', 'c_W1.csv', []), ('Phase X', 'c_X1.csv', [])]:
    if (H / f).exists():
        d = pd.read_csv(H / f)
        blocks.append((b, [(c, d[d.config == c]) for c in sorted(d.config.unique()) if c not in skip]))

kr = lambda i: i[2] == 10
rows = []
for b, lst in blocks:
    for lab, X in lst:
        o = position(WFG, X, 'IGDall', True, 'WFG', kr)
        rows.append((b, lab, o))
print('\n================ WFG (54 instances; Friedman over 15 algorithms; K-RVEA on d = 10)')
print(f"{'block':<24} {'variant':<26} {'rank':>5} {'pos':>6}  {'sig. better than':>16} {'sig. worse than':>16}   PIEA     EGES     K-RVEA   (variant vs rival, +/-/=)")
for b, lab, o in rows:
    print(f"{b:<24} {lab[:26]:<26} {o['rank']:5.2f} {o['pos']:>3}/{o['n']:<2}  {len(o['better']):>16} {len(o['worse']):>16}   "
          f"{o['counts']['PIEA']:<8} {o['counts']['EGES']:<8} {o['counts']['KRVEA']:<8} "
          + (f"worse than: {', '.join(o['worse'])}" if o['worse'] else '') + (f" equal: {', '.join(o['equal'])}" if o['equal'] else ''))

print('\n================ DTLZ (30 instances; K-RVEA on d = 10)')
G2 = pd.read_csv(H / 'c_G2.csv')
for lab, X in [('g15 (final configuration)', None), ('a100 (all anchors permuted)', G2[G2.config == 'a100'])]:
    o = position(DT, X, 'IGDall', True, 'DTLZ', kr)
    print(f"{lab:<30} rank {o['rank']:5.2f}  position {o['pos']}/{o['n']}  sig. better than {len(o['better'])}, sig. worse than {len(o['worse'])}"
          + (f" ({', '.join(o['worse'])})" if o['worse'] else '') + f"; equal: {', '.join(o['equal'])}")

print('\n================ RWMOP (35 problems, HV)')
o = position(RW, None, 'HVnorm', False, 'RWMOP', None)
print(f"g15 (final configuration)      rank {o['rank']:5.2f}  position {o['pos']}/{o['n']}  sig. better than {len(o['better'])} "
      f"({', '.join(o['better'])}), sig. worse than {len(o['worse'])}; equal: {', '.join(o['equal'])}")
print('No other TP-IM-MOEA variant was run on RWMOP or on all 30 DTLZ instances under the protocol of the article.')
