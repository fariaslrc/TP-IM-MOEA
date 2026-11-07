"""Numbers quoted in Section V for the final model (phase AC). Read-only; reuses the data assembly of
make_tables_c.py (FINAL = True)."""
from pathlib import Path
import numpy as np, pandas as pd
HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
src = open(HERE / 'make_tables_c.py', encoding='utf-8').read().split('# ---------------------------------------------------------------- helpers')[0]
exec(src)
from scipy.stats import ranksums

def tag(x, y, lower=True):
    if np.allclose(x, x[0]) and np.allclose(y, y[0]) and np.isclose(x[0], y[0]): return '='
    if ranksums(x, y).pvalue >= 0.05: return '='
    return '+' if ((x.mean() < y.mean()) if lower else (x.mean() > y.mean())) else '-'
def wlt(t): return f"{t.count('+')}/{t.count('-')}/{t.count('=')}"
CW = {k: g.IGDall.values for k, g in WFG.groupby(['alg', 'prob', 'M', 'D'])}
inst54 = [(f'WFG{p}', m, d) for d in (10, 100) for m in (3, 6, 9) for p in range(1, 10)]
print('V-A reductions (mean over instances of 1 - ours/other):')
for a in ['IMMOEAD', 'IMCMOEAD', 'SSDE']:
    r = np.array([1 - CW[('OURS',) + i].mean() / CW[(a,) + i].mean() for i in inst54])
    w3 = [1 - CW[('OURS',) + i].mean() / CW[(a,) + i].mean() for i in inst54 if i[0] == 'WFG3']
    print(f'  {a}: mean {r.mean()*100:.0f}%  WFG3 range {min(w3)*100:.0f}-{max(w3)*100:.0f}%  max {r.max()*100:.0f}% at {inst54[int(r.argmax())]}')
print('V-B per-problem wins of PIEA and EGES (rival better):')
for a in ['PIEA', 'EGES']:
    t = {i: tag(CW[(a,) + i], CW[('OURS',) + i]) for i in inst54}
    byp = {f'WFG{p}': wlt([t[i] for i in inst54 if i[0] == f'WFG{p}']) for p in range(1, 10)}
    bym = {m: wlt([t[i] for i in inst54 if i[1] == m]) for m in (3, 6, 9)}
    print(f'  {a}: by m {bym}; by problem {byp}')
CD = {k: g.IGDall.values for k, g in DT.groupby(['alg', 'prob', 'M', 'D'])}
inst30 = [(p, m, d) for d in (10, 100) for m in (3, 6, 9) for p in ['DTLZ1', 'DTLZ2', 'DTLZ3', 'DTLZ4', 'DTLZ7']]
print('V-C DTLZ tags (rival vs ours) by d:')
for a in ['EGES', 'SFADE', 'MCEAD', 'REMO', 'PIEA', 'KRVEA', 'SSDE', 'IMMOEAD', 'IMCMOEAD']:
    print(f'  {a}: ' + ' '.join(f"d{d} {wlt([tag(CD[(a,) + i], CD[('OURS',) + i]) for i in inst30 if i[2] == d and (a,) + i in CD])}" for d in (10, 100)))
CR = {k: g.HV.values for k, g in RW.groupby(['alg', 'prob'])}
probs = sorted(RW.prob.unique(), key=lambda s: int(s[5:]))
print('V-D RWMOP: losses of ours (rival better):')
for a in ['IMMOEAD', 'IMCMOEAD', 'SSDE', 'CTAEA', 'RVEA']:
    print(f"  {a}: " + ', '.join(p for p in probs if tag(CR[(a, p)], CR[('OURS', p)], False) == '+'))
o = RW[RW.alg == 'OURS'].groupby('prob').HV
print(f"  ours HV>0 on {(o.max() > 0).sum()} problems, in every run on {(o.min() > 0).sum()}")
for a, g in FEAS.groupby('config'):
    fr = g.groupby('prob').finalFeasible.mean()
    print(f"  {a}: final set feasible in some run on {(fr > 0).sum()} problems, in every run on {(fr == 1).sum()}")
best = {p: max(CR[(a, p)].mean() for a in ['OURS', 'IMMOEAD', 'IMCMOEAD', 'SSDE', 'CTAEA', 'RVEA']) for p in probs}
print('  problems where some algorithm has HV>0:', sum(v > 0 for v in best.values()))
CM = {k: g.IGDall.values for k, g in MO.groupby(['alg', 'prob', 'M', 'D'])}
instMO = sorted({k[1:] for k in CM if k[0] == 'OURS'})
print('V-G many objectives (rival vs ours):')
for a in ['RVEA', 'PIEA', 'SSDE', 'EGES']:
    print(f"  {a}: {wlt([tag(CM[(a,) + i], CM[('OURS',) + i]) for i in instMO])}")
