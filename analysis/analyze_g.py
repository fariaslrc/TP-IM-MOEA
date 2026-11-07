"""Numbers of Section V-E that come from phases F and G and are not in a table.
  1. WFG topology of the final map with the correct anchors (F1, g15i):
     rho mean, interquartile range and share of positive runs, overlap
     against its random value, ratio of adjacent to nonadjacent distances
  2. Prescreening controls (G1): uniformly random (r1) and niche-stratified
     random (r2) selection of the B evaluated candidates, against TP-IM-MOEA
     (C1) and against no prescreening (C3, q04_noPre); Friedman ranks
  3. Held-out DTLZ topology (G2): the same measures, and IGD of the fully
     permuted anchors (a100) against the correct ones (g15i)
Wilcoxon rank-sum at 5%; +/-/= is the first configuration relative to the second.
Usage: python analyze_g.py"""
from pathlib import Path
import numpy as np, pandas as pd
from scipy.stats import ranksums, friedmanchisquare

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
def tag(x, y):
    if ranksums(x, y).pvalue >= 0.05: return '='
    return '+' if x.mean() < y.mean() else '-'


def wlt(t):
    return f"{t.count('+')}/{t.count('-')}/{t.count('=')}"


def compare(A, B):
    """+/-/= of A against B over their common instances; A, B: {(prob, M, D): IGD values}."""
    return wlt([tag(A[i], B[i]) for i in sorted(set(A) & set(B))])


def igd(T):
    return {k: g.IGDall.values for k, g in T.groupby(['prob', 'M', 'D'])}


def topology(T, label):
    q = T.rhoTopo.quantile([0.25, 0.75]).values
    print(f'  {label}: rho {T.rhoTopo.mean():.2f} (IQR {q[0]:.2f} to {q[1]:.2f}, positive in {100 * (T.rhoTopo > 0).mean():.1f}% of runs), '
          f'overlap {T.overlap.mean():.2f} against {T.overlapNull.mean():.2f} for a random map, ratio {T.ratio.mean():.2f}; '
          f'prescreening rho {T.preRho.mean():.2f}, precision {T.prec.mean():.2f} against {T.precRand.mean():.2f}')


print('1. WFG topology, correct anchors (F1)')
F = pd.read_csv(H / 'f_F1.csv')
topology(F[F.config == 'g15i'], 'g15i')
topology(F[F.config == 'a100'], 'a100')

print('\n2. Prescreening controls (G1)')
C1 = pd.read_csv(H / 'c_C1.csv'); C3 = pd.read_csv(H / 'c_C3.csv'); G1 = pd.read_csv(H / 'c_G1.csv')
S = {'ours': igd(C1[C1.config == 'g15']), 'noPS': igd(C3[C3.config == 'q04_noPre']),
     'r1': igd(G1[G1.config == 'r1']), 'r2': igd(G1[G1.config == 'r2'])}
for a, b in [('r1', 'ours'), ('r2', 'ours'), ('r1', 'noPS'), ('r2', 'r1'), ('noPS', 'ours')]:
    print(f'  {a} vs {b}: {compare(S[a], S[b])}')
inst = sorted(set.intersection(*(set(v) for v in S.values())))
means = np.array([[S[a][i].mean() for a in S] for i in inst])
ranks = pd.DataFrame(means).rank(axis=1).mean().values
print(f'  Friedman ranks over {len(inst)} instances: ' + ', '.join(f'{a} {r:.2f}' for a, r in zip(S, ranks)) +
      f'  p={friedmanchisquare(*means.T).pvalue:.1e}')

print('\n3. Held-out DTLZ topology (G2)')
G2 = pd.read_csv(H / 'c_G2.csv'); T2 = pd.read_csv(H / 'f_G2.csv')
D2 = pd.read_csv(H / 'c_D2.csv')
k = ['prob', 'M', 'D', 'run']
m = G2[G2.config == 'g15i'].merge(D2[D2.config == 'g15'][k + ['IGDall']], on=k, suffixes=('', '_d2'))
print(f"  reproduction: {np.isclose(m.IGDall, m.IGDall_d2, rtol=1e-12, atol=0).sum()} of {len(m)} g15i runs identical to D2")
topology(T2[T2.config == 'g15i'], 'g15i')
topology(T2[T2.config == 'a100'], 'a100')
print(f"  a100 vs g15i (IGD): {compare(igd(G2[G2.config == 'a100']), igd(G2[G2.config == 'g15i']))}")
