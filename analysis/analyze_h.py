"""Phase H (budget) and phase I (population size) sensitivity.

H: WFG1-9 x (m, d) in {(3, 10), (9, 100)}, 30 runs, at 300 (phase C data, as
in the manuscript tables), 600 and 1,000 evaluations. TP-IM-MOEA, SSDE, PIEA
and EGES on the 18 instances; K-RVEA on the 9 with d = 10.
I: TP-IM-MOEA with N = 30 and N = 100 against N = 50 (block C4, s00_default)
on WFG2, 4, 6, 9 x (3, 10), (9, 100).
Wilcoxon rank-sum at 5%; +/-/= is the algorithm relative to TP-IM-MOEA.
Usage: python analyze_h.py
"""
from pathlib import Path
import numpy as np, pandas as pd
from scipy.stats import ranksums, friedmanchisquare

H = Path(__file__).resolve().parent.parent / 'results'     # per-run results
COLS = ['alg', 'prob', 'M', 'D', 'run', 'FE', 'IGDall', 'IGDpall', 'IGD50']


def c(name):
    d = pd.read_csv(H / f'c_{name}.csv')
    d['alg'] = d.alg.replace({'TPIMMOEA_X': 'OURS'})
    return d


# ---------------------------------------------------------------- 300 evaluations, as in make_tables_c.py
old = pd.read_csv(H / 'rescore_old.csv')
old = old[(old.run <= 30) & (old.type == 'arch') & old.alg.isin(['PIEA', 'KRVEA'])]
old = old.rename(columns={'IGDrep': 'IGDall', 'IGDprep': 'IGDpall'})
c1 = c('C1'); c1['alg'] = c1.config.replace({'g15': 'OURS'})
d5 = c('D5')
F300 = pd.concat([c1[c1.alg.isin(['OURS', 'SSDE'])], old, d5]).assign(FE=300)
INST = c('H1')[['prob', 'M', 'D']].drop_duplicates()
F300 = F300.merge(INST, on=['prob', 'M', 'D'])
ALL = pd.concat([F300, c('H1').assign(FE=lambda d: d.maxFE), c('H2').assign(FE=lambda d: d.maxFE),
                 c('H3').assign(FE=lambda d: d.maxFE)], ignore_index=True)[COLS]
print(ALL.groupby(['FE', 'alg']).size().unstack())


def tag(x, y):
    if ranksums(x, y).pvalue >= 0.05: return '='
    return '+' if x.mean() < y.mean() else '-'


def summary(T, algs, val='IGDall', label=''):
    G = {k: g[val].values for k, g in T.groupby(['alg', 'prob', 'M', 'D'])}
    inst = sorted({k[1:] for k in G if k[0] == 'OURS'})
    inst = [i for i in inst if all((a,) + i in G for a in algs)]
    means = np.array([[G[(a,) + i].mean() for a in algs] for i in inst])
    ranks = pd.DataFrame(means).rank(axis=1).mean().values
    p = friedmanchisquare(*means.T).pvalue if len(algs) > 2 else np.nan
    out = [f'{label} {val}: {len(inst)} instances, Friedman p={p:.1e}  ' +
           '  '.join(f'{a} {r:.2f}' for a, r in zip(algs, ranks))]
    for a in algs:
        if a == 'OURS': continue
        t = [tag(G[(a,) + i], G[('OURS',) + i]) for i in inst]
        by = {}
        for M in sorted({i[1] for i in inst}):
            tt = [tg for tg, i in zip(t, inst) if i[1] == M]
            by[M] = f"{tt.count('+')}/{tt.count('-')}/{tt.count('=')}"
        ratio = np.exp(np.mean([np.log(G[(a,) + i].mean() / G[('OURS',) + i].mean()) for i in inst]))
        out.append(f"    {a:6s} {t.count('+')}/{t.count('-')}/{t.count('=')}  " +
                   '  '.join(f'm{M}:{s}' for M, s in by.items()) + f'  IGD ratio vs ours {ratio:.3f}')
    return '\n'.join(out)


print('\n=== Budget sensitivity')
for FE in [300, 600, 1000]:
    T = ALL[ALL.FE == FE]
    for val in ['IGDall', 'IGDpall', 'IGD50']:
        print(summary(T, ['OURS', 'PIEA', 'EGES', 'SSDE'], val, f'FE={FE} all 18'))
    print(summary(T[T.D == 10], ['OURS', 'KRVEA', 'PIEA', 'EGES', 'SSDE'], 'IGDall', f'FE={FE} d=10'))

print('\n=== TP-IM-MOEA across budgets (mean IGD ratio to 300 evaluations)')
O = ALL[ALL.alg == 'OURS'].groupby(['FE', 'prob', 'M', 'D']).IGDall.mean().unstack('FE')
for M in [3, 9]:
    s = O.xs(M, level='M')
    print(f'  m={M}: 600/300 {np.exp(np.log(s[600] / s[300]).mean()):.3f}  1000/300 {np.exp(np.log(s[1000] / s[300]).mean()):.3f}')
for a in ['PIEA', 'EGES', 'SSDE', 'KRVEA']:
    A = ALL[ALL.alg == a].groupby(['FE', 'prob', 'M', 'D']).IGDall.mean().unstack('FE')
    print(f'  {a}: 600/300 {np.exp(np.log(A[600] / A[300]).mean()):.3f}  1000/300 {np.exp(np.log(A[1000] / A[300]).mean()):.3f}')

print('\n=== Per-instance tags vs ours (IGDall), per budget')
for FE in [300, 600, 1000]:
    T = ALL[ALL.FE == FE]
    G = {k: g.IGDall.values for k, g in T.groupby(['alg', 'prob', 'M', 'D'])}
    rows = []
    for (p, M, D) in sorted({k[1:] for k in G if k[0] == 'OURS'}, key=lambda i: (i[1], int(i[0][3:]))):
        rows.append(f'{p}m{M}:' + ''.join(tag(G[(a, p, M, D)], G[('OURS', p, M, D)]) if (a, p, M, D) in G else '.'
                                          for a in ['PIEA', 'EGES', 'SSDE', 'KRVEA']))
    print(f'  FE={FE} [PIEA EGES SSDE KRVEA]: ' + ' '.join(rows))

# ---------------------------------------------------------------- phase I
print('\n=== Population size (vs N = 50, block C4 s00_default)')
c4 = pd.read_csv(H / 'c_C4.csv').query("config == 's00_default'")
I1 = pd.read_csv(H / 'c_I1.csv')
G50 = {k: g.IGDall.values for k, g in c4.groupby(['prob', 'M', 'D'])}
for cfg in ['n030', 'n100']:
    T = I1[I1.config == cfg]
    t, r, rows = [], [], []
    for k, g in T.groupby(['prob', 'M', 'D']):
        tg = tag(g.IGDall.values, G50[k]); t.append(tg)
        r.append(g.IGDall.mean() / G50[k].mean())
        rows.append(f'{k[0]}m{k[1]}:{tg}{r[-1]:.3f}')
    print(f"  {cfg}: {t.count('+')}/{t.count('-')}/{t.count('=')}  mean ratio {np.exp(np.mean(np.log(r))):.3f}  " + ' '.join(rows))

# ---------------------------------------------------------------- Table S18 (budget)
TAB = Path(__file__).resolve().parent / 'tables'
TAB.mkdir(exist_ok=True)
NM = {'OURS': '\\ours', 'PIEA': 'PIEA', 'EGES': 'EGES', 'SSDE': 'SSDE', 'KRVEA': 'K-RVEA$^{\\mathrm{a}}$'}
cols, pv = {}, []
for FE in [300, 600, 1000]:
    T = ALL[ALL.FE == FE]
    G = {k: g.IGDall.values for k, g in T.groupby(['alg', 'prob', 'M', 'D'])}
    inst = sorted({k[1:] for k in G if k[0] == 'OURS'})
    algs4 = ['OURS', 'PIEA', 'EGES', 'SSDE']
    means = np.array([[G[(a,) + i].mean() for a in algs4] for i in inst])
    rk = dict(zip(algs4, pd.DataFrame(means).rank(axis=1).mean().values))
    pv.append(friedmanchisquare(*means.T).pvalue)
    for a in algs4 + ['KRVEA']:
        ii = [i for i in inst if (a,) + i in G]
        t = [tag(G[(a,) + i], G[('OURS',) + i]) for i in ii]
        ratio = np.exp(np.mean([np.log(G[(a,) + i].mean() / G[('OURS',) + i].mean()) for i in ii]))
        cols[(a, FE)] = ('---' if a == 'OURS' else f"{t.count('+')}/{t.count('-')}/{t.count('=')}",
                         f'{rk[a]:.2f}' if a in rk else '---', '---' if a == 'OURS' else f'{ratio:.2f}')


def sci(p):
    e = int(np.floor(np.log10(p))); m = p / 10**e
    return f'{m:.1f}\\times10^{{{e}}}'


L = ['\\providecommand{\\ours}{TP-IM-MOEA}', '\\begin{table*}[htbp]', '\\centering', '\\renewcommand{\\arraystretch}{1.15}',
     '\\setlength{\\tabcolsep}{4pt}',
     '\\caption{Comparison of \\ours{} With PIEA, EGES, SSDE, and K-RVEA Under Budgets of 300, 600, and 1{,}000 Evaluations on WFG1--WFG9 '
     'With $(m,d)\\in\\{(3,10),(9,100)\\}$ ($N=50$, 30 Runs), Scored by the IGD of the Nondominated Solutions Among All Evaluations. '
     '$+/-/=$ Counts the Instances on Which an Algorithm Performs Significantly Better Than, Worse Than, and Similarly to \\ours{} '
     '(Wilcoxon Rank-Sum Test, 0.05 Significance Level). Rank Is the Friedman Mean Rank Over the 18 Instances (Lower Is Better). '
     'Ratio Is the Geometric Mean, Over the Instances, of the Mean IGD of an Algorithm Divided by That of \\ours{}.}',
     '\\label{tab:budget}', '\\begin{tabular}{@{}lccccccccc@{}}', '\\toprule',
     '&\\multicolumn{3}{c}{$FE=300$}&\\multicolumn{3}{c}{$FE=600$}&\\multicolumn{3}{c}{$FE=1{,}000$}\\\\',
     '\\cmidrule(lr){2-4}\\cmidrule(lr){5-7}\\cmidrule(lr){8-10}',
     'Algorithm' + '&$+/-/=$&Rank&Ratio' * 3 + '\\\\', '\\midrule']
for a in ['OURS', 'PIEA', 'EGES', 'SSDE', 'KRVEA']:
    L.append(NM[a] + ''.join('&' + '&'.join(cols[(a, FE)]) for FE in [300, 600, 1000]) + '\\\\')
L += ['\\bottomrule', '\\end{tabular}', '',
      '\\vspace{2pt}',
      '\\parbox{\\textwidth}{\\scriptsize $^{\\mathrm{a}}$Evaluated on the nine instances with $d=10$ (Section~IV-B of the article). '
      'Friedman tests over the 18 instances and the four ranked algorithms: ' +
      ', '.join(f'$p={sci(p)}$ ($FE={fe}$)' for p, fe in zip(pv, ['300', '600', '1{,}000'])) + '.}',
      '\\end{table*}', '']
(TAB / 'budget.tex').write_text('\n'.join(L), encoding='utf-8')
print('wrote budget.tex')
