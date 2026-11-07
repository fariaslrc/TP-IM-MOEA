"""Phases W and X, analysed as pre-registered (TP-IM-MOEA/docs/phase_W_preregistration.md and
phase_X_preregistration.md), with the tests of the article (rank-sum per instance, signed-rank over the
54 instance means, Holm) and, for X, cluster-bootstrap intervals over the nine WFG problems."""
from pathlib import Path
import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
exec(open(HERE / 'analyze_v.py', encoding='utf-8').read().split("C1 = pd.read_csv(H / 'c_C1.csv')")[0])

C1 = pd.read_csv(H / 'c_C1.csv'); G15 = C1[C1.config == 'g15']
T1 = pd.read_csv(H / 'c_T1.csv'); TT = {c: T1[T1.config == c] for c in T1.config.unique()}
V1 = pd.read_csv(H / 'c_V1.csv'); V0 = V1[V1.config == 'V0_DasDennis']

# ------------------------------------------------------------------ phase W
W = pd.read_csv(H / 'c_W1.csv'); assert len(W) == 12960
WW = {c: W[W.config == c] for c in W.config.unique()}
print(f"Phase W: {len(W)} runs, 300 evaluations in {(W.nRecorded == 300).mean():.0%}")
cand = ['W1_Fill', 'W2_Interp', 'W2p_InterpProx', 'W3_FillLocal', 'W4_InterpFillLocal']
rows = []
for v in cand:
    r = compare(WW[v], G15); r['name'] = v; rows.append(r)
for r, pa in zip(rows, holm([r['all_p'] for r in rows])): r['pHolm'] = pa
print('\nStage 1, candidates against g15, Holm over the five:')
table(rows, 'g15')
qual = [r['name'] for r in rows if r['pHolm'] < 0.05 and r['all_dir'] > 0 and
        not any(r[f'm{m}_p'] < 0.05 and r[f'm{m}_dir'] < 0 for m in (3, 6, 9))]
print('Qualified:', ', '.join(qual) or 'none')
print('\nAttribution to the topology (signed-rank, 5%):')
att = []
for name, a, b in [('W1 vs W1s', 'W1_Fill', 'W1s_FillShuf'), ('W2 vs W2s', 'W2_Interp', 'W2s_InterpShuf'),
                   ('W3 vs W3s', 'W3_FillLocal', 'W3s_FillLocalShuf'), ('W2 vs W2p (lattice vs proximity)', 'W2_Interp', 'W2p_InterpProx'),
                   ('W4 vs W2', 'W4_InterpFillLocal', 'W2_Interp'), ('W4 vs W3', 'W4_InterpFillLocal', 'W3_FillLocal')]:
    r = compare(WW[a], WW[b]); r['name'] = name; r['pHolm'] = r['all_p']; att.append(r)
table(att, 'the second')
print('\nControls against g15 (for reference):')
ctl = []
for v in ['W1s_FillShuf', 'W2s_InterpShuf', 'W3s_FillLocalShuf']:
    r = compare(WW[v], G15); r['name'] = v; r['pHolm'] = r['all_p']; ctl.append(r)
table(ctl, 'g15')
print('\nEffect sizes against g15, 95% cluster-bootstrap intervals (for information):')
for v in cand:
    cells = [ratio_ci(WW[v], G15, s) for s in [None, lambda d: d.M == 3, lambda d: d.M == 6, lambda d: d.M == 9]]
    print(f'  {v:<20} ' + ' | '.join(f'{k} {e:.3f} [{lo:.3f}, {hi:.3f}]' for k, (e, lo, hi) in zip(['all', 'm3', 'm6', 'm9'], cells)))

# ------------------------------------------------------------------ phase X
X = pd.read_csv(H / 'c_X1.csv'); assert len(X) == 6480
XX = {c: X[X.config == c] for c in X.config.unique()}
x1 = XX['X1_TPN']
print(f"\n\nPhase X: {len(X)} runs, 300 evaluations in {(X.nRecorded == 300).mean():.0%}; "
      f"seeds equal to C1 g15: {(x1.merge(G15[KEY + ['run', 'seed']], on=KEY + ['run'], suffixes=('', '_g')).pipe(lambda d: (d.seed == d.seed_g).mean())):.0%}")
r = compare(x1, G15); r['name'] = 'X1_TPN vs g15'; r['pHolm'] = r['all_p']
print('\nPrimary comparison:')
table([r], 'g15')
ci = {k: ratio_ci(x1, G15, s) for k, s in [('all', None), ('m3', lambda d: d.M == 3), ('m6', lambda d: d.M == 6), ('m9', lambda d: d.M == 9)]}
print('IGD ratio X1/g15 with 95% cluster-bootstrap intervals: ' + ' | '.join(f'{k} {e:.3f} [{lo:.3f}, {hi:.3f}]' for k, (e, lo, hi) in ci.items()))
c1 = r['all_p'] < 0.05 and r['all_dir'] > 0
c2 = ci['all'][0] <= 0.98 and ci['all'][2] < 1.0
c3 = all(ci[k][2] < 1.03 for k in ['m3', 'm6', 'm9'])
nonInf = ci['all'][2] < 1.03 and c3
print(f'Superior: (1) significantly better {c1}; (2) ratio <= 0.98 with upper bound < 1 {c2}; '
      f'(3) every m upper bound < 1.03 {c3}  ->  {"SUPERIOR" if (c1 and c2 and c3) else "not superior"}')
print(f'Non-inferior (upper bound < 1.03 overall and in every m): {nonInf}')
att = []
for name, b in [('X1 vs X2 (no ordering)', 'X2_TPN_noOrd'), ('X1 vs X3 (shuffled graph)', 'X3_TPN_shuf'), ('X1 vs X4 (proximity, codebook)', 'X4_Prox')]:
    q = compare(x1, XX[b]); q['name'] = name; att.append(q)
for q, pa in zip(att, holm([q['all_p'] for q in att])): q['pHolm'] = pa
print('\nAttribution, Holm over the three:')
table(att, 'the control')
necessary = all(q['pHolm'] < 0.05 and q['all_dir'] > 0 for q in att)
print(f'Topology necessary (X1 significantly better than X2, X3 and X4): {necessary}')
if c1 and c2 and c3 and necessary: dec = 'TPN superior and topology necessary: TPN replaces g15, subject to confirmation'
elif nonInf and necessary: dec = 'TPN non-inferior and topology necessary: TPN may replace g15, subject to confirmation'
else: dec = 'g15 remains the final configuration; phase X is reported as the test of the topological read-out'
print('DECISION (pre-registered):', dec)

print('\nSecondary, X1 against the phase T variants with the same seeds and against its controls vs g15:')
sec = []
for name, Y in [('X1 vs A2B1 (random neighbours)', TT['A2B1']), ('X1 vs A2B0 (ordering only)', TT['A2B0'])]:
    q = compare(x1, Y); q['name'] = name; q['pHolm'] = q['all_p']; sec.append(q)
for v in ['X2_TPN_noOrd', 'X3_TPN_shuf', 'X4_Prox']:
    q = compare(XX[v], G15); q['name'] = f'{v} vs g15'; q['pHolm'] = q['all_p']; sec.append(q)
table(sec, 'the second')
for d in (10, 100):
    gx = {k: g.IGDall.values for k, g in x1[x1.D == d].groupby(KEY)}; gy = {k: g.IGDall.values for k, g in G15[G15.D == d].groupby(KEY)}
    print(f'  X1 vs g15 at d={d}: ' + '  '.join(f"m={m} " + (lambda t: f"{t.count('+')}/{t.count('-')}/{t.count('=')}")([tag(gx[i], gy[i]) for i in sorted(gx) if i[1] == m]) for m in (3, 6, 9)))

L = pd.read_csv(H / 'x_X1.csv')
print('\nMechanism (evaluated candidates, mean over runs): residual of the convex fit, weight on the neighbours, nodes besides j')
print(L.groupby(['config', 'M'])[['ev_resid', 'ev_wNb', 'ev_nCell']].mean().round(3).to_string())
F = pd.read_csv(H / 'f_X1.csv'); FF = pd.read_csv(H / 'f_F1.csv'); g15i = FF[FF.config == 'g15i']
print('\nTopology of the final map (rho; g15 = g15i of F1, same seeds):')
print(pd.concat([g15i.assign(config='g15'), F]).groupby(['config', 'M']).rhoTopo.mean().unstack().round(3).to_string())
t0 = V0.runtime.mean()
print('\nWall time relative to V0 (CASA): ' + ', '.join(f'{c} {XX[c].runtime.mean() / t0:.2f}' for c in XX) +
      ' | ' + ', '.join(f'{c} {WW[c].runtime.mean() / t0:.2f}' for c in cand))
