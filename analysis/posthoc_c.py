"""Post-hoc analysis with TP-IM-MOEA as the control (Table S16).

For each scenario (WFG, DTLZ, many objectives, RWMOP): Friedman mean ranks
on the mean indicator values; Wilcoxon signed-rank test over the instances
between TP-IM-MOEA and each algorithm on the same means, with Holm's
correction over the algorithms of the scenario; and the Vargha-Delaney A12
effect size per instance, A12 = P(TP-IM-MOEA better) + P(tie)/2 over all
pairs of runs, summarized by its median over the instances and by the
number of instances with a large effect in either direction (A12 >= 0.71 or
A12 <= 0.29). K-RVEA is compared on the instances with d = 10.
Data and scoring rules as in make_tables_c.py.
Usage: python posthoc_c.py"""
from pathlib import Path
import numpy as np, pandas as pd
from scipy.stats import wilcoxon, friedmanchisquare

H = Path(__file__).resolve().parent.parent / 'results'     # per-run results
TAB = Path(__file__).resolve().parent / 'tables'
TAB.mkdir(exist_ok=True)
NAMES = {'OURS': 'TP-IM-MOEA', 'IMMOEAD': 'IM-MOEA/D', 'IMCMOEAD': 'IM-C-MOEA/D', 'SSDE': 'SSDE', 'EGES': 'EGES',
         'KRVEA': 'K-RVEA', 'RVEA': 'RVEA', 'MCEAD': 'MCEA/D', 'AVGSAEA': 'AVG-SAEA', 'CPSMOEA': 'CPS-MOEA',
         'SVRNSGAII': 'SVR-NSGA-II', 'CSEA': 'CSEA', 'REMO': 'REMO', 'ADSAPSO': 'ADSAPSO', 'SFADE': 'SFA-DE',
         'PIEA': 'PIEA', 'CTAEA': 'CTAEA'}


def c(name):
    d = pd.read_csv(H / f'c_{name}.csv')
    d['alg'] = d.config.replace({'g15': 'OURS'})
    return d


def have(name):
    return (H / f'c_{name}.csv').exists()


COLS = ['alg', 'prob', 'M', 'D', 'run', 'IGDall']
old = pd.read_csv(H / 'rescore_old.csv')
old = old[(old.run <= 30) & (old.type == 'arch')].rename(columns={'IGDrep': 'IGDall'})
if have('D5'):
    old = old[old.alg != 'EGES']
if (H / 'rescore_remo.csv').exists():
    r = pd.read_csv(H / 'rescore_remo.csv').rename(columns={'IGDrep': 'IGDall'})
    old = pd.concat([old, r[r.run <= 30]])
WFG = pd.concat([c('C1')[COLS], old[COLS]] + ([c('D5')[COLS]] if have('D5') else []), ignore_index=True)
MO = pd.concat([c('C2')[COLS], c('C7').assign(alg='PIEA')[COLS], c('D3').assign(alg='EGES')[COLS]], ignore_index=True)
# CSEA, DTLZ4, m = 3, d = 100, runs 9 and 14 stop with an error: scored on the evaluations before it (G3);
# until G3 arrives, the runs with new seeds of phase E stand in for them
e2 = (c('G3').query("alg == 'CSEA'") if have('G3') else
      c('E2').query('run in [31, 32]').assign(run=lambda d: d.run.map({31: 9, 32: 14})))
DT = pd.concat([c('D2')[COLS], e2[COLS]] + ([c('D4').assign(alg='REMO')[COLS]] if have('D4') else []), ignore_index=True)
hv = pd.read_csv(H / 'rwmop_hv.csv')
hv['alg'] = hv.config.replace({'g15': 'OURS'})
RW = hv[hv.alg.isin(['OURS', 'IMMOEAD', 'IMCMOEAD', 'SSDE', 'CTAEA', 'RVEA'])]
full = pd.MultiIndex.from_product([RW.alg.unique(), RW.prob.unique(), range(1, 31)], names=['alg', 'prob', 'run'])
miss = full.difference(pd.MultiIndex.from_frame(RW[['alg', 'prob', 'run']])).to_frame(index=False).assign(HVnorm=0.0)
RW = pd.concat([RW, miss], ignore_index=True).assign(M=0, D=0)


def a12(x, y, lower):
    """P(x better than y) + P(tie)/2 over all pairs of runs."""
    X, Y = np.asarray(x)[:, None], np.asarray(y)[None, :]
    better = (X < Y) if lower else (X > Y)
    return better.mean() + 0.5 * (X == Y).mean()


def holm(p):
    p = np.asarray(p); o = np.argsort(p); k = len(p)
    adj = np.empty(k); run = 0.0
    for i, j in enumerate(o):
        run = max(run, min(1.0, (k - i) * p[j]))
        adj[j] = run
    return adj


def scenario(T, val, lower, label, kr_inst=None):
    G = {k: g[val].values for k, g in T.groupby(['alg', 'prob', 'M', 'D'])}
    inst = sorted({k[1:] for k in G if k[0] == 'OURS'})
    algs = [a for a in T.alg.unique() if a != 'OURS' and all((a,) + i in G for i in inst)]
    sgn = 1 if lower else -1
    Mx = np.array([[sgn * G[(a,) + i].mean() for a in ['OURS'] + algs] for i in inst])
    rk = dict(zip(['OURS'] + algs, pd.DataFrame(Mx).rank(axis=1).mean().values))
    p = [wilcoxon(Mx[:, 0], Mx[:, j + 1]).pvalue for j in range(len(algs))]
    rows = [(label, 'OURS', rk['OURS'], np.nan, np.nan, '', len(inst))]
    for a, pa, pad in zip(algs, p, holm(p)):
        A = np.array([a12(G[('OURS',) + i], G[(a,) + i], lower) for i in inst])
        rows.append((label, a, rk[a], pad, np.median(A), f'{(A >= 0.71).sum()}/{(A <= 0.29).sum()}', len(inst)))
    if kr_inst is not None and any(k[0] == 'KRVEA' for k in G):
        inst2 = [i for i in inst if kr_inst(i)]
        x = np.array([sgn * G[('OURS',) + i].mean() for i in inst2]); y = np.array([sgn * G[('KRVEA',) + i].mean() for i in inst2])
        A = np.array([a12(G[('OURS',) + i], G[('KRVEA',) + i], lower) for i in inst2])
        rows.append((label, 'KRVEA', np.nan, wilcoxon(x, y).pvalue, np.median(A), f'{(A >= 0.71).sum()}/{(A <= 0.29).sum()}', len(inst2)))
    print(f'{label}: Friedman p={friedmanchisquare(*Mx.T).pvalue:.1e}, {len(inst)} instances, {len(algs) + 1} algorithms')
    return rows


ABL = pd.concat([c('C3')[COLS], c('C1').query("alg == 'OURS'")[COLS]], ignore_index=True)
if have('K1'):            # noSOM with topo = 4 (phase K): only the base point of reproduction differs from g15
    ABL = pd.concat([ABL[ABL.alg != 'q06_noSOM'], c('K1').assign(alg='q06_noSOM')[COLS]], ignore_index=True)
NAMES.update({'q01_noRefMap': 'noRM', 'q02_noInfillD': 'noIF', 'q03_noSelRef': 'noRS', 'q04_noPre': 'noPS', 'q05_noCheap': 'noLD',
              'q06_noSOM': 'noSOM', 'q07_withNbh': 'NB', 'q08_withNbh_shuf': 'NB-sh',
              'a025': 'anchors 25\\%', 'a050': 'anchors 50\\%', 'a100': 'anchors 100\\%', 'r1': 'random selection', 'r2': 'stratified random'})
R = (scenario(WFG, 'IGDall', True, 'WFG', lambda i: i[2] == 10) + scenario(DT, 'IGDall', True, 'DTLZ', lambda i: i[2] == 10)
     + scenario(MO, 'IGDall', True, 'WFG, $m\\in\\{15,20\\}$') + scenario(RW, 'HVnorm', False, 'RWMOP')
     + scenario(ABL, 'IGDall', True, 'Ablation (WFG)'))
if have('F1'):
    F1 = c('F1').assign(alg=lambda d: d.config.replace({'g15i': 'OURS'}))
    if have('G1'):
        F1 = pd.concat([F1, c('G1')], ignore_index=True)
    R += scenario(F1[COLS], 'IGDall', True, 'Anchors and selection (WFG)')
D = pd.DataFrame(R, columns=['scenario', 'alg', 'rank', 'pHolm', 'A12', 'large', 'n'])
print(D.to_string(index=False))


def fp(p):
    if not np.isfinite(p): return '---'
    if p < 1e-3:
        e = int(np.floor(np.log10(p))); m = p / 10**e
        return f'${m:.1f}\\times10^{{{e}}}$'
    return f'{p:.3f}'


L = ['\\providecommand{\\ours}{TP-IM-MOEA}', '\\begin{table*}[htbp]', '\\centering', '\\renewcommand{\\arraystretch}{1.05}',
     '\\caption{Post-Hoc Analysis With \\ours{} as the Control. Rank Is the Friedman Mean Rank on the Mean Indicator Values; $p_{\\mathrm{Holm}}$ '
     'Is the $p$-Value of the Wilcoxon Signed-Rank Test Over the Instances Between \\ours{} and Each Algorithm, Adjusted by Holm\'s Procedure '
     'Over the Algorithms of Each Scenario (K-RVEA, Compared on the Instances With $d=10$, Is Not Adjusted); $\\hat{A}_{12}$ Is the Median Over the '
     'Instances of the Vargha--Delaney Effect Size, the Probability That a Run of \\ours{} Is Better Than a Run of the Algorithm; Large Counts '
     'the Instances With a Large Effect in Favor of \\ours{} ($\\hat{A}_{12}\\ge0.71$) and of the Algorithm ($\\hat{A}_{12}\\le0.29$).}',
     '\\label{tab:posthoc}', '\\footnotesize', '\\begin{tabular}{@{}llccccc@{}}', '\\toprule',
     'Scenario & Algorithm & Rank & $p_{\\mathrm{Holm}}$ & $\\hat{A}_{12}$ & Large & Instances \\\\']
last = None
for _, r in D.iterrows():
    if r.scenario != last:
        L.append('\\midrule'); last = r.scenario; s = r.scenario
    else:
        s = ''
    rank = '---' if not np.isfinite(r['rank']) else f"{r['rank']:.2f}"
    a = '---' if not np.isfinite(r.A12) else f'{r.A12:.2f}'
    L.append(f"{s} & {NAMES[r.alg]} & {rank} & {fp(r.pHolm)} & {a} & {r.large if r.large else '---'} & {r.n} \\\\")
L += ['\\bottomrule', '\\end{tabular}', '\\end{table*}']
(TAB / 'posthoc.tex').write_text('\n'.join(L) + '\n', encoding='utf8')
print('wrote posthoc.tex')
