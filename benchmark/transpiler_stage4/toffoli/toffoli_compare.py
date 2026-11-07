import sys
from collections import defaultdict
from qiskit import QuantumCircuit
from qiskit.quantum_info import Operator
from toffoli_benchmark import METHODS, BASES, check

def parse_label(label):
    method, basis = label.rsplit("_", 1)
    return method, basis

GMAP = {"CX": "cx", "CCX": "ccx", "H": "h", "X": "x", "Y": "y", "Z": "z",
        "S": "s", "SDG": "sdg", "T": "t", "TDG": "tdg", "SX": "sx",
        "RZ": "rz", "P": "p"}

def _num(v):
    try:
        return int(v)
    except ValueError:
        return float(v)

def parse_results(path):
    rows = {}
    with open(path) as f:
        for line in f:
            if not line.startswith("RESULT"):
                continue
            p = line.split()
            r = {k: _num(v) for k, v in (x.split("=", 1) for x in p[3:])}
            rows[p[1]] = r
    return rows

def parse_gates(path):
    g = defaultdict(list)
    with open(path) as f:
        for line in f:
            if line.startswith("GATE"):
                p = line.split()
                qs = [int(x) for x in p[4:] if not x.startswith("p=")]
                ps = [float(x[2:]) for x in p[4:] if x.startswith("p=")]
                g[p[1]].append((p[3], qs, ps))
    return g

def verify_mojo(rows, gates):
    for label, r in rows.items():
        qc = QuantumCircuit(r["qubits"])
        try:
            for name, qs, ps in gates[label]:
                getattr(qc, GMAP[name])(*ps, *qs)
        except KeyError as e:
            print(f"# VERIFY WARN: gate {e} of {label}")
            r["valid"] = -2
            continue
        r["valid"] = int(check(Operator(qc).data, parse_label(label)[0], r["qubits"]))

def vf(v):
    return {1: "PASS", 0: "FAIL"}.get(v, "?")

def main():
    m = parse_results(sys.argv[1])
    q = parse_results(sys.argv[2])
    verify_mojo(m, parse_gates(sys.argv[1]))
    order = [f"{a}_{b}" for a in METHODS for b in BASES]
    print(f"# Loaded {len(m)} Mojo rows, {len(q)} Qiskit rows")
    print("\n" + "=" * 70)
    print("CORRECTNESS")
    print("=" * 70)
    print("{:<26} {:>6} {:>7}".format("Label", "Mojo", "Qiskit"))
    for k in order:
        if k in m or k in q:
            print("{:<26} {:>6} {:>7}".format(
                k, vf(m[k]["valid"]) if k in m else "-", vf(q[k]["valid"]) if k in q else "-"))
    print("\n" + "=" * 96)
    print("GATE COUNT (Mojo | Qiskit)")
    print("=" * 96)
    h = "{:<26} {:>12} {:>9} {:>9} {:>11} {:>11}"
    print(h.format("Label", "gates", "cx", "t", "tdepth", "depth"))
    for k in order:
        if k not in m:
            continue
        a, b = m[k], q.get(k)
        def cell(key):
            if not b: return f"{a[key]}|-"
            av, bv = a[key], b[key]
            icon = "✅" if av == bv else "❌"
            return f"{av}|{bv} {icon}"
        print(h.format(k, cell("gates"), cell("cx"), cell("t"), cell("tdepth"), cell("depth")))
    print("\n" + "=" * 66)
    print("PERFORMANCE")
    print("=" * 66)
    print("{:<26} {:>10} {:>10} {:>9}".format("Label", "Mojo us", "Qiskit us", "Speedup"))
    for k in order:
        if k in m and k in q:
            print("{:<26} {:>10.1f} {:>10.1f} {:>8.1f}x".format(
                k, m[k]["ns"] / 1000, q[k]["ns"] / 1000, q[k]["ns"] / m[k]["ns"]))

if __name__ == "__main__":
    main()