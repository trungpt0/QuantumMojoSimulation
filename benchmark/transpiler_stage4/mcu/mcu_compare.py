import sys
from collections import defaultdict

import numpy as np
from qiskit import QuantumCircuit
from qiskit.quantum_info import Operator

from mcu_spec import MAX_VERIFY, parse_label, verify_mode, check_unitary

GMAP = {
    "CX": "cx", "CCX": "ccx", "SWAP": "swap",
    "H": "h", "X": "x", "Y": "y", "Z": "z",
    "S": "s", "SDG": "sdg", "T": "t", "TDG": "tdg",
    "SX": "sx", "RX": "rx", "RY": "ry", "RZ": "rz", "P": "p",
}

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
            if not line.startswith("RESULT"):
                continue
            parts = line.split()
            row = {"method": parts[1], "n_ctrl": int(parts[2])}
            for p in parts[3:]:
                if "=" in p:
                    k, v = p.split("=", 1)
                    row[k] = _num(v)
            rows.append(row)
    return rows

def parse_gates(path):
    g = defaultdict(list)
    with open(path) as f:
        for line in f:
            if not line.startswith("GATE"):
                continue
            parts = line.split()
            key = (parts[1], int(parts[2]))
            qs = [int(x) for x in parts[4:] if not x.startswith("p=")]
            ps = [float(x[2:]) for x in parts[4:] if x.startswith("p=")]
            g[key].append((parts[3], qs, ps))
    return g

def verify_mojo(rows, gates):
    for r in rows:
        key = (r["method"], r["n_ctrl"])
        nq = r["qubits"]
        if key not in gates or nq > MAX_VERIFY:
            r["valid"] = -1
            continue
        qc = QuantumCircuit(nq)
        try:
            for name, qs, ps in gates[key]:
                getattr(qc, GMAP[name])(*ps, *qs)
        except KeyError as e:
            print(f"# VERIFY WARN: gate {e} at {key}")
            r["valid"] = -2
            continue
        kind, mode, _ = parse_label(r["method"])
        r["valid"] = int(check_unitary(Operator(qc).data, kind, r["n_ctrl"], nq,
                                       verify_mode(mode, r["n_ctrl"])))

def idx(rows):
    return {(r["method"], r["n_ctrl"]): r for r in rows}

def vflag(v):
    return {1: "PASS", 0: "FAIL"}.get(v, "?")

def comparable(m, q):
    if m is None or q is None:
        return False
    if m.get("valid") == 0 or q.get("valid") == 0:
        return False
    return m.get("qubits") == q.get("qubits")

def flag(mv, qv):
    return "✅" if mv <= qv else "⚠️ " if mv <= qv * 1.2 else "❌"

def correctness_report(mi, qi):
    print("\n" + "=" * 76)
    print("CORRECTNESS")
    print("=" * 76)
    fmt = "{:<30} {:>4} {:>6} {:>7} {:>8} {:>8}"
    print(fmt.format("Label", "N", "Mojo", "Qiskit", "M-qubit", "Q-qubit"))
    print("-" * 76)
    for key in sorted(set(mi) | set(qi)):
        m, q = mi.get(key), qi.get(key)
        print(fmt.format(key[0], key[1],
                         vflag(m["valid"]) if m else "-",
                         vflag(q["valid"]) if q else "-",
                         m["qubits"] if m else "-",
                         q["qubits"] if q else "-"))

def gate_count_report(mi, qi):
    print("\n" + "=" * 106)
    print("GATE COUNT (CX-based classification)")
    print("=" * 106)
    fmt = "{:<34} {:>4} {:>8} {:>8} {:>6} {:>7} {:>7} {:>6} {:>8} {:>8} {:>6}"
    print(fmt.format("Label", "N", "M-gates", "Q-gates", "Δg",
                     "M-cx", "Q-cx", "Δcx", "M-depth", "Q-depth", "Δd"))
    print("-" * 106)
    for key in sorted(set(mi) & set(qi)):
        m, q = mi[key], qi[key]
        if not comparable(m, q):
            continue
        print(fmt.format(f"{flag(m['cx'], q['cx'])} {key[0]}", key[1],
                         m["gates"], q["gates"], f"{m['gates'] - q['gates']:+d}",
                         m["cx"], q["cx"], f"{m['cx'] - q['cx']:+d}",
                         m["depth"], q["depth"], f"{m['depth'] - q['depth']:+d}"))

def performance_report(mi, qi):
    print("\n" + "=" * 76)
    print("PERFORMANCE (median µs, synthesis + basis translation)")
    print("=" * 76)
    fmt = "{:<30} {:>4} {:>10} {:>10} {:>9}"
    print(fmt.format("Label", "N", "Mojo µs", "Qiskit µs", "Speedup"))
    print("-" * 76)
    for key in sorted(set(mi) & set(qi)):
        m, q = mi[key], qi[key]
        if not comparable(m, q) or m["ns"] <= 0 or q["ns"] <= 0:
            continue
        print(fmt.format(key[0], key[1], f"{m['ns'] / 1000:.1f}",
                         f"{q['ns'] / 1000:.1f}", f"{q['ns'] / m['ns']:.2f}x"))

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 compare_mcu.py mojo_results.txt qiskit_results.txt")
        sys.exit(1)
    mojo = parse_results(sys.argv[1])
    qiskit = parse_results(sys.argv[2])
    print(f"# Loaded {len(mojo)} Mojo rows, {len(qiskit)} Qiskit rows")
    verify_mojo(mojo, parse_gates(sys.argv[1]))
    mi, qi = idx(mojo), idx(qiskit)
    correctness_report(mi, qi)
    gate_count_report(mi, qi)
    performance_report(mi, qi)

if __name__ == "__main__":
    main()