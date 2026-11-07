"""Table of the shuffled-anchor ablation (main text): performance against
the correct anchors and topology of the final map, block F1.
Usage: python make_table_f.py"""
from pathlib import Path
import numpy as np, pandas as pd
from scipy.stats import ranksums, friedmanchisquare

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
TAB = HERE / 'tables'
TAB.mkdir(exist_ok=True)
F = pd.read_csv(H / 'c_Z4.csv')        # final model (phase Z, block Z4); c_F1.csv for g15
T = pd.read_csv(H / 'f_Z4.csv')
G = {k: g.IGDall.values for k, g in F.groupby(['config', 'prob', 'M', 'D'])}
inst = sorted({k[1:] for k in G if k[0] == 'g15i'})
cfgs = ['g15i', 'a025', 'a050', 'a100']
Mx = np.array([[G[(c,) + i].mean() for c in cfgs] for i in inst])
rk = dict(zip(cfgs, pd.DataFrame(Mx).rank(axis=1).mean().values))
p = friedmanchisquare(*Mx.T).pvalue


def tag(x, y):
    if ranksums(x, y).pvalue >= 0.05: return '='
    return '+' if x.mean() < y.mean() else '-'


lab = {'g15i': '0 (\\ours)', 'a025': '25\\%', 'a050': '50\\%', 'a100': '100\\%'}
L = ['\\providecommand{\\ours}{TP-IM-MOEA}', '\\begin{table}[t]', '\\centering', '\\renewcommand{\\arraystretch}{1.12}',
     '\\setlength{\\tabcolsep}{3pt}',
     '\\caption{Effect of Permuting the Anchors of the Map on WFG1--WFG9 (54 Instances, 30 Runs). A Permuted Fraction of the Nodes Is Trained '
     'on the Region of Another Node, While Reproduction Still Reads the Node of the Parent\'s Region. $+/-/=$ Counts the Instances on Which a '
     'Variant Performs Significantly Better Than, Worse Than, and Similarly to \\ours{} (Wilcoxon Rank-Sum Test, 0.05 Significance Level); '
     'Rank Is the Friedman Mean Rank; Ratio Is the Mean IGD Relative to \\ours{}. The Last Three Columns Describe the Trained Nodes of the Final Map: $\\rho$ Is '
     'the Spearman Correlation Between Lattice Distance and Decision-Space Distance of the Prototypes, Overlap Is the Share of Lattice Neighbors '
     'Among the Nearest Prototypes in Decision Space (Expected Value for a Random Map in Parentheses), and $\\delta$ Is the Mean Decision-Space '
     'Distance Between Adjacent Prototypes Relative to Nonadjacent Ones.}',
     '\\label{tab:anchors}', '\\footnotesize', '\\begin{tabular}{@{}lcccccc@{}}', '\\toprule',
     'Permuted & $+/-/=$ & Rank & Ratio & $\\rho$ & Overlap & $\\delta$ \\\\', '\\midrule']
for c in cfgs:
    t = [tag(G[(c,) + i], G[('g15i',) + i]) for i in inst] if c != 'g15i' else None
    w = '---' if t is None else f"{t.count('+')}/{t.count('-')}/{t.count('=')}"
    ratio = np.mean([G[(c,) + i].mean() / G[('g15i',) + i].mean() for i in inst])
    s = T[T.config == c]
    L.append(f"{lab[c]} & {w} & {rk[c]:.2f} & {ratio:.3f} & {s.rhoTopo.mean():.2f} & {s.overlap.mean():.2f} ({s.overlapNull.mean():.2f}) "
             f"& {s.ratio.mean():.2f} \\\\")
e = int(np.floor(np.log10(p)))
sci = f'{p / 10**e:.1f}\\times10^{{{e}}}'
L += ['\\bottomrule', '\\end{tabular}', '', '\\vspace{2pt}',
      f'\\parbox{{\\columnwidth}}{{\\scriptsize Friedman test: $p={sci}$.}}', '\\end{table}']
txt = '\n'.join(L).replace('& -0.00 &', '& 0.00 &') + '\n'
(TAB / 'anchors.tex').write_text(txt, encoding='utf8')
print(txt)
