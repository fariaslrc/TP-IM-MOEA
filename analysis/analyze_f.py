"""Phase F, block F1: shuffled anchors, map topology and prescreening accuracy.
  1. reproduction: g15i (anchorShuf = 0, instrumented, same seeds) against g15 of C1
  2. performance of anchorShuf = 0.25, 0.5, 1 against 0 (Wilcoxon rank-sum, 5%)
  3. topology of the final map (f_F1.csv, export_f.m)
  4. prescreening accuracy on all candidates
Usage: python analyze_f.py"""
from pathlib import Path
import numpy as np, pandas as pd
from scipy.stats import ranksums, friedmanchisquare, wilcoxon

H = Path(__file__).resolve().parent.parent / 'results'     # per-run results
F = pd.read_csv(H / 'c_F1.csv')
T = pd.read_csv(H / 'f_F1.csv')
C1 = pd.read_csv(H / 'c_C1.csv'); C1 = C1[C1.config == 'g15']
k = ['prob', 'M', 'D', 'run']

m = F[F.config == 'g15i'].merge(C1[k + ['IGDall']], on=k, suffixes=('', '_c1'))
print(f"1. reproduction: {np.isclose(m.IGDall, m.IGDall_c1, rtol=1e-12, atol=0).sum()} of {len(m)} g15i runs identical to C1")


def tag(x, y):
    if ranksums(x, y).pvalue >= 0.05: return '='
    return '+' if x.mean() < y.mean() else '-'


G = {kk: g.IGDall.values for kk, g in F.groupby(['config', 'prob', 'M', 'D'])}
inst = sorted({kk[1:] for kk in G if kk[0] == 'g15i'})
print('\n2. shuffled anchors against the correct anchors (+/-/= of the shuffled variant)')
for c in ['a025', 'a050', 'a100']:
    by = {mm: [tag(G[(c,) + i], G[('g15i',) + i]) for i in inst if i[1] == mm] for mm in (3, 6, 9)}
    allt = sum(by.values(), [])
    ratio = np.mean([G[(c,) + i].mean() / G[('g15i',) + i].mean() for i in inst])
    print(f"  {c}: all {allt.count('+')}/{allt.count('-')}/{allt.count('=')}  "
          + '  '.join(f"m{mm} {v.count('+')}/{v.count('-')}/{v.count('=')}" for mm, v in by.items())
          + f"  mean IGD ratio {ratio:.3f}")
cfgs = ['g15i', 'a025', 'a050', 'a100']
Mx = np.array([[G[(c,) + i].mean() for c in cfgs] for i in inst])
rk = pd.DataFrame(Mx).rank(axis=1).mean().values
print('  Friedman ranks:', dict(zip(cfgs, rk.round(2))), f'p={friedmanchisquare(*Mx.T).pvalue:.1e}')
for j, c in enumerate(cfgs[1:], 1):
    print(f'  signed-rank {c} vs g15i over instances: p={wilcoxon(Mx[:, 0], Mx[:, j]).pvalue:.1e}')

print('\n3. topology of the final map (means over runs)')
cols = ['nTrained', 'rhoTopo', 'overlap', 'overlapNull', 'ratio']
print(T.groupby(['config', 'M'])[cols].mean().round(3).to_string())
print('  share of g15i runs with rhoTopo > 0:', (T[T.config == 'g15i'].rhoTopo > 0).mean().round(3),
      ' a100:', (T[T.config == 'a100'].rhoTopo > 0).mean().round(3))
print('  by problem (g15i, rhoTopo):', T[T.config == 'g15i'].groupby('prob').rhoTopo.mean().round(3).to_dict())

print('\n4. prescreening accuracy of g15i (means over runs of the means over generations)')
P = T[T.config == 'g15i']
print(P.groupby('M')[['preRho', 'prec', 'precRand', 'impSel', 'impAll']].mean().round(3).to_string())
print(P.groupby('D')[['preRho', 'prec', 'precRand', 'impSel', 'impAll']].mean().round(3).to_string())
print('  overall:', P[['preRho', 'prec', 'precRand', 'impSel', 'impAll']].mean().round(3).to_dict())
print('  share of runs with prec > precRand:', (P.prec > P.precRand).mean().round(3),
      ' impSel > impAll:', (P.impSel > P.impAll).mean().round(3))
