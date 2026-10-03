import os
os.environ.setdefault("RAYON_NUM_THREADS", "1")
import ast
import math
import sys
import time
from statistics import mean, median, pstdev
import qiskit
from qiskit import QuantumCircuit
from qiskit.converters import circuit_to_dag
from qiskit.quantum_info import Operator
from qiskit.transpiler import CouplingMap, Layout, PassManager
from qiskit.transpiler.passes import (
    VF2Layout, SabreLayout, SetLayout, FullAncillaAllocation,
    EnlargeWithAncilla, ApplyLayout, SabreSwap, CheckMap,
)
from qiskit.transpiler.passes.layout.vf2_layout import VF2LayoutStopReason

PATH = sys.argv[1] if len(sys.argv) > 1 else "benchmark/transpiler_stage2/layout_benchmark.txt"
ROUTE_SEED = 42
ROUTE_TRIALS = 20
MAX_EQ_QUBITS = 10

ONE_Q   = {"H": "h", "X": "x", "Y": "y", "Z": "z", "S": "s", "SDG": "sdg",
           "T": "t", "TDG": "tdg", "SX": "sx"}
PARAM_Q = {"RX": "rx", "RY": "ry", "RZ": "rz", "P": "p"}

def parse(path):
    params, cases, cur, topo = {}, [], None, None
    for raw in open(path):
        tok = raw.split()
        if not tok:
            continue
        key = tok[0]
        if key in ("VF2Layout", "SabreLayout"):
            params[key] = {k: float(v) for k, v in zip(tok[1::2], tok[2::2])}
        elif key == "Case":
            cur = {"id": int(tok[1]), "label": tok[2], "gates": [], "topos": []}
        elif key == "Qubits":
            cur["nq"] = int(tok[1])
        elif key == "Physical":
            cur["nc"] = int(tok[1])
        elif key == "Gate":
            cur["gates"].append(tok[1:])
        elif key == "Topology":
            topo = {"name": tok[1], "n": int(tok[2]), "edges": [], "Sabre": []}
            cur["topos"].append(topo)
        elif key == "Edges":
            e = list(map(int, tok[1:]))
            topo["edges"] = list(zip(e[0::2], e[1::2]))
        elif key == "VF2":
            topo["VF2"] = ast.literal_eval(raw.split(None, 1)[1].strip())
        elif key == "VF2Eval":
            topo["VF2Eval"] = dict(zip(tok[1::2], tok[2::2]))
        elif key == "Sabre":
            _, seed, rest = raw.split(None, 2)
            lay_str, ns = rest.rsplit("Runtime_ns", 1)
            topo["Sabre"].append((int(seed), ast.literal_eval(lay_str.strip()), int(ns)))
        elif key == "EndCase":
            cases.append(cur)
    return params, cases

def build_circuit(nq, gates):
    qc = QuantumCircuit(nq)
    for g in gates:
        name = g[0]
        if name == "CX":
            qc.cx(int(g[1]), int(g[2]))
        elif name in PARAM_Q:
            getattr(qc, PARAM_Q[name])(float(g[2]), int(g[1]))
        elif name in ONE_Q:
            getattr(qc, ONE_Q[name])(int(g[1]))
        elif name in ("MEASURE", "MEASURE_ALL", "REMOVED"):
            pass
        else:
            qc.id(int(g[1]))
    return qc

def build_cm(n, edges):
    cm = CouplingMap()
    for q in range(n):
        cm.add_physical_qubit(q)
    for u, v in edges:
        cm.add_edge(u, v)
        cm.add_edge(v, u)
    return cm

def is_valid(layout, nq, n_phys):
    if layout is None or len(layout) < nq:
        return False
    v = layout[:nq]
    return len(set(v)) == nq and all(0 <= p < n_phys for p in v)

def route(qc, cm, layout):
    lay = Layout.from_intlist(list(layout[:qc.num_qubits]), *qc.qregs)
    pm = PassManager([
        SetLayout(lay), FullAncillaAllocation(cm), EnlargeWithAncilla(),
        ApplyLayout(),
        SabreSwap(cm, heuristic="decay", seed=ROUTE_SEED, trials=ROUTE_TRIALS),
    ])
    routed = pm.run(qc)
    return routed.count_ops().get("swap", 0), routed

def check_map(routed, cm):
    chk = CheckMap(cm)
    chk.run(circuit_to_dag(routed))
    return bool(chk.property_set["is_swap_mapped"])

def check_equiv(qc, routed, layout):
    n = routed.num_qubits
    if n > MAX_EQ_QUBITS:
        return None
    ref = QuantumCircuit(n)
    ref.compose(qc, qubits=list(layout[:qc.num_qubits]), inplace=True)
    for inst in routed.data:
        if inst.operation.name == "swap":
            a, b = (routed.find_bit(q).index for q in inst.qubits)
            ref.swap(a, b)
    return Operator(routed).equiv(Operator(ref))

def qiskit_vf2(qc, cm, p):
    dag = circuit_to_dag(qc)
    vf2 = VF2Layout(coupling_map=cm, seed=-1,
                    call_limit=int(p["Call_limit"]),
                    max_trials=int(p["Max_solutions"]))
    t0 = time.perf_counter_ns()
    vf2.run(dag)
    dt = time.perf_counter_ns() - t0
    found = vf2.property_set["VF2Layout_stop_reason"] == VF2LayoutStopReason.SOLUTION_FOUND
    lay = vf2.property_set["layout"]
    layout = [lay[q] for q in dag.qubits] if found and lay is not None else None
    return found, layout, dt

def qiskit_sabre(qc, cm, p, seed):
    dag = circuit_to_dag(qc)
    sabre = SabreLayout(cm, seed=seed,
                        max_iterations=int(p["Iter"]),
                        layout_trials=int(p["Trials"]),
                        swap_trials=1,
                        skip_routing=True)
    t0 = time.perf_counter_ns()
    sabre.run(dag)
    dt = time.perf_counter_ns() - t0
    lay = sabre.property_set["layout"]
    return [lay[q] for q in dag.qubits], dt

def main():
    params, cases = parse(PATH)
    sp = params["SabreLayout"]
    print(f"Qiskit {qiskit.__version__}, RAYON_NUM_THREADS={os.environ['RAYON_NUM_THREADS']}")
    print(f"Config: trials={int(sp['Trials'])} iter={int(sp['Iter'])} seeds={int(sp.get('Seeds', 1))} "
          f"| Mojo score_trials={int(sp.get('Score_trials', 1))} greedy={int(sp.get('Greedy', 0))} "
          f"refine={int(sp.get('Refine_steps', 0))} "
          f"| judge=SabreSwap(decay, seed={ROUTE_SEED}, trials={ROUTE_TRIALS})\n")
    vf2_total = vf2_mismatch = vf2_same = 0
    sab_total = sab_better_eq = 0
    sab_m_sum = sab_q_sum = 0.0
    sig_win = sig_loss = 0
    t_ratios = []
    invalid = []
    fail = {"map_M": 0, "map_Q": 0, "eq_M": 0, "eq_Q": 0, "eq_skip": 0}
    for c in cases:
        qc = build_circuit(c["nq"], c["gates"])
        for t in c["topos"]:
            tag = f'Case {c["id"]:3d} {c["label"]:<14} {t["name"]:<10}'
            cm = build_cm(t["n"], t["edges"])
            if c["nq"] > t["n"]:
                print(f"{tag} SKIP (n_virt > n_phys)")
                continue
            # VF2
            m_lay   = t["VF2"]
            m_found = t["VF2Eval"]["Perfect"] == "True"
            try:
                q_found, q_lay, q_ns = qiskit_vf2(qc, cm, params["VF2Layout"])
            except Exception as e:
                print(f"{tag} VF2 Qiskit error: {e}")
                continue
            vf2_total += 1
            ok = m_found == q_found
            same = ok and q_found and list(m_lay[:c["nq"]]) == q_lay
            vf2_mismatch += not ok
            vf2_same += same
            if m_lay and not is_valid(m_lay, c["nq"], t["n"]):
                invalid.append(f"{tag} VF2")
            print(f"{tag} VF2   found M/Q {m_found!s:>5}/{q_found!s:<5} "
                  f"{'OK ' if ok else 'MISMATCH'} same_layout={same} "
                  f"t M/Q {t['VF2Eval']['Runtime_ns']}/{q_ns} ns")
            # SABRE
            runs = t["Sabre"]
            if not runs or not runs[0][1]:
                print(f"{tag} SABRE Mojo have no layout (early return)")
                continue
            m_rs, q_rs, m_ns, q_ns_l = [], [], [], []
            for k, (seed, m_lay, m_t) in enumerate(runs):
                if not is_valid(m_lay, c["nq"], t["n"]):
                    invalid.append(f"{tag} SABRE seed {seed}")
                    continue
                q_lay, q_t = qiskit_sabre(qc, cm, sp, seed)
                m_sw, m_routed = route(qc, cm, m_lay)
                q_sw, q_routed = route(qc, cm, q_lay)
                m_rs.append(m_sw)
                q_rs.append(q_sw)
                m_ns.append(m_t)
                q_ns_l.append(q_t)
                fail["map_M"] += not check_map(m_routed, cm)
                fail["map_Q"] += not check_map(q_routed, cm)
                if k == 0:
                    m_eq = check_equiv(qc, m_routed, m_lay)
                    q_eq = check_equiv(qc, q_routed, q_lay)
                    if m_eq is None:
                        fail["eq_skip"] += 1
                    else:
                        fail["eq_M"] += not m_eq
                        fail["eq_Q"] += not q_eq
            if not m_rs:
                continue
            mm, qm = mean(m_rs), mean(q_rs)
            sm, sq = pstdev(m_rs), pstdev(q_rs)
            se = ((sm ** 2 + sq ** 2) / len(m_rs)) ** 0.5
            mark = ""
            if qm - mm > 2 * se and qm > mm:
                sig_win += 1
                mark = "  << Mojo better"
            elif mm - qm > 2 * se and mm > qm:
                sig_loss += 1
                mark = "  >> Mojo worse"
            sab_total += 1
            sab_better_eq += mm <= qm
            sab_m_sum += mm
            sab_q_sum += qm
            tm, tq = median(m_ns), median(q_ns_l)
            if tm > 0 and tq > 0:
                t_ratios.append(tm / tq)
            print(f"{tag} SABRE swaps M {mm:6.2f}±{sm:5.2f}  Q {qm:6.2f}±{sq:5.2f}  "
                  f"t(median) M/Q {tm:.0f}/{tq:.0f} ns{mark}")

    print("\n══════ SUMMARY ══════")
    print(f"VF2   : {vf2_total} runs, found-mismatch = {vf2_mismatch}, same layout = {vf2_same}")
    print(f"SABRE : {sab_total} runs, Mojo <= Qiskit (mean) = {sab_better_eq}/{sab_total}, "
          f"total swaps M/Q = {sab_m_sum:.1f}/{sab_q_sum:.1f} "
          f"= {sab_m_sum / max(sab_q_sum, 1e-9):.3f}")
    print(f"Significant diff  : Mojo better = {sig_win}, Mojo worse = {sig_loss}")
    if t_ratios:
        gm = math.exp(mean(math.log(r) for r in t_ratios))
        print(f"Runtime M/Q (geometric mean of median ratios) = {gm:.3f}")
    print(f"Map check   : Mojo FAIL = {fail['map_M']}, Qiskit FAIL = {fail['map_Q']}")
    print(f"Equivalence : Mojo FAIL = {fail['eq_M']}, Qiskit FAIL = {fail['eq_Q']}, "
          f"skipped (N > {MAX_EQ_QUBITS}) = {fail['eq_skip']}")
    print(f"Invalid Mojo layouts: {len(invalid)}")
    for s in invalid:
        print("  ", s)

if __name__ == "__main__":
    main()