import sys
from collections import defaultdict

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    HAS_PLT = True
except ImportError:
    HAS_PLT = False

try:
    import numpy as np
    from qiskit import QuantumCircuit
    from qiskit.circuit.library import MCXGate
    from qiskit.quantum_info import Operator
    HAS_QISKIT = True
except ImportError:
    HAS_QISKIT = False

def _num(v):
    try:
        return int(v)
    except ValueError:
        try:
            return float(v)
        except ValueError:
            return v

def parse_results(path):
    rows = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line.startswith("RESULT"):
                continue
            parts = line.split()
            try:
                row = {"method": parts[1], "n_ctrl": int(parts[2])}
                for p in parts[3:]:
                    if "=" in p:
                        k, v = p.split("=", 1)
                        row[k] = _num(v)
                rows.append(row)
            except (IndexError, ValueError) as e:
                print(f"# PARSE WARN: {line[:60]} → {e}")
    return rows

def parse_gates(path):
    """GATE method n NAME q0 q1 ... [p=angle ...] → {(method, n): [(name, qubits, params)]}"""
    g = defaultdict(list)
    with open(path) as f:
        for line in f:
            if not line.startswith("GATE"):
                continue
            parts = line.split()
            key = (parts[1], int(parts[2]))
            name = parts[3]
            qs = [int(x) for x in parts[4:] if not x.startswith("p=")]
            ps = [float(x[2:]) for x in parts[4:] if x.startswith("p=")]
            g[key].append((name, qs, ps))
    return g

GMAP = {
    "CX": "cx", "CNOT": "cx", "CCX": "ccx", "SWAP": "swap",
    "H": "h", "X": "x", "Y": "y", "Z": "z",
    "S": "s", "SDG": "sdg", "T": "t", "TDG": "tdg",
    "SX": "sx", "SXDG": "sxdg", "ID": "id",
    "RX": "rx", "RY": "ry", "RZ": "rz", "P": "p",
}

def verify_mode(method):
    if method.startswith("vchain"):          return "clean"
    if method.startswith("recursion"):       return "dirty"
    if method == "toffoli_relative_phase":   return "relphase"
    return "none"

def mcx_reference(n_ctrl, n_qubits):
    ref = QuantumCircuit(n_qubits)
    ref.append(MCXGate(n_ctrl), list(range(n_ctrl + 1)))
    return Operator(ref).data

def check_unitary(U, n_ctrl, n_qubits, mode):
    R = mcx_reference(n_ctrl, n_qubits)
    if mode == "clean":
        d = 2 ** (n_ctrl + 1)
        U, R = U[:, :d], R[:, :d]
    if mode == "relphase":
        return bool(np.allclose(np.abs(U), np.abs(R), atol=1e-8))
    ph = np.vdot(R.ravel(), U.ravel())
    if abs(ph) < 1e-12:
        return False
    ph /= abs(ph)
    return bool(np.allclose(U, ph * R, atol=1e-8))

def verify_mojo(rows, gates):
    for r in rows:
        key = (r["method"], r["n_ctrl"])
        if not HAS_QISKIT or key not in gates:
            r["valid"] = -1
            continue
        nq = r["qubits"]
        qc = QuantumCircuit(nq)
        try:
            for name, qs, ps in gates[key]:
                getattr(qc, GMAP[name])(*ps, *qs)
        except KeyError as e:
            print(f"# VERIFY WARN: cổng lạ {e} ở {key}")
            r["valid"] = -2
            continue
        r["valid"] = int(check_unitary(
            Operator(qc).data, r["n_ctrl"], nq, verify_mode(r["method"])))

def idx(rows):
    return {(r["method"], r["n_ctrl"]): r for r in rows}

def vflag(v):
    return {1: "PASS", 0: "FAIL", -1: "?", -2: "?"}.get(v, "?")

def correctness_report(mojo, qiskit):
    print("\n" + "=" * 70)
    print("CORRECTNESS (unitary vs MCX)")
    print("=" * 70)
    mi, qi = idx(mojo), idx(qiskit)
    fmt = "{:<26} {:>4} {:>8} {:>8} {:>8} {:>8}"
    print(fmt.format("Method", "N", "Mojo", "Qiskit", "M-qubit", "Q-qubit"))
    print("-" * 70)
    for key in sorted(set(mi) | set(qi)):
        m, q = mi.get(key), qi.get(key)
        print(fmt.format(
            key[0], key[1],
            vflag(m["valid"]) if m else "-",
            vflag(q["valid"]) if q else "-",
            m["qubits"] if m else "-",
            q["qubits"] if q else "-",
        ))

def comparable(m, q):
    if m is None or q is None:
        return False
    if m.get("valid") == 0 or q.get("valid") == 0:
        return False
    return m.get("qubits") == q.get("qubits")

def flag(mv, qv):
    return "✅" if mv <= qv else "⚠️ " if mv <= qv * 1.2 else "❌"

def gate_count_report(mojo, qiskit):
    mi, qi = idx(mojo), idx(qiskit)
    print("\n" + "=" * 100)
    print("GATE COUNT (flagged by CX; comparable rows only)")
    print("=" * 100)
    fmt = "{:<28} {:>4} {:>8} {:>8} {:>6} {:>8} {:>8} {:>6} {:>8} {:>8} {:>6}"
    print(fmt.format("Method", "N", "M-gates", "Q-gates", "Δgates",
                     "M-cx", "Q-cx", "Δcx", "M-depth", "Q-depth", "Δdepth"))
    print("-" * 100)
    for key in sorted(set(mi) & set(qi)):
        m, q = mi[key], qi[key]
        if not comparable(m, q):
            continue
        print(fmt.format(
            f"{flag(m['cx'], q['cx'])} {key[0]}", key[1],
            m["gates"], q["gates"], f"{m['gates'] - q['gates']:+d}",
            m["cx"], q["cx"], f"{m['cx'] - q['cx']:+d}",
            m["depth"], q["depth"], f"{m['depth'] - q['depth']:+d}",
        ))

def t_count_report(mojo, qiskit):
    mi, qi = idx(mojo), idx(qiskit)
    print("\n" + "=" * 70)
    print("T-GATE COUNT")
    print("=" * 70)
    fmt = "{:<28} {:>4} {:>8} {:>8} {:>6}"
    print(fmt.format("Method", "N", "Mojo-T", "Qiskit-T", "Δ"))
    print("-" * 70)
    for key in sorted(set(mi) & set(qi)):
        m, q = mi[key], qi[key]
        if not comparable(m, q) or (m["t"] == 0 and q["t"] == 0):
            continue
        print(fmt.format(f"{flag(m['t'], q['t'])} {key[0]}", key[1],
                         m["t"], q["t"], f"{m['t'] - q['t']:+d}"))

def performance_report(mojo, qiskit):
    mi, qi = idx(mojo), idx(qiskit)
    print("\n" + "=" * 70)
    print("PERFORMANCE (median µs, synthesis + basis lowering)")
    print("=" * 70)
    fmt = "{:<28} {:>4} {:>10} {:>10} {:>9}"
    print(fmt.format("Method", "N", "Mojo µs", "Qiskit µs", "Speedup"))
    print("-" * 70)
    for key in sorted(set(mi) & set(qi)):
        m, q = mi[key], qi[key]
        if not comparable(m, q):
            continue
        if m["ns"] <= 0 or q["ns"] <= 0:
            continue
        print(fmt.format(key[0], key[1],
                         f"{m['ns'] / 1000:.1f}", f"{q['ns'] / 1000:.1f}",
                         f"{q['ns'] / m['ns']:.2f}x"))

def plot_comparison(mojo, qiskit):
    if not HAS_PLT:
        return
    def get_series(rows, method, metric):
        pts = {r["n_ctrl"]: r.get(metric, 0) for r in rows
               if r["method"] == method and r.get("valid") != 0}
        xs = sorted(pts)
        return xs, [pts[x] for x in xs]
    methods = ["noancilla_ibm", "noancilla_ft", "vchain", "recursion", "gray_code"]
    metrics = [("cx", "CX count"), ("depth", "Circuit depth"),
               ("t", "T-gate count"), ("ns", "Runtime (ns)")]
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle("MCX Synthesis: Mojo vs Qiskit", fontsize=14)
    axes = axes.flatten()
    colors_m = ["#1f77b4", "#d62728", "#2ca02c", "#ff7f0e", "#9467bd"]
    colors_q = ["#aec7e8", "#f7b6d2", "#98df8a", "#ffbb78", "#c5b0d5"]
    for ai, (metric, ylabel) in enumerate(metrics):
        ax = axes[ai]
        for mi, method in enumerate(methods):
            xs_m, ys_m = get_series(mojo, method, metric)
            xs_q, ys_q = get_series(qiskit, method, metric)
            if xs_m:
                ax.plot(xs_m, ys_m, marker="o", color=colors_m[mi],
                        label=f"Mojo {method}", linewidth=1.5)
            if xs_q:
                ax.plot(xs_q, ys_q, marker="s", color=colors_q[mi],
                        linestyle="--", label=f"Qiskit {method}", linewidth=1.5)
        ax.set_xlabel("n_controls")
        ax.set_ylabel(ylabel)
        ax.set_title(ylabel)
        ax.grid(True, ls=":", alpha=0.4)
        if ai == 0:
            ax.legend(fontsize=6, ncol=2)
        if metric == "ns":
            ax.set_yscale("log")
    plt.tight_layout()
    # plt.savefig("compare_mcx.png", dpi=130, bbox_inches="tight")
    # print("\n[Chart saved to compare_mcx.png]")

def plot_methods_n5(mojo, qiskit):
    if not HAS_PLT:
        return
    methods = ["noancilla_ibm", "vchain", "recursion", "gray_code"]
    metrics = ["cx", "t", "depth"]
    n_target = 5
    def vals(rows):
        d = {mt: {k: 0 for k in metrics} for mt in methods}
        for r in rows:
            if r["n_ctrl"] == n_target and r["method"] in methods and r.get("valid") != 0:
                for k in metrics:
                    d[r["method"]][k] = r.get(k, 0)
        return d
    m_vals, q_vals = vals(mojo), vals(qiskit)
    fig, axes = plt.subplots(1, 3, figsize=(14, 5))
    fig.suptitle(f"MCX Method Comparison (n_controls={n_target})", fontsize=13)
    x = range(len(methods))
    w = 0.35
    for ai, metric in enumerate(metrics):
        ax = axes[ai]
        ax.bar([xi - w / 2 for xi in x], [m_vals[m][metric] for m in methods],
               w, label="Mojo", color="#1f77b4")
        ax.bar([xi + w / 2 for xi in x], [q_vals[m][metric] for m in methods],
               w, label="Qiskit", color="#aec7e8")
        ax.set_xticks(list(x))
        ax.set_xticklabels(methods, rotation=20, ha="right", fontsize=8)
        ax.set_title(metric.upper())
        ax.set_ylabel("count")
        ax.legend(fontsize=8)
        ax.grid(True, ls=":", alpha=0.4, axis="y")
    plt.tight_layout()
    # plt.savefig("compare_mcx_n5.png", dpi=130, bbox_inches="tight")
    # print("[Chart saved to compare_mcx_n5.png]")

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 compare_mcx.py mojo_results.txt qiskit_results.txt")
        sys.exit(1)
    mojo_rows   = parse_results(sys.argv[1])
    qiskit_rows = parse_results(sys.argv[2])
    print(f"# Loaded {len(mojo_rows)} Mojo rows, {len(qiskit_rows)} Qiskit rows")
    if not HAS_QISKIT:
        print("# WARN: Qiskit is unavailable; skipping Mojo verification")
    verify_mojo(mojo_rows, parse_gates(sys.argv[1]))
    correctness_report(mojo_rows, qiskit_rows)
    gate_count_report(mojo_rows, qiskit_rows)
    t_count_report(mojo_rows, qiskit_rows)
    performance_report(mojo_rows, qiskit_rows)
    if HAS_PLT:
        plot_comparison(mojo_rows, qiskit_rows)
        plot_methods_n5(mojo_rows, qiskit_rows)
    else:
        print("\n# pip install matplotlib")

if __name__ == "__main__":
    main()