import sys
import time

try:
    import numpy as np
    from qiskit import QuantumCircuit
    from qiskit.circuit.library import MCXGate, RCCXGate
    from qiskit.transpiler import PassManager
    from qiskit.transpiler.passes import HighLevelSynthesis, BasisTranslator
    from qiskit.circuit.equivalence_library import SessionEquivalenceLibrary as SEL
    from qiskit.quantum_info import Operator
    from qiskit.synthesis import (
        synth_mcx_noaux_v24, synth_mcx_gray_code,
        synth_mcx_n_clean_m15, synth_mcx_1_clean_b95,
    )
except ImportError as e:
    print(f"# ERROR: {e}")
    sys.exit(1)

try:
    from qiskit.synthesis import synth_mcx_1_dirty_kg24
    HAS_DIRTY = True
except ImportError:
    HAS_DIRTY = False

WARM = 3
REPS = 50
MAX_VERIFY_QUBITS = 10

def count_cx(qc):
    return sum(1 for i in qc.data if i.operation.name in ("cx", "cnot", "ecr"))

def count_t(qc):
    return sum(1 for i in qc.data if i.operation.name in ("t", "tdg"))

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

_PM = {}

def get_pm(basis):
    key = tuple(basis)
    if key not in _PM:
        _PM[key] = PassManager([
            HighLevelSynthesis(basis_gates=basis),
            BasisTranslator(SEL, basis),
        ])
    return _PM[key]

def lower(qc, basis):
    out = get_pm(basis).run(qc)
    bad = set(out.count_ops()) - set(basis)
    if bad:
        raise RuntimeError(f"Gate(s) outside the basis: {sorted(bad)}")
    return out

def bench(fn):
    for _ in range(WARM):
        fn()
    ts = []
    for _ in range(REPS):
        t0 = time.perf_counter_ns()
        fn()
        ts.append(time.perf_counter_ns() - t0)
    return int(np.median(ts))

def run_case(label, n_ctrl, build, basis, mode):
    try:
        qc = lower(build(n_ctrl), basis)
    except Exception as e:
        print(f"# ERROR {label} n={n_ctrl}: {e}")
        return
    pm = get_pm(basis)
    ns = bench(lambda: pm.run(build(n_ctrl)))
    nq = qc.num_qubits
    valid = -1
    if nq <= MAX_VERIFY_QUBITS:
        valid = int(check_unitary(Operator(qc).data, n_ctrl, nq, mode))
    print(f"RESULT {label} {n_ctrl}"
          f" gates={len(qc.data)}"
          f" cx={count_cx(qc)}"
          f" t={count_t(qc)}"
          f" depth={qc.depth()}"
          f" qubits={nq}"
          f" valid={valid}"
          f" ns={ns}")

def _small(n_ctrl):
    qc = QuantumCircuit(n_ctrl + 1)
    qc.append(MCXGate(n_ctrl), list(range(n_ctrl + 1)))
    return qc

def build_noancilla(n_ctrl):
    return _small(n_ctrl) if n_ctrl <= 2 else synth_mcx_noaux_v24(n_ctrl)

def build_gray(n_ctrl):
    return _small(n_ctrl) if n_ctrl <= 1 else synth_mcx_gray_code(n_ctrl)

def build_vchain(n_ctrl):
    return synth_mcx_n_clean_m15(n_ctrl)

def build_recursion(n_ctrl):
    if HAS_DIRTY:
        return synth_mcx_1_dirty_kg24(n_ctrl)
    return synth_mcx_1_clean_b95(n_ctrl)

def build_toffoli(method):
    qc = QuantumCircuit(3)
    if method == "standard":
        qc.ccx(0, 1, 2)
    elif method == "relative_phase":
        qc.append(RCCXGate(), [0, 1, 2])
    return qc

def main():
    print("# Qiskit MCX Synthesis Benchmark")
    print("# Format: RESULT method n_controls gates= cx= t= depth= qubits= valid= ns=")
    print(f"# Timing: warm={WARM} reps={REPS} median")
    if not HAS_DIRTY:
        print("# NOTE: synth_mcx_1_dirty_kg24 is unavailable; recursion uses a clean ancilla (b95)")
    ibm_basis = ["cx", "rz", "sx", "x"]
    ft_basis  = ["cx", "h", "t", "tdg", "s", "sdg", "x", "y", "z"]
    uni_basis = ["cx", "ccx", "rz", "sx", "x", "h", "t", "tdg", "s", "swap"]
    rec_mode  = "dirty" if HAS_DIRTY else "clean"
    for n in [1, 2, 3, 4, 5, 6, 7, 8, 10, 12]:
        run_case("noancilla_ibm", n, build_noancilla, ibm_basis, "none")
        run_case("noancilla_ft",  n, build_noancilla, ft_basis,  "none")
        run_case("noancilla_uni", n, build_noancilla, uni_basis, "none")
        if n <= 5:
            run_case("gray_code", n, build_gray, ibm_basis, "none")
        if n >= 3:
            run_case("vchain",    n, build_vchain,    ft_basis, "clean")
            run_case("recursion", n, build_recursion, ft_basis, rec_mode)
    print("# SECTION: toffoli_methods")
    run_case("toffoli_standard", 2,
             lambda _: build_toffoli("standard"), ft_basis, "none")
    run_case("toffoli_relative_phase", 2,
             lambda _: build_toffoli("relative_phase"), ft_basis, "relphase")
    print("# SKIP toffoli_t_depth: no equivalent implementation available in Qiskit")
    print("# DONE")

if __name__ == "__main__":
    main()