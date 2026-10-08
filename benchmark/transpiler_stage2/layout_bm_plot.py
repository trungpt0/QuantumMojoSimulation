import ast
import sys
import time
import os
import matplotlib.pyplot as plt
from qiskit import QuantumCircuit
from qiskit.converters import circuit_to_dag
from qiskit.quantum_info import Operator
from qiskit.transpiler import CouplingMap, Layout, PassManager
from qiskit.transpiler.passes import ( VF2Layout, SabreLayout, SetLayout, FullAncillaAllocation, EnlargeWithAncilla, ApplyLayout, SabreSwap, CheckMap)
from qiskit.transpiler.passes.layout.vf2_layout import VF2LayoutStopReason

PATH = (sys.argv[1] if len(sys.argv) > 1 else "benchmark/transpiler_stage2/layout_benchmark.txt")
ROUTE_SEED = 42
MAX_EQ_QUBITS = 10
ONE_Q = {"H": "h", "X": "x", "Y": "y", "Z": "z", "S": "s", "SDG": "sdg", "T": "t", "TDG": "tdg", "SX": "sx"}
PARAM_Q = {"RX": "rx", "RY": "ry", "RZ": "rz", "P": "p"}

def parse(path):
    params, cases, cur, topo = {}, [], None, None
    for raw in open(path):
        tok = raw.split()
        if not tok: continue
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
            getattr(qc, PARAM_Q[name])(float(g[2]),int(g[1]))
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
    return (len(set(v)) == nq and all(0 <= p < n_phys for p in v))

def est_swaps(qc, cm, layout):
    total = 0
    for inst in qc.data:
        if inst.operation.num_qubits == 2:
            a, b = (qc.find_bit(q).index for q in inst.qubits)
            d = cm.distance(layout[a], layout[b])
            total += max(d - 1, 0)
    return total

def route(qc, cm, layout):
    lay = Layout.from_intlist(list(layout[:qc.num_qubits]), *qc.qregs)
    pm = PassManager([
        SetLayout(lay),
        FullAncillaAllocation(cm),
        EnlargeWithAncilla(),
        ApplyLayout(),
        SabreSwap(
            cm,
            heuristic="decay",
            seed=ROUTE_SEED,
        ),
    ])
    routed = pm.run(qc)
    return (routed.count_ops().get("swap", 0), routed)

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

def fmt(x):
    return ("skip" if x is None else ("OK" if x else "FAIL"))

def qiskit_vf2(qc, cm, p):
    dag = circuit_to_dag(qc)
    vf2 = VF2Layout(coupling_map=cm, seed=-1, call_limit=int(p["Call_limit"]), max_trials=int(p["Max_solutions"]))
    t0 = time.perf_counter_ns()
    vf2.run(dag)
    dt = (time.perf_counter_ns()- t0)
    found = (vf2.property_set["VF2Layout_stop_reason"]== VF2LayoutStopReason.SOLUTION_FOUND)
    lay = vf2.property_set["layout"]
    layout = ([lay[q] for q in dag.qubits] if found and lay is not None else None)
    return (found, layout, dt)

def qiskit_sabre(qc, cm, p):
    dag = circuit_to_dag(qc)
    sabre = SabreLayout(cm, seed=ROUTE_SEED, max_iterations=int(p["Iter"]), layout_trials=int(p["Trials"]), swap_trials=int(p["Trials"]), skip_routing=True)
    t0 = time.perf_counter_ns()
    sabre.run(dag)
    dt = (time.perf_counter_ns()- t0)
    lay = sabre.property_set["layout"]
    return ([lay[q] for q in dag.qubits], dt)

def plot_swap_comparison(results, out_prefix):
    sabre_results = [r for r in results if r["type"] == "SABRE"]
    swap_less = sum(r["m_swaps"] < r["q_swaps"] for r in sabre_results)
    swap_equal = sum(r["m_swaps"] == r["q_swaps"] for r in sabre_results)
    swap_greater = sum(r["m_swaps"] > r["q_swaps"] for r in sabre_results)
    labels = [
        "Mojo < Qiskit",
        "Mojo = Qiskit",
        "Mojo > Qiskit",
    ]
    values = [
        swap_less,
        swap_equal,
        swap_greater,
    ]
    plt.figure(figsize=(7, 5))
    bars = plt.bar(labels, values)
    plt.ylabel("Number of cases")
    plt.title("SABRE SWAP Comparison")
    plt.grid(axis="y", alpha=0.3)
    for bar, value in zip(bars, values):
        plt.text(
            bar.get_x()
            + bar.get_width() / 2,
            value,
            str(value),
            ha="center",
            va="bottom",
        )
    plt.tight_layout()
    plt.savefig(f"{out_prefix}/swap_comparison.png", dpi=200)
    plt.close()

def plot_swap_per_case(results, out_prefix):
    sabre_results = [r for r in results if r["type"] == "SABRE"]
    x = list(range(len(sabre_results)))
    m_swaps = [r["m_swaps"]for r in sabre_results]
    q_swaps = [r["q_swaps"]for r in sabre_results]
    plt.figure(figsize=(12, 5))
    plt.plot(x, m_swaps, label="Mojo", marker="o", markersize=3)
    plt.plot(x, q_swaps, label="Qiskit", marker="x",markersize=3)
    plt.xlabel("Benchmark case")
    plt.ylabel("Routed SWAP count")
    plt.title(
        "SABRE Routed SWAP Count: "
        "Mojo vs Qiskit"
    )
    plt.legend()
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(f"{out_prefix}/swap_per_case.png", dpi=200)
    plt.close()

def plot_swap_difference(results, out_prefix):
    sabre_results = [r for r in results if r["type"] == "SABRE"]
    x = list(range(len(sabre_results)))
    swap_diff = [r["m_swaps"] - r["q_swaps"] for r in sabre_results]
    plt.figure(figsize=(12, 5))
    plt.bar(x, swap_diff)
    plt.axhline(0, linewidth=1)
    plt.xlabel("Benchmark case")
    plt.ylabel(
        "Mojo SWAPs - "
        "Qiskit SWAPs"
    )
    plt.title("SWAP Difference per Case")
    plt.grid(axis="y", alpha=0.3)
    plt.tight_layout()
    plt.savefig(f"{out_prefix}/swap_difference.png", dpi=200,)
    plt.close()

def plot_swap_scatter(results, out_prefix):
    sabre_results = [r for r in results if r["type"] == "SABRE"]
    m = [r["m_swaps"] for r in sabre_results]
    q = [r["q_swaps"] for r in sabre_results]
    max_swap = max(m + q) if (m or q) else 1
    plt.figure(figsize=(7, 7))
    plt.scatter(q, m, alpha=0.7,)
    plt.plot(
        [0, max_swap],
        [0, max_swap],
        linestyle="--",
        linewidth=1,
        label="Mojo = Qiskit",
    )
    plt.xlabel("Qiskit SWAP count")
    plt.ylabel("Mojo SWAP count")
    plt.title("SABRE SWAP Comparison")
    plt.legend()
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(f"{out_prefix}/swap_scatter.png", dpi=200)
    plt.close()

def plot_runtime(results,out_prefix):
    sabre_results = [r for r in results if r["type"] == "SABRE"]
    x = list(range(len(sabre_results)))
    m_time = [r["m_time"] for r in sabre_results]
    q_time = [r["q_time"] for r in sabre_results]
    plt.figure(figsize=(12, 5))
    plt.plot(
        x,
        m_time,
        label="Mojo",
        marker="o",
        markersize=3,
    )
    plt.plot(
        x,
        q_time,
        label="Qiskit",
        marker="x",
        markersize=3,
    )
    plt.xlabel("Benchmark case")
    plt.ylabel("Runtime (ns)")
    plt.title(
        "SABRE Layout Runtime: "
        "Mojo vs Qiskit"
    )
    plt.yscale("log")
    plt.legend()
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(f"{out_prefix}/runtime_per_case.png",dpi=200,)
    plt.close()

def plot_runtime_ratio(results, out_prefix):
    sabre_results = [r for r in results if r["type"] == "SABRE"]
    x = list(range(len(sabre_results)))
    runtime_ratio = []
    for r in sabre_results:
        if r["q_time"] > 0:
            runtime_ratio.append(
                r["m_time"]
                / r["q_time"]
            )
        else:
            runtime_ratio.append(
                float("nan")
            )
    plt.figure(figsize=(12, 5))
    plt.bar(x, runtime_ratio,)
    plt.axhline(1.0, linewidth=1, linestyle="--")
    plt.xlabel("Benchmark case")
    plt.ylabel(
        "Runtime ratio "
        "(Mojo / Qiskit)"
    )
    plt.title("SABRE Runtime Ratio")
    plt.grid(axis="y", alpha=0.3,)
    plt.tight_layout()
    plt.savefig(f"{out_prefix}/runtime_ratio.png", dpi=200,)
    plt.close()

def plot_map_check(results,out_prefix):
    sabre_results = [r for r in results if r["type"] == "SABRE"]
    map_m_pass = sum(r["map_M"] for r in sabre_results)
    map_m_fail = (len(sabre_results) - map_m_pass)
    map_q_pass = sum(r["map_Q"] for r in sabre_results)
    map_q_fail = (len(sabre_results) - map_q_pass)
    labels = ["Mojo", "Qiskit"]
    passed = [map_m_pass, map_q_pass]
    failed = [map_m_fail, map_q_fail]
    xpos = range(len(labels))
    plt.figure(figsize=(7, 5))
    plt.bar(xpos, passed, label="PASS")
    plt.bar(xpos, failed, bottom=passed, label="FAIL")
    plt.xticks(list(xpos), labels)
    plt.ylabel("Number of cases")
    plt.title("CheckMap Results")
    plt.legend()
    plt.grid(axis="y", alpha=0.3,)
    plt.tight_layout()
    plt.savefig(f"{out_prefix}/map_check.png",dpi=200,)
    plt.close()

def plot_equivalence(results, out_prefix):
    sabre_results = [r for r in results if r["type"] == "SABRE"]
    eq_m_pass = sum(r["eq_M"] is True for r in sabre_results)
    eq_m_fail = sum(r["eq_M"] is False for r in sabre_results)
    eq_q_pass = sum(r["eq_Q"] is True for r in sabre_results)
    eq_q_fail = sum(r["eq_Q"] is False for r in sabre_results)
    eq_skip = sum(r["eq_M"] is None for r in sabre_results)
    labels = ["Mojo","Qiskit"]
    passed = [eq_m_pass,eq_q_pass]
    failed = [eq_m_fail,eq_q_fail]
    skipped = [eq_skip,eq_skip]
    xpos = range(len(labels))
    plt.figure(figsize=(7, 5))
    plt.bar(
        xpos,
        passed,
        label="PASS",
    )
    plt.bar(
        xpos,
        failed,
        bottom=passed,
        label="FAIL",
    )
    plt.bar(
        xpos,
        skipped,
        bottom=[
            passed[0] + failed[0],
            passed[1] + failed[1],
        ],
        label="SKIP",
    )
    plt.xticks(list(xpos),labels)
    plt.ylabel("Number of cases")
    plt.title("Circuit Equivalence Results")
    plt.legend()
    plt.grid(axis="y",alpha=0.3)
    plt.tight_layout()
    plt.savefig(f"{out_prefix}/equivalence.png", dpi=200)
    plt.close()

def plot_results(results, out_prefix="results/layout_transpiler/images1"):
    os.makedirs(out_prefix, exist_ok=True)
    plot_swap_comparison(results, out_prefix)
    plot_swap_per_case(results, out_prefix)
    plot_swap_difference(results, out_prefix)
    plot_swap_scatter(results, out_prefix)
    plot_runtime(results, out_prefix)
    plot_runtime_ratio(results, out_prefix)
    plot_map_check(results, out_prefix)
    plot_equivalence(results, out_prefix)
    sabre_results = [r for r in results if r["type"] == "SABRE"]
    total = len(sabre_results)
    swap_less = sum(r["m_swaps"] < r["q_swaps"] for r in sabre_results)
    swap_equal = sum(r["m_swaps"] == r["q_swaps"] for r in sabre_results)
    swap_greater = sum(r["m_swaps"] > r["q_swaps"] for r in sabre_results)
    runtime_ratios = [r["m_time"] / r["q_time"] for r in sabre_results if r["q_time"] > 0]
    runtime_mean = (
        sum(runtime_ratios)
        / len(runtime_ratios)
        if runtime_ratios
        else float("nan")
    )
    map_m_pass = sum(r["map_M"] for r in sabre_results)
    map_m_fail = (total - map_m_pass)
    map_q_pass = sum(r["map_Q"] for r in sabre_results)
    map_q_fail = (total - map_q_pass)
    eq_m_pass = sum(r["eq_M"] is True for r in sabre_results)
    eq_m_fail = sum(r["eq_M"] is False for r in sabre_results)
    eq_q_pass = sum(r["eq_Q"] is True for r in sabre_results)
    eq_q_fail = sum(r["eq_Q"] is False for r in sabre_results)
    eq_skip = sum(r["eq_M"] is None for r in sabre_results)
    print()
    print("════════════════════════════════════════")
    print("             PLOT SUMMARY")
    print( "════════════════════════════════════════")
    print()
    print(f"Total SABRE cases : {total}")
    print()
    print("SWAP comparison:")
    if total > 0:
        print(
            f"  Mojo < Qiskit : "
            f"{swap_less}/{total} "
            f"({100 * swap_less / total:.2f}%)"
        )
        print(
            f"  Mojo = Qiskit : "
            f"{swap_equal}/{total} "
            f"({100 * swap_equal / total:.2f}%)"
        )
        print(
            f"  Mojo > Qiskit : "
            f"{swap_greater}/{total} "
            f"({100 * swap_greater / total:.2f}%)"
        )
    print()
    print("Map check:")
    print(
        f"  Mojo   PASS/FAIL = "
        f"{map_m_pass}/{map_m_fail}"
    )
    print(
        f"  Qiskit PASS/FAIL = "
        f"{map_q_pass}/{map_q_fail}"
    )
    print()
    print(
        "Equivalence:"
    )
    print(
        f"  Mojo   PASS/FAIL/SKIP = "
        f"{eq_m_pass}/{eq_m_fail}/{eq_skip}"
    )
    print(
        f"  Qiskit PASS/FAIL/SKIP = "
        f"{eq_q_pass}/{eq_q_fail}/{eq_skip}"
    )
    print()
    print(
        f"Runtime mean ratio M/Q = "
        f"{runtime_mean:.3f}"
    )
    print()
    print(f"Plots saved to:")
    print(f"  {out_prefix}/")
    print()
    print("Generated plots:")
    print("  1. swap_comparison.png")
    print("  2. swap_per_case.png")
    print("  3. swap_difference.png")
    print("  4. swap_scatter.png")
    print( "  5. runtime_per_case.png")
    print("  6. runtime_ratio.png")
    print("  7. map_check.png")
    print("  8. equivalence.png")

def main():
    params, cases = parse(PATH)
    vf2_total = 0
    vf2_mismatch = 0
    vf2_same = 0
    sab_total = 0
    sab_better_eq = 0
    sab_ratio = []
    invalid = []
    fail = {
        "map_M": 0,
        "map_Q": 0,
        "eq_M": 0,
        "eq_Q": 0,
        "eq_skip": 0,
    }
    results = []
    for c in cases:
        qc = build_circuit(
            c["nq"],
            c["gates"],
        )
        for t in c["topos"]:
            tag = (
                f'Case {c["id"]:3d} '
                f'{c["label"]:<14} '
                f'{t["name"]:<10}'
            )
            cm = build_cm(
                t["n"],
                t["edges"],
            )
            if c["nq"] > t["n"]:
                print(
                    f"{tag} "
                    f"SKIP "
                    f"(n_virt > n_phys)"
                )
                continue
            m_lay = t["VF2"]
            m_found = (t["VF2Eval"]["Perfect"] == "True")
            try:
                (q_found,q_lay,q_ns,) = qiskit_vf2(qc,cm,params["VF2Layout"])
            except Exception as e:
                print(
                    f"{tag} "
                    f"VF2 Qiskit error: {e}"
                )
                continue
            vf2_total += 1
            ok = (m_found == q_found)
            same = (ok and q_found and list(m_lay[:c["nq"]]) == q_lay)
            vf2_mismatch += int(not ok)
            vf2_same += int(same)
            if (m_lay and not is_valid(m_lay,c["nq"],t["n"])):
                invalid.append(f"{tag} VF2")
            print(
                f"{tag} "
                f"VF2   found M/Q "
                f"{m_found!s:>5}/"
                f"{q_found!s:<5} "
                f"{'OK ' if ok else 'MISMATCH'} "
                f"same_layout={same} "
                f"t M/Q "
                f"{t['VF2Eval']['Runtime_ns']}/"
                f"{q_ns} ns"
            )
            m_lay = t["Sabre"]
            if not m_lay:
                print(
                    f"{tag} "
                    f"SABRE Mojo have no layout "
                    f"(early return)"
                )
                continue
            if not is_valid(m_lay,c["nq"],t["n"]):
                invalid.append(f"{tag} SABRE")
                print(
                    f"{tag} "
                    f"SABRE Mojo layout "
                    f"INVALID {m_lay}")
                continue
            q_lay, q_ns = qiskit_sabre(qc,cm,params["SabreLayout"])
            m_rs, m_routed = route(qc,cm,m_lay)
            q_rs, q_routed = route(qc,cm,q_lay)
            m_es = est_swaps(qc,cm,m_lay,)
            q_es = est_swaps(qc,cm,q_lay,)
            m_map = check_map(m_routed,cm,)
            q_map = check_map(q_routed,cm,)
            m_eq = check_equiv(qc,m_routed,m_lay)
            q_eq = check_equiv(qc,q_routed,q_lay)
            fail["map_M"] += int(not m_map)
            fail["map_Q"] += int(not q_map)
            if m_eq is None:
                fail["eq_skip"] += 1
            else:
                fail["eq_M"] += int(not m_eq)
                fail["eq_Q"] += int(not q_eq)
            sab_total += 1
            sab_better_eq += int(m_rs <= q_rs)
            if q_rs > 0:
                sab_ratio.append(m_rs / q_rs)
            results.append({
                "type": "SABRE",
                "case": c["id"],
                "label": c["label"],
                "topology": t["name"],
                "n_qubits": c["nq"],
                "n_physical": t["n"],
                "m_swaps": m_rs,
                "q_swaps": q_rs,
                "m_est_swaps": m_es,
                "q_est_swaps": q_es,
                "map_M": m_map,
                "map_Q": q_map,
                "eq_M": m_eq,
                "eq_Q": q_eq,
                "m_time": int(t["SabreEval"]["Runtime_ns"]),
                "q_time": q_ns,
            })
            print(
                f"{tag} "
                f"SABRE routed_swaps "
                f"M/Q {m_rs}/{q_rs}  "
                f"est_swaps "
                f"M/Q {m_es}/{q_es}  "
                f"map M/Q "
                f"{fmt(m_map)}/"
                f"{fmt(q_map)}  "
                f"equiv M/Q "
                f"{fmt(m_eq)}/"
                f"{fmt(q_eq)}  "
                f"t M/Q "
                f"{t['SabreEval']['Runtime_ns']}/"
                f"{q_ns} ns"
            )
    print(
        "\n══════ SUMMARY ══════"
    )
    print(
        f"VF2   : "
        f"{vf2_total} runs, "
        f"found-mismatch = "
        f"{vf2_mismatch}, "
        f"same layout = "
        f"{vf2_same}"
    )
    print(
        f"SABRE : "
        f"{sab_total} runs, "
        f"Mojo <= Qiskit swaps = "
        f"{sab_better_eq}/{sab_total}",
        end="",
    )
    if sab_ratio:
        print(
            f", mean ratio M/Q = "
            f"{sum(sab_ratio) / len(sab_ratio):.3f}"
        )
    else:
        print()
    print(
        f"Map check   : "
        f"Mojo FAIL = "
        f"{fail['map_M']}, "
        f"Qiskit FAIL = "
        f"{fail['map_Q']}"
    )
    print(
        f"Equivalence : "
        f"Mojo FAIL = "
        f"{fail['eq_M']}, "
        f"Qiskit FAIL = "
        f"{fail['eq_Q']}, "
        f"skipped "
        f"(N > {MAX_EQ_QUBITS}) = "
        f"{fail['eq_skip']}"
    )
    print(
        f"Invalid Mojo layouts: "
        f"{len(invalid)}"
    )
    for s in invalid:
        print("  ", s)
    plot_results(results,
        out_prefix=(
            "results/"
            "layout_transpiler/"
            "image1"
        ),
    )

if __name__ == "__main__":
    main()