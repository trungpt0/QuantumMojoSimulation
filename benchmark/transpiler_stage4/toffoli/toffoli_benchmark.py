import time
import numpy as np

from qiskit import QuantumCircuit, transpile
from qiskit.circuit.library import RCCXGate, CCXGate
from qiskit.quantum_info import Operator

WARM, REPS = 5, 200
METHODS = ["standard", "relative_phase", "t_depth"]
BASES = ["ibm", "ft", "uni"]
IBM = ["cx", "rz", "sx", "x"]
FT = ["cx", "h", "t", "tdg", "s", "sdg", "x", "y", "z"]
UNI = ["cx", "rz", "sx", "x", "h", "t", "tdg", "s", "swap"]
BASIS_GATES = {"ibm": IBM, "ft": FT, "uni": UNI}

def check(U, method, nq):
    ref = QuantumCircuit(nq)
    ref.append(CCXGate(), [0, 1, 2])
    R = Operator(ref).data
    d = 8
    U, R = U[:, :d], R[:, :d]
    if method in ("relative_phase"):
        return bool(np.allclose(np.abs(U), np.abs(R), atol=1e-8))
    ph = np.vdot(R.ravel(), U.ravel())
    if abs(ph) < 1e-12:
        return False
    ph /= abs(ph)
    return bool(np.allclose(U, ph * R, atol=1e-8))

def build_t_depth():
    qc = QuantumCircuit(3)
    qc.h(2)
    qc.t(0)
    qc.t(1)
    qc.t(2)
    qc.cx(0, 1)
    qc.cx(0, 2)
    qc.cx(1, 0)
    qc.cx(2, 0)
    qc.t(0)
    qc.tdg(1)
    qc.tdg(2)
    qc.cx(1, 2)
    qc.tdg(2)
    qc.cx(1, 2)
    qc.cx(2, 0)
    qc.cx(1, 0)
    qc.cx(0, 2)
    qc.cx(0, 1)
    qc.h(2)
    return qc

def build(method):
    qc = QuantumCircuit(3)
    if method in ("standard"):
        qc.ccx(0, 1, 2)
    elif method in ("relative_phase"):
        qc.append(RCCXGate(), [0, 1, 2])
    elif method == "t_depth":
        qc = build_t_depth()
    else:
        raise ValueError(f"Unknown method: {method}")
    return qc

def synthesize(qc, bg):
    return transpile(
        qc,
        basis_gates=bg,
        optimization_level=0,
        seed_transpiler=42,
    )

def count(qc, names):
    return sum(1 for i in qc.data if i.operation.name in names)

def depth_of(qc, only_t=False):
    qd = [0] * qc.num_qubits
    for inst in qc.data:
        qs = [qc.find_bit(q).index for q in inst.qubits]
        m = max((qd[q] for q in qs), default=0)
        is_t = inst.operation.name in ("t", "tdg")
        inc = 1 if (is_t or not only_t) else 0
        for q in qs: qd[q] = m + inc
    return max(qd, default=0)

def bench(fn):
    for _ in range(WARM): fn()
    ts = []
    for _ in range(REPS):
        t0 = time.perf_counter_ns()
        fn()
        ts.append(time.perf_counter_ns() - t0)
    return int(np.median(ts))

def main():
    print("# Qiskit Toffoli Synthesis Benchmark")
    print(f"# Timing: warm={WARM} reps={REPS} median")
    for method in METHODS:
        for basis in BASES:
            bg = BASIS_GATES[basis]
            label = f"{method}_{basis}"
            try:
                qc = synthesize(build(method), bg)
                bad = set(qc.count_ops()) - set(bg)
                if bad: raise RuntimeError(f"gate is not in basis: {sorted(bad)}")
            except Exception as e:
                print(f"# ERROR {label}: {e}")
                continue
            ns = bench(lambda: synthesize(build(method), bg)
            )
            valid = int(
                check(Operator(qc).data, method, 3))
            td = depth_of(qc, only_t=True)
            depth = depth_of(qc)
            print(
                f"RESULT {label} 2 "
                f"gates={len(qc.data)} "
                f"cx={count(qc, ('cx',))} "
                f"t={count(qc, ('t', 'tdg'))} "
                f"tdepth={td} "
                f"depth={depth} "
                f"qubits=3 valid={valid} ns={ns}"
            )
    print("# DONE")

if __name__ == "__main__":
    main()