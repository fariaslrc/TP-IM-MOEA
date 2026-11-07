"""Phase V, analysed as pre-registered (TP-IM-MOEA/docs/phase_V_preregistration.md), with the
tests of the article (rank-sum per instance, signed-rank over the 54 instance means, Holm).

  Check     V0 equal to C1 g15 run by run.
  Stage 1   V1 to V4 against g15, Holm over the four; a variant qualifies if it is significantly
            better after Holm and significantly worse (signed-rank, 5%) in no group of m.
  Secondary H2 (V1 vs V2, V3 vs V4), H3 (V1 vs V3, V2 vs V4), groups of m; topology of the final
            map, fraction of nodes trained, time relative to V0.
  Not part of the rule of phase V: the effect sizes with cluster-bootstrap intervals over the nine
  WFG problems, the standard adopted from phase X on, reported for information.
"""
from pathlib import Path
import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
src = open(HERE / 'analyze_tu.py', encoding='utf-8').read().split("C1 = pd.read_csv")[0]
exec(src)                                     # holm, tag, a12, signed, compare, fmt, table, KEY


def ratio_ci(X, Y, sel=None, B=10000, seed=1):
    """Geometric mean of the ratio of instance means X/Y and its 95% cluster-bootstrap interval,
    resampling the WFG problems."""
    mx = X.groupby(KEY).IGDall.mean(); my = Y.groupby(KEY).IGDall.mean()
    d = np.log(mx / my).rename('lr').reset_index()
    if sel is not None: d = d[sel(d)]
    probs = sorted(d.prob.unique()); by = {p: d[d.prob == p].lr.values for p in probs}
    rng = np.random.default_rng(seed); est = np.exp(d.lr.mean()); bs = np.empty(B)
    for b in range(B):
        pick = rng.choice(probs, len(probs), replace=True)
        bs[b] = np.mean(np.concatenate([by[p] for p in pick]))
    lo, hi = np.exp(np.percentile(bs, [2.5, 97.5]))
    return est, lo, hi


C1 = pd.read_csv(H / 'c_C1.csv'); G15 = C1[C1.config == 'g15']
V = pd.read_csv(H / 'c_V1.csv')
order = ['V1_URmap', 'V2_URall', 'V3_URDmap', 'V4_URDall']
assert len(V) == 8100 and sorted(V.config.unique()) == sorted(['V0_DasDennis'] + order)
VV = {c: V[V.config == c] for c in V.config.unique()}

v0 = VV['V0_DasDennis'].merge(G15[KEY + ['run', 'IGDall', 'seed']], on=KEY + ['run'], suffixes=('', '_g'))
print(f"Check: V0 equal to C1 g15 in {(v0.IGDall == v0.IGDall_g).sum()} of {len(v0)} runs "
      f"(max |diff| {np.abs(v0.IGDall - v0.IGDall_g).max():.1e}); seeds equal in {(v0.seed == v0.seed_g).mean():.0%}; "
      f"300 evaluations in {(V.nRecorded == 300).mean():.0%} of the runs")

rows = []
for v in order:
    r = compare(VV[v], G15); r['name'] = v; rows.append(r)
for r, pa in zip(rows, holm([r['all_p'] for r in rows])): r['pHolm'] = pa
print('\nStage 1 (WFG, N = 50, 300 evaluations), each variant against g15, Holm over the four:')
table(rows, 'g15')
qual = [r for r in rows if r['pHolm'] < 0.05 and r['all_dir'] > 0 and
        not any(r[f'm{m}_p'] < 0.05 and r[f'm{m}_dir'] < 0 for m in (3, 6, 9))]
print('\nQualified under the rule:', ', '.join(f"{r['name']} (pHolm {fmt(r['pHolm'])})" for r in qual) or 'none')
print('Significantly worse than g15 after Holm:',
      ', '.join(r['name'] for r in rows if r['pHolm'] < 0.05 and r['all_dir'] < 0) or 'none')

print('\nSecondary comparisons (no decision):')
sec = []
for name, a, b in [('H2 V1 map vs V2 all', 'V1_URmap', 'V2_URall'), ('H2 V3 map vs V4 all', 'V3_URDmap', 'V4_URDall'),
                   ('H3 V1 unif vs V3 Dir', 'V1_URmap', 'V3_URDmap'), ('H3 V2 unif vs V4 Dir', 'V2_URall', 'V4_URDall')]:
    r = compare(VV[a], VV[b]); r['name'] = name; r['pHolm'] = r['all_p']; sec.append(r)
table(sec, 'the second')

print('\nEffect sizes against g15, 95% cluster-bootstrap intervals over the nine problems (for information):')
print(f"{'variant':<12} {'all':>22} {'m=3':>22} {'m=6':>22} {'m=9':>22}")
for v in order:
    cells = []
    for sel in [None, lambda d: d.M == 3, lambda d: d.M == 6, lambda d: d.M == 9]:
        e, lo, hi = ratio_ci(VV[v], G15, sel); cells.append(f'{e:.3f} [{lo:.3f}, {hi:.3f}]')
    print(f'{v:<12} ' + ' '.join(f'{c:>22}' for c in cells))
print('  (ratio of IGD, variant / g15; below 1 is better)')

for d in (10, 100):
    print(f'\nBy m at d = {d}: better/worse/similar against g15 per instance')
    for v in order:
        X = VV[v][VV[v].D == d]; Y = G15[G15.D == d]
        gx = {k: g.IGDall.values for k, g in X.groupby(KEY)}; gy = {k: g.IGDall.values for k, g in Y.groupby(KEY)}
        parts = []
        for m in (3, 6, 9):
            t = [tag(gx[i], gy[i]) for i in sorted(gx) if i[1] == m]
            parts.append(f"m={m} {t.count('+')}/{t.count('-')}/{t.count('=')}")
        print(f'  {v:<12} ' + '  '.join(parts))

FV = H / 'f_V1.csv'
if FV.exists():
    f = pd.read_csv(FV)
    nodes = {('V0_DasDennis', 3): 45, ('V0_DasDennis', 6): 42, ('V0_DasDennis', 9): 45}
    f['nodes'] = [nodes.get((c, m), 50) for c, m in zip(f.config, f.M)]
    f['fracTrained'] = f.nTrained / f['nodes']
    f['overlapGain'] = f.overlap - f.overlapNull
    print('\nFinal map (mean over runs), by m:')
    print(f.groupby(['config', 'M'])[['nodes', 'nTrained', 'fracTrained', 'rhoTopo', 'overlapGain', 'ratio']].mean().round(3).to_string())

t0 = VV['V0_DasDennis'].runtime.mean()
print('\nWall time per run relative to V0 (same PC): ' +
      ', '.join(f'{v} {VV[v].runtime.mean() / t0:.2f}' for v in order) + f' (V0 {t0:.2f} s)')
