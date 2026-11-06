import numpy as np
from qiskit import QuantumCircuit
from qiskit.circuit.library import (
    PhaseGate, RZGate, RYGate, RXGate, UGate, XGate, YGate, ZGate, HGate,
)

LAM, TH, PHI = 0.7, 0.9, 0.4
NS = [1, 2, 3, 4, 5, 6, 7, 8, 10]
MODES = ["noancilla", "vchain"]
MAX_VERIFY = 10

KINDS = {
    "mcphase": (lambda: PhaseGate(LAM), 1),
    "mcrz":    (lambda: RZGate(TH), 1),
    "mcry":    (lambda: RYGate(TH), 1),
    "mcrx":    (lambda: RXGate(TH), 1),
    "mcu":     (lambda: UGate(TH, PHI, LAM), 1),
    "mcmt_x2": (XGate, 2),
    "mcmt_y2": (YGate, 2),
    "mcmt_z2": (ZGate, 2),
    "mcmt_h2": (HGate, 2),
}

def parse_label(label):
    kind, mode, basis = label.rsplit("_", 2)
    return kind, mode, basis

def verify_mode(mode, n):
    return "clean" if mode == "vchain" and n >= 2 else "none"

def reference(kind, n, nq):
    gate_f, k = KINDS[kind]
    ref = QuantumCircuit(nq)
    cg = gate_f().control(n)
    for j in range(k):
        ref.append(cg, list(range(n)) + [n + j])
    return ref

def check_unitary(U, kind, n, nq, mode):
    from qiskit.quantum_info import Operator
    R = Operator(reference(kind, n, nq)).data
    if mode == "clean":
        d = 2 ** (n + KINDS[kind][1])
        U, R = U[:, :d], R[:, :d]
    ph = np.vdot(R.ravel(), U.ravel())
    if abs(ph) < 1e-12:
        return False
    ph /= abs(ph)
    return bool(np.allclose(U, ph * R, atol=1e-8))