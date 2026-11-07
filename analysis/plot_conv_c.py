"""Fig. S1: mean IGD of the nondominated solutions among the first t
evaluations (conv_c.csv, from conv_c.m), WFG3, WFG4 and WFG9 with
(m,d) = (3,10) (top) and (9,100) (bottom).
Usage: python plot_conv_c.py"""
from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
OUT = HERE / 'figures' / 'convergence_curves.pdf'
OUT.parent.mkdir(exist_ok=True)
C = pd.read_csv(H / 'conv_c.csv')
STY = {'OURS': ('TP-IM-MOEA', '#c0392b', '-'), 'PIEA': ('PIEA', '#2471a3', '--'), 'EGES': ('EGES', '#1e8449', '-.'),
       'KRVEA': ('K-RVEA', '#7d3c98', ':'), 'SSDE': ('SSDE', '#7f7f7f', (0, (5, 1, 1, 1)))}
plt.rcParams.update({'font.size': 8, 'font.family': 'serif'})
fig, axes = plt.subplots(2, 3, figsize=(7.2, 4.2))
for r, (M, D) in enumerate([(3, 10), (9, 100)]):
    for j, p in enumerate(['WFG3', 'WFG4', 'WFG9']):
        ax = axes[r, j]
        for a, (lab, col, ls) in STY.items():
            s = C[(C.alg == a) & (C.prob == p) & (C.M == M) & (C.D == D)]
            if len(s):
                ax.plot(s.t, s.IGD, color=col, ls=ls, lw=1.3, label=lab)
        ax.set_title(f'{p}, $m={M}$, $d={D}$', fontsize=8)
        ax.set_xlim(0, 300); ax.grid(alpha=0.3, lw=0.4)
        if r == 1: ax.set_xlabel('Evaluations')
        if j == 0: ax.set_ylabel('IGD')
h, l = axes[0, 0].get_legend_handles_labels()
fig.legend(h, l, loc='lower center', ncol=5, frameon=False, bbox_to_anchor=(0.5, -0.01))
fig.tight_layout(rect=(0, 0.05, 1, 1))
fig.savefig(OUT, bbox_inches='tight')
print('wrote', OUT)
end = C[C.t == 300].pivot_table(index=['prob', 'M', 'D'], columns='alg', values='IGD')
print(end.round(3).to_string())
