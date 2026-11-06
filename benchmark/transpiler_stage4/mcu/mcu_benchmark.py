import sys
import time
import numpy as np

from qiskit import QuantumCircuit
from qiskit.circuit.library import MCMTGate
from qiskit.synthesis import synth_mcmt_vchain
from qiskit.transpiler import generate_preset_pass_manager
from qiskit.quantum_info import Operator

from mcu_spec import (
    LAM, TH, NS, MODES, MAX_VERIFY, KINDS, verify_mode, check_unitary,
)

WARM = 3
REPS = 30

IBM_BASIS = ["cx", "rz", "sx", "x"]
UNI_BASIS = ["cx", "ccx", "rz", "sx", "x", "h", "t", "tdg", "s", "swap"]

def count(qc, names):
    return sum(1 for i in qc.data if i.operation.name in names)

def build(kind, mode, n):
    gate_f, k = KINDS[kind]
    if mode == "vchain" and n >= 2:
        return synth_mcmt_vchain(gate_f(), n, k)          # controls, targets, n-1 ancilla
    qc = QuantumCircuit(n + k)
    ctrls = list(range(n))
    if kind == "mcphase":
        qc.mcp(LAM, ctrls, n)
    elif kind == "mcrz":
        qc.mcrz(TH, ctrls, n)
    elif kind == "mcry":
        qc.mcry(TH, ctrls, n)
    elif kind == "mcrx":
        qc.mcrx(TH, ctrls, n)
    elif k == 1:
        qc.append(gate_f().control(n), ctrls + [n])
    else:
        qc.append(MCMTGate(gate_f(), n, k), list(range(n + k)))
    return qc

def lower(qc, pm, basis):
    out = pm.run(qc)
    bad = set(out.count_ops()) - set(basis)
    if bad:
        raise RuntimeError(f"cong ngoai basis: {sorted(bad)}")
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

def run_case(kind, mode, basis_name, basis, pm, n):
    label = f"{kind}_{mode}_{basis_name}"
    try:
        qc = lower(build(kind, mode, n), pm, basis)
    except Exception as e:
        print(f"# ERROR {label} n={n}: {e}")
        return
    ns = bench(lambda: pm.run(build(kind, mode, n)))
    nq = qc.num_qubits
    valid = -1
    if nq <= MAX_VERIFY:
        valid = int(check_unitary(Operator(qc).data, kind, n, nq, verify_mode(mode, n)))
    print(f"RESULT {label} {n}"
          f" gates={len(qc.data)}"
          f" cx={count(qc, ('cx',))}"
          f" t={count(qc, ('t', 'tdg'))}"
          f" depth={qc.depth()}"
          f" qubits={nq}"
          f" valid={valid}"
          f" ns={ns}")

def main():
    print("# Qiskit MCU Synthesis Benchmark")
    print(f"# Timing: warm={WARM} reps={REPS} median")
    pms = {
        "ibm": (IBM_BASIS, generate_preset_pass_manager(optimization_level=0, basis_gates=IBM_BASIS)),
        "uni": (UNI_BASIS, generate_preset_pass_manager(optimization_level=0, basis_gates=UNI_BASIS)),
    }
    for n in NS:
        for basis_name, (basis, pm) in pms.items():
            for mode in MODES:
                for kind in KINDS:
                    run_case(kind, mode, basis_name, basis, pm, n)
    print("# DONE")

if __name__ == "__main__":
    main()