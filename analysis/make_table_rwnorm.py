"""Table S17: normalization points of the RWMOP hypervolume (rwmop_norm.csv,
written by rescore_rwmop.m). Usage: python make_table_rwnorm.py"""
from pathlib import Path
import pandas as pd

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
TAB = HERE / 'tables'
TAB.mkdir(exist_ok=True)
R = pd.read_csv(H / 'rwmop_norm_final.csv')   # union including the final model (rescore_rwmop_final.m)
R = R.iloc[R.prob.str[5:].astype(int).argsort()]


def num(v):
    s = f'{float(v):.6g}'
    if 'e' not in s:
        return s
    m, e = s.split('e')
    return f'{m}\\times10^{{{int(e)}}}'


def vec(s):
    return '$(' + ',\\,'.join(num(v) for v in s.split()) + ')$'


L = ['\\begin{table*}[htbp]', '\\centering', '\\renewcommand{\\arraystretch}{1.1}', '\\setlength{\\tabcolsep}{4pt}',
     '\\caption{Normalization Points of the HV on RWMOP1--RWMOP35: Ideal and Nadir Points of the Feasible Nondominated Solutions in the '
     'Union of the Final Sets of All Algorithms and Runs (Six Significant Digits). RWMOP28, on Which No Algorithm Finds a Feasible Solution, '
     'Is Omitted. The Reference Point Is $(1.1,\\ldots,1.1)$ in the Normalized Space.}',
     '\\label{tab:rwmop_norm}', '\\scriptsize', '\\begin{tabular}{@{}lrll@{}}', '\\toprule',
     'Problem & Points & Ideal & Nadir \\\\', '\\midrule']
for _, r in R.iterrows():
    L.append(f'{r.prob} & {r.nPoints} & {vec(r.ideal)} & {vec(r.nadir)} \\\\')
L += ['\\bottomrule', '\\end{tabular}', '\\end{table*}']
(TAB / 'rwmop_norm.tex').write_text('\n'.join(L) + '\n', encoding='utf8')
print('wrote rwmop_norm.tex', len(R), 'problems')
