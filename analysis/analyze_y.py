"""Phase Y, analysed as pre-registered (TP-IM-MOEA/docs/phase_Y_preregistration.md): X2 against g15 on
the suites that took no part in its selection, and its position against the other algorithms.
Y1 WFG m in {15, 20} (IGD), Y2 RWMOP (HV, fixed normalization of the article), Y3 DTLZ (IGD, reported only)."""
from pathlib import Path
import numpy as np, pandas as pd
from scipy.stats import ranksums, wilcoxon

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
src = open(HERE / 'compare_all_variants.py', encoding='utf-8').read().split("C3 = pd.read_csv")[0]
exec(src)                                                  # WFG, MO, DT, RW, scenario, position, holm, COLS


def tagv(x, y, lower):
    if len(x) == 0 or len(y) == 0: return '='
    if np.allclose(x, x[0]) and np.allclose(y, y[0]) and np.isclose(x[0], y[0]): return '='
    if ranksums(x, y).pvalue >= 0.05: return '='
    return '+' if ((x.mean() < y.mean()) if lower else (x.mean() > y.mean())) else '-'


def head2head(X, Y, val, lower, key, B=10000, seed=1):
    """X2 (X) against g15 (Y): rank-sum counts, signed-rank over the instance means, and the ratio
    favouring X2 below 1 (IGD: X2/g15; HV: g15/X2) with a cluster bootstrap over problems."""
    gx = {k: g[val].values for k, g in X.groupby(key)}; gy = {k: g[val].values for k, g in Y.groupby(key)}
    inst = sorted(set(gx) & set(gy))
    t = [tagv(gx[i], gy[i], lower) for i in inst]
    mx = np.array([gx[i].mean() for i in inst]); my = np.array([gy[i].mean() for i in inst])
    d = (my - mx) if lower else (mx - my)                   # > 0 where X2 is better
    p = wilcoxon(mx, my).pvalue if np.any(d != 0) else 1.0
    nz = d[d != 0]; rr = pd.Series(np.abs(nz)).rank().values; better = rr[nz > 0].sum() > rr[nz < 0].sum()
    eps = 1e-12
    lr = np.log((mx + eps) / (my + eps)) if lower else np.log((my + eps) / (mx + eps))
    prob = [i[0] if isinstance(i, tuple) else i for i in inst]
    by = {pp: lr[[q == pp for q in prob]] for pp in sorted(set(prob))}
    rng = np.random.default_rng(seed); ps = list(by); bs = np.empty(B)
    for b in range(B):
        bs[b] = np.mean(np.concatenate([by[q] for q in rng.choice(ps, len(ps), replace=True)]))
    lo, hi = np.exp(np.percentile(bs, [2.5, 97.5]))
    return dict(n=len(inst), wlt=f"{t.count('+')}/{t.count('-')}/{t.count('=')}", p=p, better=better,
                ratio=float(np.exp(lr.mean())), lo=lo, hi=hi)


KEY3 = ['prob', 'M', 'D']
C2 = pd.read_csv(H / 'c_C2.csv'); D2 = pd.read_csv(H / 'c_D2.csv')
Y1 = pd.read_csv(H / 'c_Y1.csv'); Y3 = pd.read_csv(H / 'c_Y3.csv')
hv = pd.read_csv(H / 'rwmop_hv.csv'); hvy = pd.read_csv(H / 'rwmop_hv_y.csv')
G1, G2, G3 = C2[C2.config == 'g15'], hv[hv.config == 'g15'], D2[D2.config == 'g15']
assert len(Y1) == 1080 and len(hvy) == 1050 and len(Y3) == 900 and len(G1) == 1080 and len(G2) == 1050 and len(G3) == 900

res = {}
res['Y1 WFG m=15,20 (IGD)'] = head2head(Y1, G1, 'IGDall', True, KEY3)
res['Y2 RWMOP (HV)'] = head2head(hvy, G2, 'HVnorm', False, ['prob'])
res['Y3 DTLZ (IGD, reported)'] = head2head(Y3, G3, 'IGDall', True, KEY3)
for m in (15, 20):
    res[f'   Y1, m={m}'] = head2head(Y1[Y1.M == m], G1[G1.M == m], 'IGDall', True, KEY3)
for m in (3, 6, 9):
    res[f'   Y3, m={m}'] = head2head(Y3[Y3.M == m], G3[G3.M == m], 'IGDall', True, KEY3)
pH = holm([res['Y1 WFG m=15,20 (IGD)']['p'], res['Y2 RWMOP (HV)']['p']])
print('X2 against g15 (+ = X2 better; ratio below 1 favours X2; 95% cluster-bootstrap interval over problems)')
for k, r in res.items():
    print(f"{k:<26} n={r['n']:>2}  +/-/= {r['wlt']:>8}  signed-rank p={r['p']:.3g} ({'X2' if r['better'] else 'g15'} ahead)  "
          f"ratio {r['ratio']:.3f} [{r['lo']:.3f}, {r['hi']:.3f}]")
y1, y2 = res['Y1 WFG m=15,20 (IGD)'], res['Y2 RWMOP (HV)']
c1 = y1['hi'] < 1.03 and y2['hi'] < 1.03
c2 = not ((pH[0] < 0.05 and not y1['better']) or (pH[1] < 0.05 and not y2['better']))
print(f"\nRule: (1) non-inferior on Y1 and Y2 (upper bounds {y1['hi']:.3f}, {y2['hi']:.3f} < 1.03): {c1}; "
      f"(2) significantly worse on neither (Holm p {pH[0]:.3g}, {pH[1]:.3g}): {c2}")
print('DECISION (pre-registered):', 'X2 REPLACES g15 as the final configuration' if (c1 and c2) else 'g15 remains the final configuration')
for k, r, ph in [('Y1', y1, pH[0]), ('Y2', y2, pH[1])]:
    sup = r['better'] and r['p'] < 0.05 and r['hi'] < 1
    print(f"   superiority over g15 may be claimed on {k}: {sup}")

print('\nPosition against the other algorithms (analysis of the article):')
MO2 = MO.copy(); RW2 = RW.copy(); DT2 = DT.copy()
y1o = Y1.assign(alg='OURS')[COLS]; y3o = Y3.assign(alg='OURS')[COLS]
y2o = hvy.assign(alg='OURS', M=0, D=0)[['alg', 'prob', 'M', 'D', 'run', 'HVnorm']]
for lab, base, X, val, lower, kr in [('WFG m=15,20', MO, y1o, 'IGDall', True, None), ('RWMOP', RW, y2o, 'HVnorm', False, None),
                                       ('DTLZ', DT, y3o, 'IGDall', True, lambda i: i[2] == 10)]:
    for who, XX in [('g15', None), ('X2', X)]:
        o = position(base, XX, val, lower, lab, kr)
        print(f"  {lab:<12} {who:<4} rank {o['rank']:5.2f}  position {o['pos']}/{o['n']}  sig. better than {len(o['better'])}"
              f"  sig. worse than {len(o['worse'])}{' (' + ', '.join(o['worse']) + ')' if o['worse'] else ''}  equal: {', '.join(o['equal'])}")
