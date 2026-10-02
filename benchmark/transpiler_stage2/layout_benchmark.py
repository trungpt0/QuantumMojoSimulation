import ast
import sys
import time

from qiskit import QuantumCircuit
from qiskit.converters import circuit_to_dag
from qiskit.transpiler import CouplingMap, Layout, PassManager
from qiskit.transpiler.passes import (
    VF2Layout, SabreLayout, SetLayout, FullAncillaAllocation,
    EnlargeWithAncilla, ApplyLayout, SabreSwap,
)
from qiskit.transpiler.passes.layout.vf2_layout import VF2LayoutStopReason

PATH = sys.argv[1] if len(sys.argv) > 1 else "benchmark/transpiler_stage2/layout_benchmark.txt"
ROUTE_SEED = 42

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
            topo = {"name": tok[1], "n": int(tok[2]), "edges": []}
            cur["topos"].append(topo)
        elif key == "Edges":
            e = list(map(int, tok[1:]))
            topo["edges"] = list(zip(e[0::2], e[1::2]))
        elif key in ("VF2", "Sabre"):
            topo[key] = ast.literal_eval(raw.split(None, 1)[1].strip())
        elif key in ("VF2Eval", "SabreEval"):
            topo[key] = dict(zip(tok[1::2], tok[2::2]))
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

def est_swaps(qc, cm, layout):
    total = 0
    for inst in qc.data:
        if inst.operation.num_qubits == 2:
            a, b = (qc.find_bit(q).index for q in inst.qubits)
            d = cm.distance(layout[a], layout[b])
            total += max(d - 1, 0)
    return total

def routed_swaps(qc, cm, layout):
    lay = Layout.from_intlist(list(layout[:qc.num_qubits]), *qc.qregs)
    pm = PassManager([
        SetLayout(lay), FullAncillaAllocation(cm), EnlargeWithAncilla(),
        ApplyLayout(), SabreSwap(cm, heuristic="decay", seed=ROUTE_SEED),
    ])
    return pm.run(qc).count_ops().get("swap", 0)

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

def qiskit_sabre(qc, cm, p):
    dag = circuit_to_dag(qc)
    sabre = SabreLayout(cm, seed=ROUTE_SEED,
                        max_iterations=int(p["Iter"]),
                        layout_trials=int(p["Trials"]),
                        swap_trials=int(p["Trials"]),
                        skip_routing=True)
    t0 = time.perf_counter_ns()
    sabre.run(dag)
    dt = time.perf_counter_ns() - t0
    lay = sabre.property_set["layout"]
    return [lay[q] for q in dag.qubits], dt

def main():
    params, cases = parse(PATH)
    vf2_total = vf2_mismatch = vf2_same = 0
    sab_total = sab_better_eq = 0
    sab_ratio = []
    invalid = []
    for c in cases:
        qc = build_circuit(c["nq"], c["gates"])
        for t in c["topos"]:
            tag = f'Case {c["id"]:3d} {c["label"]:<14} {t["name"]:<10}'
            cm = build_cm(t["n"], t["edges"])
            if c["nq"] > t["n"]:
                print(f"{tag} SKIP (n_virt > n_phys)")
                continue
            # ── VF2 ──
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
            # ── SABRE ──
            m_lay = t["Sabre"]
            if not m_lay:
                print(f"{tag} SABRE Mojo have no layout (early return)")
                continue
            if not is_valid(m_lay, c["nq"], t["n"]):
                invalid.append(f"{tag} SABRE")
                print(f"{tag} SABRE Mojo layout INVALID {m_lay}")
                continue
            q_lay, q_ns = qiskit_sabre(qc, cm, params["SabreLayout"])
            m_rs, q_rs = routed_swaps(qc, cm, m_lay), routed_swaps(qc, cm, q_lay)
            m_es, q_es = est_swaps(qc, cm, m_lay), est_swaps(qc, cm, q_lay)
            sab_total += 1
            sab_better_eq += m_rs <= q_rs
            if q_rs > 0:
                sab_ratio.append(m_rs / q_rs)
            print(f"{tag} SABRE routed_swaps M/Q {m_rs}/{q_rs}  est_swaps M/Q {m_es}/{q_es}  "
                  f"t M/Q {t['SabreEval']['Runtime_ns']}/{q_ns} ns")
    print("\n══════ SUMMARY ══════")
    print(f"VF2   : {vf2_total} runs, found-mismatch = {vf2_mismatch}, same layout = {vf2_same}")
    print(f"SABRE : {sab_total} runs, Mojo <= Qiskit swaps = {sab_better_eq}/{sab_total}", end="")
    if sab_ratio:
        print(f", mean ratio M/Q = {sum(sab_ratio) / len(sab_ratio):.3f}")
    else:
        print()
    print(f"Invalid Mojo layouts: {len(invalid)}")
    for s in invalid:
        print("  ", s)

if __name__ == "__main__":
    main()