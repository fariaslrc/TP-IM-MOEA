"""Phases T and U, analysed as pre-registered (TP-IM-MOEA/docs/phase_T_preregistration.md
and phase_U_preregistration.md), with the tests of the article (posthoc_c.py, make_tables_c.py):
Wilcoxon rank-sum per instance (5%), Wilcoxon signed-rank over the 54 instance means, Holm.

  T  each of the 19 variants against g15 (block C1); a variant qualifies if it is
     significantly better after Holm over the 19 and significantly worse (signed-rank,
     5%) in no group of m. Secondary: topology of the final map (f_T1 against g15i of
     f_F1) and time.
  U  checks (U0 equal to C1 g15 run by run; U3 in the direction of K1) and the
     comparisons C1 to C4 with Holm over the four. Secondary: the base-point log (u_U1).
"""
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.stats import ranksums, wilcoxon

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
KEY = ['prob', 'M', 'D']


def holm(p):
    p = np.asarray(p); o = np.argsort(p); k = len(p)
    adj = np.empty(k); run = 0.0
    for i, j in enumerate(o):
        run = max(run, min(1.0, (k - i) * p[j]))
        adj[j] = run
    return adj


def tag(x, y):
    """'+' if x is significantly better (lower IGD) than y, '-' if worse, '=' otherwise."""
    if np.allclose(x, x[0]) and np.allclose(y, y[0]) and np.isclose(x[0], y[0]): return '='
    if ranksums(x, y).pvalue >= 0.05: return '='
    return '+' if x.mean() < y.mean() else '-'


def a12(x, y):
    X, Y = np.asarray(x)[:, None], np.asarray(y)[None, :]
    return (X < Y).mean() + 0.5 * (X == Y).mean()


def signed(mx, my):
    """Two-sided signed-rank p over instance means and the direction: +1 if x is better."""
    d = my - mx                                   # > 0 where x has the lower IGD
    if np.allclose(d, 0): return 1.0, 0
    p = wilcoxon(mx, my).pvalue
    r = pd.Series(np.abs(d[d != 0])).rank().values
    rp, rn = r[d[d != 0] > 0].sum(), r[d[d != 0] < 0].sum()
    return p, (1 if rp > rn else -1)


def compare(X, Y):
    """X, Y: run-level frames (prob, M, D, run, IGDall). Returns the summary of X against Y."""
    gx = {k: g.IGDall.values for k, g in X.groupby(KEY)}
    gy = {k: g.IGDall.values for k, g in Y.groupby(KEY)}
    inst = sorted(set(gx) & set(gy))
    assert len(inst) == 54, len(inst)
    tags = {i: tag(gx[i], gy[i]) for i in inst}
    mx = np.array([gx[i].mean() for i in inst]); my = np.array([gy[i].mean() for i in inst])
    out = {'n': len(inst)}
    for lab, sel in [('all', lambda i: True)] + [(f'm{m}', (lambda mm: lambda i: i[1] == mm)(m)) for m in (3, 6, 9)]:
        ii = [k for k, i in enumerate(inst) if sel(i)]
        t = [tags[inst[k]] for k in ii]
        out[f'{lab}_wlt'] = f"{t.count('+')}/{t.count('-')}/{t.count('=')}"
        p, s = signed(mx[ii], my[ii])
        out[f'{lab}_p'] = p; out[f'{lab}_dir'] = s
    out['A12med'] = float(np.median([a12(gx[i], gy[i]) for i in inst]))
    out['gmRatio'] = float(np.exp(np.mean(np.log(mx / my))))   # geometric mean of IGD(X)/IGD(Y)
    return out


def fmt(p):
    return f'{p:.1e}' if p < 1e-3 else f'{p:.3f}'


def table(rows, ref):
    print(f"{'variant':<20} {'+/-/= all':>10} {'m=3':>8} {'m=6':>8} {'m=9':>8}  {'p':>8} {'pHolm':>8} dir  A12   IGD ratio  worse-m")
    for r in rows:
        worse = [m for m in (3, 6, 9) if r[f'm{m}_p'] < 0.05 and r[f'm{m}_dir'] < 0]
        print(f"{r['name']:<20} {r['all_wlt']:>10} {r['m3_wlt']:>8} {r['m6_wlt']:>8} {r['m9_wlt']:>8}  {fmt(r['all_p']):>8} "
              f"{fmt(r['pHolm']):>8} {'+' if r['all_dir'] > 0 else '-':>3}  {r['A12med']:.2f}  {r['gmRatio']:.3f}      "
              f"{','.join(map(str, worse)) or '-'}")
    print(f'(+ = the variant is better than {ref}; A12 = P(variant better); IGD ratio = geometric mean of the instance means, variant / {ref})')


C1 = pd.read_csv(H / 'c_C1.csv'); G15 = C1[C1.config == 'g15']
assert len(G15) == 1620

# ------------------------------------------------------------------ phase T
if (H / 'c_T1.csv').exists():
    T = pd.read_csv(H / 'c_T1.csv')
    order = ['A0B1', 'A0B2', 'A0B3', 'A1B0', 'A1B1', 'A1B2', 'A1B3', 'A2B0', 'A2B1', 'A2B2', 'A2B3',
             'A3B0', 'A3B1', 'A3B2', 'A3B3', 'R1_NeighborDE', 'R2_DecisionSOM', 'R3_DecisionSOM_B3', 'R4_GlobalEta']
    assert sorted(T.config.unique()) == sorted(order) and len(T) == 30780
    same_seed = T.merge(G15[KEY + ['run', 'seed']], on=KEY + ['run'], suffixes=('', '_g'))
    print(f'Phase T: {len(T)} runs, seeds equal to C1 g15 in {(same_seed.seed == same_seed.seed_g).mean():.0%} of them, '
          f'{(T.nRecorded == 300).mean():.0%} with 300 evaluations')
    rows = []
    for v in order:
        r = compare(T[T.config == v], G15); r['name'] = v; rows.append(r)
    for r, pa in zip(rows, holm([r['all_p'] for r in rows])): r['pHolm'] = pa
    print('\nStage 1 (WFG, N = 50, 300 evaluations), each variant against g15, Holm over the 19:')
    table(rows, 'g15')
    qual = [r for r in rows if r['pHolm'] < 0.05 and r['all_dir'] > 0 and
            not any(r[f'm{m}_p'] < 0.05 and r[f'm{m}_dir'] < 0 for m in (3, 6, 9))]
    print('\nQualified under the rule:', ', '.join(f"{r['name']} (pHolm {fmt(r['pHolm'])})" for r in qual) or 'none')
    sigworse = [r['name'] for r in rows if r['pHolm'] < 0.05 and r['all_dir'] < 0]
    print('Significantly worse than g15 after Holm:', ', '.join(sigworse) or 'none')

    # time relative to g15 run on the same PC in the same session (U0 of phase U); C1 ran elsewhere
    UT = pd.read_csv(H / 'c_U1.csv'); t0 = UT[UT.config == 'U0_Prototype'].runtime.mean()
    tm = T.groupby('config').runtime.mean().reindex(order) / t0
    print(f"\nWall time per run relative to g15 on the same PC (U0, {t0:.2f} s): " +
          ', '.join(f'{k} {v:.2f}' for k, v in tm.items()))

    FT, FF = H / 'f_T1.csv', H / 'f_F1.csv'
    if FT.exists() and FF.exists():
        ft = pd.read_csv(FT); ff = pd.read_csv(FF); ref = ff[ff.config == 'g15i']
        cols = [c for c in ['rhoTopo', 'overlap', 'overlapNull', 'ratio', 'nTrained'] if c in ft.columns]
        print('\nTopology of the final map (mean over runs; g15 = g15i of F1, same seeds):')
        print(f"{'config':<20} " + ' '.join(f'{c:>11}' for c in cols))
        print(f"{'g15':<20} " + ' '.join(f'{ref[c].mean():>11.3f}' for c in cols))
        for v in order:
            s = ft[ft.config == v]
            print(f"{v:<20} " + ' '.join(f'{s[c].mean():>11.3f}' for c in cols))
        for m in (3, 6, 9):
            print(f"  rhoTopo m={m}: g15 {ref[ref.M == m].rhoTopo.mean():.3f}; " +
                  ', '.join(f"{v} {ft[(ft.config == v) & (ft.M == m)].rhoTopo.mean():.3f}" for v in ['A1B0', 'A2B0', 'A3B0']))

# ------------------------------------------------------------------ phase U
U = pd.read_csv(H / 'c_U1.csv')
assert len(U) == 6480
u0 = U[U.config == 'U0_Prototype'].merge(G15[KEY + ['run', 'IGDall', 'seed']], on=KEY + ['run'], suffixes=('', '_g'))
print(f'\nPhase U: U0 equal to C1 g15 in {(u0.IGDall == u0.IGDall_g).sum()} of {len(u0)} runs '
      f'(max |diff| {np.abs(u0.IGDall - u0.IGDall_g).max():.1e}); seeds equal in {(u0.seed == u0.seed_g).mean():.0%}')
UU = {c: U[U.config == c] for c in U.config.unique()}
K1 = pd.read_csv(H / 'c_K1.csv')
print('\nChecks against the article:')
chk = [('U3_Parent vs g15', UU['U3_Parent'], G15), ('K1 noSOM vs g15 (article)', K1, G15)]
crow = []
for name, X, Y in chk:
    r = compare(X, Y); r['name'] = name; r['pHolm'] = r['all_p']; crow.append(r)
table(crow, 'g15')

comp = [('C1 U1 vs U3', 'U1_RegionMean', 'U3_Parent'), ('C2 U0 vs U1', 'U0_Prototype', 'U1_RegionMean'),
        ('C3 U2 vs U3', 'U2_RegionMember', 'U3_Parent'), ('C4 U1 vs U2', 'U1_RegionMean', 'U2_RegionMember')]
urows = []
for name, a, b in comp:
    r = compare(UU[a], UU[b]); r['name'] = name; urows.append(r)
for r, pa in zip(urows, holm([r['all_p'] for r in urows])): r['pHolm'] = pa
print('\nPre-registered comparisons (first named against second), Holm over the four:')
table(urows, 'the second')
extra = []
for name, a in [('U1 vs U0 (g15)', 'U1_RegionMean'), ('U2 vs U0 (g15)', 'U2_RegionMember')]:
    r = compare(UU[a], UU['U0_Prototype']); r['name'] = name; r['pHolm'] = r['all_p']; extra.append(r)
print('\nFor reference, against g15 (not part of the Holm family):')
table(extra, 'g15')

FU = H / 'u_U1.csv'
if FU.exists():
    L = pd.read_csv(FU)
    print('\nBase points (mean over runs of the per-generation means, evaluated candidates):')
    cols = ['ev_nMem', 'ev_alone', 'ev_dPP', 'ev_dPM', 'ev_dMP']
    print(L.groupby(['config', 'M'])[cols].mean().round(3).to_string())
    print('\nSame, over all candidates, U0 only, by m and d:')
    print(L[L.config == 'U0_Prototype'].groupby(['M', 'D'])[[c.replace('ev_', 'all_') for c in cols]].mean().round(3).to_string())
