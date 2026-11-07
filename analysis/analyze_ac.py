"""Phase AC, version 3, analysed as fixed in TP-IM-MOEA/docs/phase_AC_protocol.md (section 'Versao 3').
Reference of every comparison: 'gated' = X1 where the lattice has resolution H1 >= 2 (phase X on WFG
m 3-9, phase AB on DTLZ and RWMOP) and X2 where H1 = 1 (phase Y, WFG m 15/20); same seeds (runs 1-30).
H-A: gated_transport, gated_mass, gated_direct, coop3 against gated on three suites, Holm over the four
profiles within each suite. H-C: repair on RWMOP. Read-only."""
from pathlib import Path
import numpy as np, pandas as pd

HERE = Path(__file__).resolve().parent                     # analysis scripts
H = HERE.parent / 'results'                                # per-run results
exec(open(HERE / 'analyze_y.py', encoding='utf-8').read().split("KEY3 = ['prob'")[0])   # head2head, position, holm, ...

KEY3 = ['prob', 'M', 'D']
AC = pd.read_csv(H / 'c_AC.csv')
X1 = pd.read_csv(H / 'c_X1.csv'); X1 = X1[X1.config == 'X1_TPN']
Y1 = pd.read_csv(H / 'c_Y1.csv'); AB3 = pd.read_csv(H / 'c_AB3.csv')
hvab = pd.read_csv(H / 'rwmop_hv_ab.csv'); hv = pd.read_csv(H / 'rwmop_hv.csv')
C1 = pd.read_csv(H / 'c_C1.csv'); C2 = pd.read_csv(H / 'c_C2.csv'); D2 = pd.read_csv(H / 'c_D2.csv')
REF = {'AC1': X1, 'AC2': Y1, 'AC3': AB3}
G15 = {'AC1': C1[C1.config == 'g15'], 'AC2': C2[C2.config == 'g15'], 'AC3': D2[D2.config == 'g15']}
LAB = {'AC1': 'WFG m=3,6,9', 'AC2': 'WFG m=15,20', 'AC3': 'DTLZ m=3,6,9'}
PROF = ['gated_transport', 'gated_mass', 'gated_direct', 'coop3']
assert len(X1) == 1620 and len(Y1) == 1080 and len(AB3) == 900 and len(hvab) == 1050

print('H-A, cooperation against gated (+ = profile better; ratio below 1 favours the profile; 95% cluster-bootstrap CI)')
res = {}
for b in ['AC1', 'AC2', 'AC3']:
    rr = {p: head2head(AC[(AC.block == b) & (AC.config == p)], REF[b], 'IGDall', True, KEY3) for p in PROF}
    ph = holm([rr[p]['p'] for p in PROF])
    print(f'\n {LAB[b]}')
    for p, q in zip(PROF, ph):
        r = rr[p]; r['pHolm'] = q
        ms = []
        for m in sorted(REF[b].M.unique()):
            rm = head2head(AC[(AC.block == b) & (AC.config == p) & (AC.M == m)], REF[b][REF[b].M == m], 'IGDall', True, KEY3)
            r[f'hi_m{m}'] = rm['hi']; ms.append(f"m{m} {rm['wlt']} {rm['ratio']:.3f}[{rm['hi']:.3f}]")
        rg = head2head(AC[(AC.block == b) & (AC.config == p)], G15[b], 'IGDall', True, KEY3)
        print(f"  {p:<16} {r['wlt']:>9}  p={r['p']:.3g} pHolm={q:.3g} ({'profile' if r['better'] else 'gated'} ahead)  "
              f"ratio {r['ratio']:.3f} [{r['lo']:.3f}, {r['hi']:.3f}] | {' | '.join(ms)} | vs g15 {rg['wlt']} {rg['ratio']:.3f}")
        res[(b, p)] = r

print('\nAdoption rule: significantly better in >= 1 suite (pHolm < 0.05, better, CI upper < 1) and no suite or m with CI upper >= 1.03')
adopt = {}
for p in PROF:
    win = [b for b in ['AC1', 'AC2', 'AC3'] if res[(b, p)]['pHolm'] < 0.05 and res[(b, p)]['better'] and res[(b, p)]['hi'] < 1]
    bad = [f"{b}{'' if k == 'hi' else ' ' + k[3:]}" for b in ['AC1', 'AC2', 'AC3'] for k, v in res[(b, p)].items()
           if (k == 'hi' or k.startswith('hi_m')) and v >= 1.03]
    adopt[p] = bool(win) and not bad
    mean_ratio = np.exp(np.mean([np.log(res[(b, p)]['ratio']) for b in ['AC1', 'AC2', 'AC3']]))
    print(f"  {p:<16} wins in {win or '-'}; CI upper >= 1.03 in {bad or '-'}; mean ratio {mean_ratio:.3f}  ->  {'ADOPTED' if adopt[p] else 'not adopted'}")
qual = [p for p in PROF if adopt[p]]
if 'coop3' in qual: final = 'coop3'
elif qual: final = min(qual, key=lambda p: np.mean([np.log(res[(b, p)]['ratio']) for b in ['AC1', 'AC2', 'AC3']]))
else: final = None
print('DECISION H-A:', f'{final} is adopted on top of gated' if final else 'no cooperation change is adopted; the model stays gated (X1 with the ordering gate)')

# ---------------- H-C, repair on RWMOP ----------------
print('\nH-C, repair on RWMOP (reference gated = X1 of phase AB; final feasible = a feasible member in the final N)')
ref = hvab.assign(feas=(hvab.nBest > 0).astype(float))
fr = ref.groupby('prob').feas.mean()
hard = sorted(fr[fr <= 0.5].index, key=lambda s: int(s[5:])); easy = [p for p in fr.index if p not in hard]
A4 = AC[AC.block == 'AC4']
for p in ['gated_repair_global', 'gated_repair_som', 'coop3']:
    X = A4[A4.config == p]
    fx = X.groupby('prob').finalFeasible.mean()
    gain = (fx[hard] - fr[hard]) * 100
    dh = X.groupby('prob').HVnorm.mean() - ref.groupby('prob').HVnorm.mean()
    r = head2head(X, ref, 'HVnorm', False, ['prob'])
    print(f"  {p:<20} hard problems (gated feasible in <= 50% of runs):")
    print('     ' + ', '.join(f"{q} {fr[q]*100:.0f}->{fx[q]*100:.0f}%" for q in hard))
    print(f"     gain >= 10 pp in {int((gain >= 10).sum())}/{len(hard)}; mean gain {gain.mean():.1f} pp")
    print(f"     other problems: worst mean-HV change {dh[easy].min():+.4f} ({dh[easy].idxmin()}), worse than -0.01 in {int((dh[easy] < -0.01).sum())}/{len(easy)}")
    print(f"     all 35, HV against gated: {r['wlt']}  signed-rank p={r['p']:.3g} ({'profile' if r['better'] else 'gated'} ahead)")
S = A4[A4.config == 'gated_repair_som'].set_index(['prob', 'run']); G = A4[A4.config == 'gated_repair_global'].set_index(['prob', 'run'])
r = head2head(S.reset_index(), G.reset_index(), 'HVnorm', False, ['prob'])
fs = S.groupby('prob').finalFeasible.mean(); fg = G.groupby('prob').finalFeasible.mean()
print(f"  repair_som vs repair_global: HV {r['wlt']} p={r['p']:.3g} ({'som' if r['better'] else 'global'} ahead); "
      f"feasibility on the hard problems: som {fs[hard].mean()*100:.0f}%, global {fg[hard].mean()*100:.0f}%")
print('  repair generations (mean per run, hard problems): ' + ', '.join(
    f"{q} {A4[(A4.config == 'gated_repair_som') & (A4.prob == q)].repairGens.mean():.1f}" for q in hard))
print('  solve time (s, mean over RWMOP): ' + ', '.join(f"{p} {A4[A4.config == p].tSolve.mean():.1f}" for p in ['coop3', 'gated_repair_global', 'gated_repair_som']))

# ---------------- literature position ----------------
print('\nPosition against the other algorithms (analysis of the article):')
cases = [('WFG m=3,6,9', WFG, 'AC1', 'IGDall', True, lambda i: i[2] == 10, X1),
         ('WFG m=15,20', MO, 'AC2', 'IGDall', True, None, Y1),
         ('DTLZ', DT, 'AC3', 'IGDall', True, lambda i: i[2] == 10, AB3)]
for lab, base, b, val, lower, kr, gref in cases:
    for who, XX in [('gated', gref)] + [(p, AC[(AC.block == b) & (AC.config == p)]) for p in PROF]:
        o = position(base, XX.assign(alg='OURS')[COLS], val, lower, lab, kr)
        print(f"  {lab:<12} {who:<16} rank {o['rank']:5.2f}  position {o['pos']}/{o['n']}  better than {len(o['better'])}  worse than {len(o['worse'])}"
              f"{' (' + ', '.join(o['worse']) + ')' if o['worse'] else ''}")
for who, XX in [('gated', hvab)] + [(p, A4[A4.config == p]) for p in ['coop3', 'gated_repair_global', 'gated_repair_som']]:
    o = position(RW, XX.assign(alg='OURS', M=0, D=0)[['alg', 'prob', 'M', 'D', 'run', 'HVnorm']], 'HVnorm', False, 'RWMOP', None)
    print(f"  {'RWMOP':<12} {who:<20} rank {o['rank']:5.2f}  position {o['pos']}/{o['n']}  better than {len(o['better'])}  worse than {len(o['worse'])}")
