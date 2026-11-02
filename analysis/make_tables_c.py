"""Manuscript tables under the uniform protocol of phases C and D.

WFG and DTLZ: every algorithm runs with a hard budget of 300 evaluations and
is scored by the IGD of the nondominated solutions among all its evaluations
(IGD computed by the run in double precision). The algorithms that return all
their evaluations and were not rerun come from rescore_old.csv (first 300
evaluations, scored the same way). IGD+ and the IGD of 50 solutions chosen by
the environmental selection of NSGA-III are robustness checks.
RWMOP: HV of a final set of N solutions (TP-IM-MOEA reduces its archive to N
with its own environmental selection); a run without a feasible solution, or
that stops with an error, scores HV = 0.
Wilcoxon rank-sum at 5%; the tag next to an algorithm gives it relative to
TP-IM-MOEA (+ better, - worse, = similar). Friedman mean ranks on the means.
Usage: python make_tables_c.py
"""
from pathlib import Path
import numpy as np, pandas as pd
from scipy.stats import ranksums, friedmanchisquare

H = Path(__file__).resolve().parent.parent / 'results'     # per-run results
TAB = Path(__file__).resolve().parent / 'tables'
TAB.mkdir(exist_ok=True)
HEAD = '\\providecommand{\\ours}{TP-IM-MOEA}\n'
NAMES = {'OURS': '\\ours', 'IMMOEAD': 'IM-MOEA/D', 'IMCMOEAD': 'IM-C-MOEA/D', 'SSDE': 'SSDE', 'EGES': 'EGES',
         'KRVEA': 'K-RVEA', 'RVEA': 'RVEA', 'MCEAD': 'MCEA/D', 'AVGSAEA': 'AVG-SAEA', 'CPSMOEA': 'CPS-MOEA',
         'SVRNSGAII': 'SVR-NSGA-II', 'CSEA': 'CSEA', 'REMO': 'REMO', 'ADSAPSO': 'ADSAPSO', 'SFADE': 'SFA-DE',
         'PIEA': 'PIEA', 'CTAEA': 'CTAEA'}


# ---------------------------------------------------------------- data
def c(name):
    d = pd.read_csv(H / f'c_{name}.csv')
    d['alg'] = d.config.replace({'g15': 'OURS'})
    return d


def have(name):
    return (H / f'c_{name}.csv').exists()


COLS = ['alg', 'prob', 'M', 'D', 'run', 'IGDall', 'IGDpall', 'IGD50']
old = pd.read_csv(H / 'rescore_old.csv')
old = old[(old.run <= 30) & (old.type == 'arch')].rename(columns={'IGDrep': 'IGDall', 'IGDprep': 'IGDpall'})
if have('D5'):                                   # EGES rerun with seeds and the cap replaces the archived runs
    old = old[old.alg != 'EGES']
if (H / 'rescore_remo.csv').exists():            # REMO (block B4), scored on its first 300 evaluations
    r = pd.read_csv(H / 'rescore_remo.csv').rename(columns={'IGDrep': 'IGDall', 'IGDprep': 'IGDpall'})
    old = pd.concat([old, r[r.run <= 30]])
WFG = pd.concat([c('C1')[COLS], old[COLS]] + ([c('D5')[COLS]] if have('D5') else []), ignore_index=True)
ABL = pd.concat([c('C3')[COLS], c('C1').query("alg == 'OURS'")[COLS]], ignore_index=True)
MO = pd.concat([c('C2')[COLS], c('C7').assign(alg='PIEA')[COLS], c('D3').assign(alg='EGES')[COLS]], ignore_index=True)
# CSEA, DTLZ4, m = 3, d = 100, runs 9 and 14 stop with an error: scored on the evaluations before it (G3);
# until G3 arrives, the runs with new seeds of phase E stand in for them
e2 = (c('G3').query("alg == 'CSEA'") if have('G3') else
      c('E2').query('run in [31, 32]').assign(run=lambda d: d.run.map({31: 9, 32: 14})))
DT = pd.concat([c('D2')[COLS], e2[COLS]] + ([c('D4').assign(alg='REMO')[COLS]] if have('D4') else []), ignore_index=True)
TIME = c('D1').groupby('alg').runtime.mean()      # optimization time only (metric.tSolve)

c5, c8 = c('C5'), c('C8')
if (H / 'rwmop_hv.csv').exists():                  # HV with one explicit normalization per problem (rescore_rwmop.m)
    hvn = pd.read_csv(H / 'rwmop_hv.csv')[['config', 'prob', 'run', 'HVnorm']]
    c5 = c5.merge(hvn, on=['config', 'prob', 'run'], how='left').assign(HV=lambda d: d.HVnorm)
    c8 = c8.merge(hvn, on=['config', 'prob', 'run'], how='left').assign(HV=lambda d: d.HVnorm)
RW = pd.concat([c5.query("alg == 'OURS'"), c8], ignore_index=True)[['alg', 'prob', 'M', 'D', 'run', 'HV']]
full = pd.MultiIndex.from_product([RW.alg.unique(), RW.prob.unique(), range(1, 31)], names=['alg', 'prob', 'run'])
miss = full.difference(pd.MultiIndex.from_frame(RW[['alg', 'prob', 'run']])).to_frame(index=False)
RW = pd.concat([RW, miss], ignore_index=True)
RW['HV'] = RW.HV.fillna(0)
RWMD = c5.groupby('prob')[['M', 'D']].first()


def cache(T, val='IGDall'):
    return {k: g[val].values for k, g in T.groupby(['alg', 'prob', 'M', 'D'])}


# ---------------------------------------------------------------- helpers
def fe(x):
    if not np.isfinite(x): return '---'
    if x == 0: return '0.0000e+0'
    e = int(np.floor(np.log10(abs(x)))); m = x / 10**e
    if round(abs(m), 4) >= 10: m /= 10; e += 1
    return f'{m:.4f}e{e:+d}'


def sci(p):
    e = int(np.floor(np.log10(p))); m = p / 10**e
    return f'{m:.1f}\\times10^{{{e}}}'


TT = {'+': '$+$', '-': '$-$', '=': '$=$'}


def tag(x, y, lower=True):
    if len(x) == 0 or len(y) == 0: return None
    if np.allclose(x, x[0]) and np.allclose(y, y[0]) and np.isclose(x[0], y[0]): return '='
    if ranksums(x, y).pvalue >= 0.05: return '='
    return '+' if ((x.mean() < y.mean()) if lower else (x.mean() > y.mean())) else '-'


def wlt(t):
    return f"{t.count('+')}/{t.count('-')}/{t.count('=')}"


def cell(mu, sd, tg, best):
    s = '---' if not np.isfinite(mu) else (fe(mu) if sd is None else f'{fe(mu)} ({fe(sd)})')
    if tg: s += ' ' + TT[tg]
    return f'\\hl{{{s}}}' if best else s


def per_instance(C, cols, groups, caption, label, lower=True, colsep='2pt', mean_only=False, ref='OURS'):
    """cols: algorithm keys, ref last; groups: [(prob, [(M, D), ...])]."""
    L = [HEAD + '\\begin{table*}[htbp]', '\\centering', '\\renewcommand{\\arraystretch}{1.15}',
         f'\\setlength{{\\tabcolsep}}{{{colsep}}}', f'\\caption{{{caption}}}', '\\resizebox{\\textwidth}{!}{',
         '\\begin{tabular}{@{}' + 'c' * (3 + len(cols)) + '@{}}', '\\toprule',
         'Problem&$m$&$d$&' + '&'.join(NAMES.get(a, a) for a in cols) + '\\\\', '\\midrule']
    tags = {a: [] for a in cols[:-1]}
    for gi, (prob, mds) in enumerate(groups):
        for k, (M, D) in enumerate(mds):
            o = C.get((ref, prob, M, D), np.array([]))
            mus = {a: C[(a, prob, M, D)].mean() for a in cols if (a, prob, M, D) in C}
            best = (min if lower else max)(mus.values())
            cells = []
            for a in cols:
                if a not in mus:
                    cells.append('---'); continue
                x = C[(a, prob, M, D)]
                tg = None if a == ref else tag(x, o, lower)
                if tg: tags[a].append(tg)
                cells.append(cell(x.mean(), None if mean_only else x.std(ddof=1), tg, np.isclose(x.mean(), best)))
            lead = f'\\multirow{{{len(mds)}}}{{*}}{{{prob}}}' if k == 0 else ''
            L.append(f'{lead}&{M}&{D}&' + '&'.join(cells) + '\\\\')
        if gi < len(groups) - 1: L.append('\\hline')
    L += ['\\hline', '\\multicolumn{3}{c}{$+/-/=$}&' + '&'.join(wlt(tags[a]) for a in cols[:-1]) + '&\\\\',
          '\\bottomrule', '\\end{tabular}', '}', f'\\label{{{label}}}', '\\end{table*}']
    return '\n'.join(L) + '\n', tags


def ranks(C, algs, inst):
    Mx = np.array([[C[(a,) + i].mean() for a in algs] for i in inst])
    return dict(zip(algs, pd.DataFrame(Mx).rank(axis=1).mean().values)), friedmanchisquare(*Mx.T).pvalue


def write(name, text):
    (TAB / name).write_text(text, encoding='utf8'); print('wrote', name)


GAP = ('The Best Mean Is Highlighted in Gray. $+$, $-$, and $=$ Indicate That an Algorithm Performs Significantly Better Than, '
       'Worse Than, and Similarly to \\ours{}, Respectively (Wilcoxon Rank-Sum Test, 0.05 Significance Level).')
IGDDEF = 'IGD of the Nondominated Solutions Among All Evaluations'

# ---------------------------------------------------------------- WFG per-instance (S2-S6)
CW, CWp, CW50 = cache(WFG), cache(WFG, 'IGDpall'), cache(WFG, 'IGD50')
for D in (10, 100):
    groups = [(f'WFG{p}', [(m, D) for m in (3, 6, 9)]) for p in range(1, 10)]
    cap = (f'{IGDDEF} (Mean and Standard Deviation) on WFG1--WFG9 With $d={D}$ ($N=50$, $FE=300$, 30 Runs). ' + GAP)
    write(f'wfg_d{D}.tex', per_instance(CW, ['IMMOEAD', 'IMCMOEAD', 'SSDE', 'OURS'], groups, cap, f'tab:wfg_d{D}', colsep='6pt')[0])
groups = [(f'WFG{p}', [(m, d) for m in (3, 6, 9) for d in (10, 100)]) for p in range(1, 10)]
cap = (f'{IGDDEF} (Mean and Standard Deviation) of K-RVEA, EGES, RVEA, and \\ours{{}} on WFG1--WFG9 ($N=50$, $FE=300$, 30 Runs). '
       '``---\'\' Marks $d=100$ for K-RVEA, Whose Initial Design of $11d-1$ Samples Exceeds the Budget. ' + GAP)
write('krvea_eges_rvea.tex', per_instance(CW, ['KRVEA', 'EGES', 'RVEA', 'OURS'], groups, cap, 'tab:krvea_eges_rvea', colsep='6pt')[0])
cap = (f'{IGDDEF} (Mean and Standard Deviation) of MCEA/D, AVG-SAEA, CPS-MOEA, SVR-NSGA-II, CSEA, and \\ours{{}} on WFG1--WFG9 '
       '($N=50$, $FE=300$, 30 Runs). ' + GAP)
write('nonkriging_baselines.tex', per_instance(CW, ['MCEAD', 'AVGSAEA', 'CPSMOEA', 'SVRNSGAII', 'CSEA', 'OURS'], groups, cap,
                                               'tab:nonkriging_baselines', colsep='3pt')[0])
FURTHER = ['PIEA', 'ADSAPSO', 'SFADE'] + (['REMO'] if ('REMO', 'WFG1', 3, 10) in CW else [])
lst = ', '.join(NAMES[a] for a in FURTHER)
cap = (f'{IGDDEF} (Mean and Standard Deviation) of {lst}, and \\ours{{}} on WFG1--WFG9 ($N=50$, $FE=300$, 30 Runs). ' + GAP)
write('further_baselines.tex', per_instance(CW, FURTHER + ['OURS'], groups, cap, 'tab:further_baselines', colsep='4pt')[0])

# ---------------------------------------------------------------- WFG summary (main text, Table II)
inst54 = [(f'WFG{p}', m, d) for d in (10, 100) for m in (3, 6, 9) for p in range(1, 10)]
inst27 = [i for i in inst54 if i[2] == 10]
A54 = ['OURS', 'IMMOEAD', 'IMCMOEAD', 'SSDE', 'RVEA', 'EGES', 'MCEAD', 'AVGSAEA', 'CPSMOEA', 'SVRNSGAII', 'CSEA'] + FURTHER
A27 = A54 + ['KRVEA']
r54, p54 = ranks(CW, A54, inst54); r27, p27 = ranks(CW, A27, inst27)
r54p, p54p = ranks(CWp, A54, inst54); r5450, p5450 = ranks(CW50, A54, inst54)
L = [HEAD + '\\begin{table}[t]', '\\centering', '\\renewcommand{\\arraystretch}{1.12}', '\\setlength{\\tabcolsep}{2.5pt}',
     '\\caption{Summary of the Comparison on WFG1--WFG9 ($N=50$, $FE=300$, 30 Runs). $+/-/=$ Counts the Instances on Which an '
     'Algorithm Performs Significantly Better Than, Worse Than, and Similarly to \\ours{} in IGD (Wilcoxon Rank-Sum Test, 0.05 '
     'Significance Level). The Next Columns Give Friedman Mean Ranks (Lower Is Better) in IGD Over the 54 Instances and Over the 27 '
     'Instances With $d=10$, and in IGD$^+$ and IGD$_{50}$ Over the 54 Instances. Time Is the Mean Optimization Time per Run on One Machine. '
     'Per-Instance Results Are Given in Tables~S2--S6 of the Supplementary Material.}',
     '\\label{tab:wfg_baselines_summary}', '\\footnotesize', '\\begin{tabular}{@{}lcccccc@{}}', '\\toprule',
     '&&\\multicolumn{2}{c}{IGD rank}&IGD$^+$&IGD$_{50}$&\\\\', '\\cmidrule(lr){3-4}',
     'Algorithm & $+/-/=$ & 54 & $d=10$ & rank & rank & Time (s) \\\\', '\\midrule']
for a in sorted(A27, key=lambda a: r54.get(a, 99)):
    if a == 'OURS':
        w = '---'
    else:
        inst = inst27 if a == 'KRVEA' else inst54
        w = wlt([tag(CW[(a,) + i], CW[('OURS',) + i]) for i in inst]) + ('$^{\\mathrm{a}}$' if a == 'KRVEA' else '')
    f2 = lambda d: f'{d[a]:.2f}' if a in d else '---'
    L.append(f"{NAMES[a]} & {w} & {f2(r54)} & {f2(r27)} & {f2(r54p)} & {f2(r5450)} & {TIME[a if a != 'OURS' else 'OURS']:.2f} \\\\")
L += ['\\bottomrule', '\\end{tabular}', '', '\\vspace{2pt}',
      '\\parbox{\\columnwidth}{\\scriptsize $^{\\mathrm{a}}$Evaluated on the 27 instances with $d=10$: its initial design of $11d-1$ '
      f'samples exceeds the budget at $d=100$. Friedman tests (IGD): $p={sci(p54)}$ (54 instances, {len(A54)} algorithms) and '
      f'$p={sci(p27)}$ ($d=10$, {len(A27)} algorithms).}}', '\\end{table}']
write('wfg_baselines_summary.tex', '\n'.join(L) + '\n')

# ---------------------------------------------------------------- DTLZ (main text summary + S13-S15)
CD, CDp, CD50 = cache(DT), cache(DT, 'IGDpall'), cache(DT, 'IGD50')
DPROB = ['DTLZ1', 'DTLZ2', 'DTLZ3', 'DTLZ4', 'DTLZ7']
inst30 = [(p, m, d) for d in (10, 100) for m in (3, 6, 9) for p in DPROB]
i10, i100 = [i for i in inst30 if i[2] == 10], [i for i in inst30 if i[2] == 100]
FURTHER_D = ['PIEA', 'ADSAPSO', 'SFADE'] + (['REMO'] if ('REMO', 'DTLZ1', 3, 10) in CD else [])
D30 = [a for a in dict.fromkeys(A54 + FURTHER_D) if all((a,) + i in CD for i in inst30)]
D15 = D30 + ['KRVEA']
q30, pq30 = ranks(CD, D30, inst30); q10, pq10 = ranks(CD, D15, i10); q100, pq100 = ranks(CD, D30, i100)
q30p, _ = ranks(CDp, D30, inst30); q3050, _ = ranks(CD50, D30, inst30)
L = [HEAD + '\\begin{table}[t]', '\\centering', '\\renewcommand{\\arraystretch}{1.12}', '\\setlength{\\tabcolsep}{2.5pt}',
     '\\caption{Summary of the Comparison on the Held-Out Suite DTLZ1--DTLZ4 and DTLZ7 ($m\\in\\{3,6,9\\}$, $d\\in\\{10,100\\}$, $N=50$, '
     '$FE=300$, 30 Runs). $+/-/=$ and the Ranks Are Defined as in Table~\\ref{tab:wfg_baselines_summary}; IGD Ranks Are Given Over the 30 '
     'Instances and Separately Over the 15 Instances With $d=10$ and With $d=100$. Per-Instance Results Are Given in Tables~S13--S15 of the '
     'Supplementary Material.}',
     '\\label{tab:dtlz_summary}', '\\footnotesize', '\\begin{tabular}{@{}lcccccc@{}}', '\\toprule',
     '&&\\multicolumn{3}{c}{IGD rank}&IGD$^+$&IGD$_{50}$\\\\', '\\cmidrule(lr){3-5}',
     'Algorithm & $+/-/=$ & 30 & $d=10$ & $d=100$ & rank & rank \\\\', '\\midrule']
for a in sorted(D15, key=lambda a: q30.get(a, 99)):
    if a == 'OURS':
        w = '---'
    else:
        inst = i10 if a == 'KRVEA' else inst30
        w = wlt([tag(CD[(a,) + i], CD[('OURS',) + i]) for i in inst]) + ('$^{\\mathrm{a}}$' if a == 'KRVEA' else '')
    f2 = lambda d: f'{d[a]:.2f}' if a in d else '---'
    L.append(f'{NAMES[a]} & {w} & {f2(q30)} & {f2(q10)} & {f2(q100)} & {f2(q30p)} & {f2(q3050)} \\\\')
L += ['\\bottomrule', '\\end{tabular}', '', '\\vspace{2pt}',
      '\\parbox{\\columnwidth}{\\scriptsize $^{\\mathrm{a}}$Evaluated on the 15 instances with $d=10$. Friedman tests (IGD): '
      f'$p={sci(pq30)}$ (30 instances, {len(D30)} algorithms) and $p={sci(pq10)}$ ($d=10$, {len(D15)} algorithms).}}', '\\end{table}']
write('dtlz_summary.tex', '\n'.join(L) + '\n')
dgroups = [(p, [(m, d) for m in (3, 6, 9) for d in (10, 100)]) for p in DPROB]
sets = [('dtlz_a', ['IMMOEAD', 'IMCMOEAD', 'SSDE', 'RVEA', 'OURS'], '6pt', ''),
        ('dtlz_b', ['KRVEA', 'EGES', 'MCEAD', 'AVGSAEA', 'OURS'], '6pt',
         '``---\'\' Marks $d=100$ for K-RVEA, Whose Initial Design of $11d-1$ Samples Exceeds the Budget. '),
        ('dtlz_c', ['CPSMOEA', 'SVRNSGAII', 'CSEA'] + FURTHER_D + ['OURS'], '3pt', '')]
for name, cols, sep, extra in sets:
    lst = ', '.join(NAMES[a] for a in cols[:-1]) + ', and \\ours{}'
    cap = (f'{IGDDEF} (Mean and Standard Deviation) of {lst} on the Held-Out Suite DTLZ1--DTLZ4 and DTLZ7 ($N=50$, $FE=300$, '
           '30 Runs). ' + extra + GAP)
    write(f'{name}.tex', per_instance(CD, cols, dgroups, cap, f'tab:{name}', colsep=sep)[0])

# ---------------------------------------------------------------- many objectives (S12)
CM = cache(MO)
groupsMO = [(f'WFG{p}', sorted({(M, D) for (a, pp, M, D) in CM if pp == f'WFG{p}' and a == 'OURS'})) for p in range(1, 10)]
cap = (f'{IGDDEF} (Mean and Standard Deviation) on WFG1--WFG9 With $m=15$ and $m=20$, $d=(m-1)+10$ and $d=100$ ($N=50$, $FE=300$, '
       '30 Runs). ' + GAP)
write('manyobjective.tex', per_instance(CM, ['SSDE', 'RVEA', 'PIEA', 'EGES', 'OURS'], groupsMO, cap, 'tab:manyobjective', colsep='4pt')[0])
instMO = [(p, M, D) for p, mds in groupsMO for (M, D) in mds]
for met, CC in (('IGD', CM), ('IGD+', cache(MO, 'IGDpall')), ('IGD50', cache(MO, 'IGD50'))):
    rr, pp = ranks(CC, ['OURS', 'SSDE', 'RVEA', 'PIEA', 'EGES'], instMO)
    print(f'many-objective {met} ranks:', {k: round(v, 2) for k, v in sorted(rr.items(), key=lambda z: z[1])}, f'p={pp:.1e}')

# ---------------------------------------------------------------- ablation (S8)
abl = ['q01_noRefMap', 'q02_noInfillD', 'q03_noSelRef', 'q04_noPre', 'q05_noCheap', 'q06_noSOM', 'q07_withNbh', 'q08_withNbh_shuf']
for a, s in zip(abl, ['noRM', 'noIF', 'noRS', 'noPS', 'noLD', 'noSOM', 'NB', 'NB-sh']):
    NAMES[a] = s
cap = (f'Mean {IGDDEF} of \\ours{{}} and Its Variants on WFG1--WFG9 (30 Runs, $N=50$, $FE=300$). Each Variant, Named \\ours-$X$, Removes or '
       'Adds One Component: noRM Replaces the Reference-Anchored Map by a One-Dimensional Chain; noIF Replaces the Decomposition-Based Ranking '
       'of Candidates by Nondominated Sorting of the Predicted Objectives; noRS Uses Truncation Instead of Reference Niching for $m\\ge4$; noPS '
       'Evaluates All Candidates Without Prescreening; noLD Removes Latin Hypercube Initialization and Duplicate Rejection; noSOM Uses the Parent '
       'Instead of Its Region\'s Prototype as Base Point; NB and NB-sh Add Neighborhood Cooperation Over the Correct and Over a Randomly Shuffled '
       'Lattice, Respectively. The Best Mean Is Highlighted in Gray. $+$, $-$, and $=$ Indicate That a Variant Performs Significantly Better '
       'Than, Worse Than, and Similarly to \\ours{} (Wilcoxon Rank-Sum Test, 0.05 Significance Level).')
CA = cache(ABL)
t, abtags = per_instance(CA, abl + ['OURS'], groups, cap, 'tab:ablation', colsep='2pt', mean_only=True)
write('ablation.tex', t)
inst = [(f'WFG{p}', m, d) for p in range(1, 10) for m in (3, 6, 9) for d in (10, 100)]
nb = {m: [tag(CA[('q07_withNbh',) + i], CA[('q08_withNbh_shuf',) + i]) for i in inst if i[1] == m] for m in (3, 6, 9)}
print('ablation (variant vs ours):')
for a in abl:
    print(f'  {NAMES[a]:6s} all {wlt(abtags[a])}; ' + '; '.join(
        f"m={m} {wlt([tag(CA[(a,) + i], CA[('OURS',) + i]) for i in inst if i[1] == m])}" for m in (3, 6, 9)))
print('  NB vs NB-sh:', wlt(sum(nb.values(), [])), {m: wlt(v) for m, v in nb.items()})

# ---------------------------------------------------------------- sensitivity (S9, S10)
c4 = c('C4'); c4['k'] = c4.config.str.split('_').str[0]
if have('I1'):                                    # population sizes N = 30 and N = 100 (phase I)
    c4 = pd.concat([c4, c('I1').assign(k=lambda d: d.config)], ignore_index=True)
CS ={k: g.IGDall.values for k, g in c4.groupby(['k', 'prob', 'M', 'D'])}
sinst = [(p, 3, 10) for p in ('WFG2', 'WFG4', 'WFG6', 'WFG9')] + [(p, 9, 100) for p in ('WFG2', 'WFG4', 'WFG6', 'WFG9')]
rows = [('s00', 'Default', '')] + [
    ('s01', '$\\eta_0$', '$0.1$'), ('s02', '', '$0.4$'), ('s03', '$F_0$', '$0.3$'), ('s04', '', '$0.7$'),
    ('s05', '$CR_0$', '$0.7$'), ('s06', '', '$0.95$'), ('s07', '$K$', '$3$'), ('s08', '', '$10$'),
    ('s09', '$k$', '$1$'), ('s10', '', '$5$'), ('s11', '$\\theta$', '$2$'), ('s12', '', '$10$'),
    ('s13', '$B_0$', '$5$'), ('s14', '', '$20$')]
nrows = [('n030', '$N$', '$30$'), ('n100', '', '$100$')] if have('I1') else []
best = {i: min(CS[(r[0],) + i].mean() for r in rows + nrows) for i in sinst}
L = [HEAD, '\\begin{table*}[htbp]', '\\centering', '\\renewcommand{\\arraystretch}{1.15}', '\\setlength{\\tabcolsep}{3pt}',
     f'\\caption{{Mean {IGDDEF} of \\ours{{}} With One Parameter Varied at a Time Around Its Default Value (Table~I of the Article)'
     + (', and With Population Sizes $N=30$ and $N=100$,' if nrows else '') +
     ' on WFG2, WFG4, WFG6, and WFG9 ($N=50$ Unless Stated, $FE=300$, 30 Runs). The Defaults Are $\\eta_0=0.2$, $F_0=0.5$, $CR_0=0.9$, $K=5$, $k=3$, $\\theta=5$, '
     'and $B_0=10$. The Best Mean Is Highlighted in Gray. $+$, $-$, and $=$ Indicate That a Variant Performs Significantly Better Than, '
     'Worse Than, and Similarly to the Default Configuration (Wilcoxon Rank-Sum Test, 0.05 Significance Level), and the Last Column '
     'Counts These Outcomes.}',
     '\\label{tab:sensitivity}', '\\resizebox{\\textwidth}{!}{', '\\begin{tabular}{@{}llccccccccc@{}}', '\\toprule',
     '&&\\multicolumn{4}{c}{$(m,d)=(3,10)$}&\\multicolumn{4}{c}{$(m,d)=(9,100)$}&\\\\', '\\cmidrule(lr){3-6}\\cmidrule(lr){7-10}',
     'Parameter&Value&WFG2&WFG4&WFG6&WFG9&WFG2&WFG4&WFG6&WFG9&$+/-/=$\\\\', '\\midrule']
tot = []
TOTAL = lambda t: f'\\multicolumn{{10}}{{l}}{{Total over the 14 parameter variants and 8 instances}}&{t}\\\\'
for cfg, par, val in rows + nrows:
    if cfg == 'n030':                             # population size, outside the total of the parameters
        L += ['\\midrule', TOTAL(wlt(tot)), '\\midrule']
    cells, cnt = [], []
    for i in sinst:
        x = CS[(cfg,) + i]; s = fe(x.mean())
        if cfg != 's00':
            g = tag(x, CS[('s00',) + i]); cnt.append(g); s += ' ' + TT[g]
        cells.append(f'\\hl{{{s}}}' if np.isclose(x.mean(), best[i]) else s)
    if cfg[0] == 's': tot += cnt
    lead = f'\\multicolumn{{2}}{{l}}{{{par}}}' if cfg == 's00' else f'{par}&{val}'
    L.append(f"{lead}&{'&'.join(cells)}&{wlt(cnt) if cnt else ''}\\\\")
    if cfg in ('s00', 's02', 's04', 's06', 's08', 's10', 's12'): L.append('\\midrule')
    print(f'  sensitivity {cfg} {wlt(cnt) if cnt else ""}')
if not nrows:
    L += ['\\midrule', TOTAL(wlt(tot))]
L += ['\\bottomrule', '\\end{tabular}}', '\\end{table*}', '']
write('sensitivity.tex', '\n'.join(L))
print('sensitivity total', wlt(tot))

B = {k: g.HV.fillna(0).values for k, g in c5.assign(k=c5.config.str[:3]).groupby(['k', 'prob'])}
TC = {k: g.IGDall.values for k, g in c4[c4.k.str.startswith('t')].groupby(['k', 'M', 'D'])}


def trio(lo, de, hi, lower):
    vals = [lo.mean(), de.mean(), hi.mean()]; b = (min if lower else max)(vals)
    out = []
    for v, x in zip(vals, (lo, de, hi)):
        s = fe(v) + ('' if x is de else ' ' + TT[tag(x, de, lower)])
        out.append(f'\\hl{{{s}}}' if np.isclose(v, b) else s)
    return out


L = [HEAD, '\\begin{table}[htbp]', '\\centering', '\\renewcommand{\\arraystretch}{1.15}', '\\setlength{\\tabcolsep}{3pt}',
     '\\caption{Sensitivity of \\ours{} to the Base Batch Size $B_0$ on Four RWMOP Problems (Mean HV of the Final $N$ Solutions, Higher Is '
     'Better; a Run Without a Feasible Solution Scores HV $=0$) and to the Batch-Adaptation Threshold $\\Theta$ on WFG9 With $FE=2{,}000$ '
     f'(Mean {IGDDEF}), 30 Runs. The Best Mean Is Highlighted in Gray. $+$, $-$, and $=$ Indicate That a Value Performs Significantly '
     'Better Than, Worse Than, and Similarly to the Default (Wilcoxon Rank-Sum Test, 0.05 Significance Level).}',
     '\\label{tab:sensitivity_batch}', '\\resizebox{\\columnwidth}{!}{', '\\begin{tabular}{@{}lccc@{}}', '\\toprule',
     'Problem&$B_0=5$&$B_0=10$ (default)&$B_0=20$\\\\', '\\midrule']
for p in ('RWMOP1', 'RWMOP8', 'RWMOP21', 'RWMOP29'):
    L.append(f"{p}&{'&'.join(trio(B[('b05', p)], B[('g15', p)], B[('b20', p)], False))}\\\\")
L += ['\\midrule', 'Problem&$\\Theta=500$&$\\Theta=1{,}000$ (default)&$\\Theta=2{,}000$\\\\', '\\midrule']
for m, d in ((3, 10), (9, 100)):
    L.append(f"WFG9, $(m,d)=({m},{d})$&{'&'.join(trio(TC[('t0500', m, d)], TC[('t1000', m, d)], TC[('t2000', m, d)], True))}\\\\")
L += ['\\bottomrule', '\\end{tabular}}', '\\end{table}', '']
write('sensitivity_batch.tex', '\n'.join(L))

# ---------------------------------------------------------------- RWMOP (S7 + main-text summary)
CR = {k: g.HV.values for k, g in RW.groupby(['alg', 'prob'])}
probs = sorted(RW.prob.unique(), key=lambda s: int(s[5:]))
rcols = ['IMMOEAD', 'IMCMOEAD', 'SSDE', 'CTAEA', 'RVEA', 'OURS']
L = [HEAD + '\\begin{table*}[htbp]', '\\centering', '\\renewcommand{\\arraystretch}{1.15}', '\\setlength{\\tabcolsep}{2pt}',
     '\\caption{HV of the Final $N$ Solutions (Mean and Standard Deviation; Higher Is Better) on RWMOP1--RWMOP35 (Settings of Kumar et al., '
     '30 Runs), With the Objectives of Each Problem Normalized by the Ideal and Nadir Points of the Union of All Final Sets and the Reference Point $(1.1,\\ldots,1.1)$. A Run Without a Feasible Solution Scores HV $=0$. The Best Mean Is Highlighted in Gray. $+$, $-$, and $=$ Indicate That an '
     'Algorithm Performs Significantly Better Than, Worse Than, and Similarly to \\ours{} (Wilcoxon Rank-Sum Test, 0.05 Significance Level).}',
     '\\resizebox{\\textwidth}{!}{', '\\begin{tabular}{@{}' + 'c' * (3 + len(rcols)) + '@{}}', '\\toprule',
     'Problem&$m$&$d$&' + '&'.join(NAMES[a] for a in rcols) + '\\\\', '\\midrule']
rtags = {a: [] for a in rcols[:-1]}
for p in probs:
    o = CR[('OURS', p)]; mus = {a: CR[(a, p)].mean() for a in rcols}; b = max(mus.values())
    cells = []
    for a in rcols:
        x = CR[(a, p)]; tg = None if a == 'OURS' else tag(x, o, lower=False)
        if tg: rtags[a].append(tg)
        cells.append(cell(x.mean(), x.std(ddof=1), tg, b > 0 and np.isclose(x.mean(), b)))
    L.append(f'{p}&{RWMD.loc[p, "M"]}&{RWMD.loc[p, "D"]}&' + '&'.join(cells) + '\\\\')
L += ['\\hline', '\\multicolumn{3}{c}{$+/-/=$}&' + '&'.join(wlt(rtags[a]) for a in rcols[:-1]) + '&\\\\',
      '\\bottomrule', '\\end{tabular}', '}', '\\label{tab:rwmop_full}', '\\end{table*}']
write('rwmop_full.tex', '\n'.join(L) + '\n')
Mx = np.array([[-CR[(a, p)].mean() for a in rcols] for p in probs])
rr = dict(zip(rcols, pd.DataFrame(Mx).rank(axis=1).mean().values)); prw = friedmanchisquare(*Mx.T).pvalue
nbest = {a: sum(np.isclose(CR[(a, p)].mean(), max(CR[(b, p)].mean() for b in rcols)) and CR[(a, p)].mean() > 0 for p in probs) for a in rcols}
L = [HEAD + '\\begin{table}[t]', '\\centering', '\\renewcommand{\\arraystretch}{1.15}',
     '\\caption{Summary of the Comparison on RWMOP1--RWMOP35 (HV of the Final $N$ Solutions, 30 Runs). $+/-/=$ Counts the Problems on Which '
     'an Algorithm Performs Significantly Better Than, Worse Than, and Similarly to \\ours{} (Wilcoxon Rank-Sum Test, 0.05 Significance Level); '
     'Rank Is the Friedman Mean Rank (Lower Is Better); Best Counts the Problems on Which an Algorithm Attains the Highest Mean HV. Per-Instance '
     'Results Are Given in Table~S7 of the Supplementary Material.}', '\\label{tab:rwmop}', '\\begin{tabular}{@{}lccc@{}}', '\\toprule',
     'Algorithm & $+/-/=$ & Rank & Best \\\\', '\\midrule']
for a in sorted(rcols, key=lambda a: rr[a]):
    L.append(f"{NAMES[a]} & {'---' if a == 'OURS' else wlt(rtags[a])} & {rr[a]:.2f} & {nbest[a]} \\\\")
L += ['\\bottomrule', '\\end{tabular}', '', '\\vspace{2pt}',
      f'\\parbox{{\\columnwidth}}{{\\scriptsize Friedman test: $p={sci(prw)}$ (35 problems, 6 algorithms).}}', '\\end{table}']
write('rwmop.tex', '\n'.join(L) + '\n')

# ---------------------------------------------------------------- numbers for the text
print('\nWFG ranks 54:', {k: round(v, 2) for k, v in sorted(r54.items(), key=lambda z: z[1])})
print('WFG ranks 27:', {k: round(v, 2) for k, v in sorted(r27.items(), key=lambda z: z[1])})
print('WFG IGD+ ranks:', {k: round(v, 2) for k, v in sorted(r54p.items(), key=lambda z: z[1])})
print('WFG IGD50 ranks:', {k: round(v, 2) for k, v in sorted(r5450.items(), key=lambda z: z[1])})
for a in A27:
    if a == 'OURS': continue
    by = {m: [tag(CW[(a,) + i], CW[('OURS',) + i]) for i in inst54 if i[1] == m and (a,) + i in CW] for m in (3, 6, 9)}
    byd = {d: [tag(CW[(a,) + i], CW[('OURS',) + i]) for i in inst54 if i[2] == d and (a,) + i in CW] for d in (10, 100)}
    print(f'  WFG {a:10s} {wlt(sum(by.values(), []))}  ' + ' '.join(f'm{m}:{wlt(v)}' for m, v in by.items())
          + '  ' + ' '.join(f'd{d}:{wlt(v)}' for d, v in byd.items()) + f'  time {TIME[a]:.2f}')
print(f"  time OURS {TIME['OURS']:.2f}")
print('\nDTLZ ranks 30:', {k: round(v, 2) for k, v in sorted(q30.items(), key=lambda z: z[1])})
print('DTLZ ranks d10:', {k: round(v, 2) for k, v in sorted(q10.items(), key=lambda z: z[1])})
print('DTLZ ranks d100:', {k: round(v, 2) for k, v in sorted(q100.items(), key=lambda z: z[1])})
for a in D15:
    if a == 'OURS': continue
    byd = {d: [tag(CD[(a,) + i], CD[('OURS',) + i]) for i in inst30 if i[2] == d and (a,) + i in CD] for d in (10, 100)}
    print(f'  DTLZ {a:10s} ' + ' '.join(f'd{d}:{wlt(v)}' for d, v in byd.items()))
print('\nRWMOP ranks:', {k: round(v, 2) for k, v in sorted(rr.items(), key=lambda z: z[1])}, 'best:', nbest)
print('RWMOP tags:', {a: wlt(t) for a, t in rtags.items()})
