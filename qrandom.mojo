from qmath import *
from circuit import QuantumCircuit
from std.time import monotonic

struct ApplyGateLog(Copyable, Movable):
    var gate_name: String
    var q0: Int
    var q1: Int
    var theta: Float64

    def __init__(out self, gate_name: String, q0: Int, q1: Int = -1, theta: Float64 = 0.0):
        self.gate_name = gate_name
        self.q0 = q0
        self.q1 = q1
        self.theta = theta

    def __copy__(self) -> Self:
        var new_log = ApplyGateLog.__new__(ApplyGateLog)
        new_log.gate_name = self.gate_name
        new_log.q0 = self.q0
        new_log.q1 = self.q1
        new_log.theta = self.theta
        return new_log

    def __moveinit__(out self, owned other: Self):
        self.gate_name = other.gate_name
        self.q0 = other.q0
        self.q1 = other.q1
        self.theta = other.theta

def apply_random_single_qubit_gate(mut qc: QuantumCircuit, n: Int):
    var gate_random = random_int(0, 4)
    var w_random = random_int(0, n)
    var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
    if gate_random == 0: qc.X(w_random)
    elif gate_random == 1: qc.Y(w_random)
    elif gate_random == 2: qc.Z(w_random)
    elif gate_random == 3: qc.H(w_random)
    # elif gate_random == 4: qc.S(w_random)
    # elif gate_random == 5: qc.T(w_random)
    # elif gate_random == 6: qc.RX(w_random, theta_random)
    # elif gate_random == 7: qc.RY(w_random, theta_random)
    # elif gate_random == 8: qc.RZ(w_random, theta_random)
    # elif gate_random == 9: qc.P(w_random, theta_random)
    # else: qc.IP(w_random, theta_random)

def apply_random_single_qubit_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
    var gate_random = random_int(0, 4)
    var w_random = random_int(0, n)
    var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
    if gate_random == 0: qc.X(w_random); return ApplyGateLog("X", w_random)
    elif gate_random == 1: qc.Y(w_random); return ApplyGateLog("Y", w_random)
    elif gate_random == 2: qc.Z(w_random); return ApplyGateLog("Z", w_random)
    else: qc.H(w_random); return ApplyGateLog("H", w_random)
    # elif gate_random == 3: qc.H(w_random); return ApplyGateLog("H", w_random)
    # elif gate_random == 4: qc.S(w_random); return ApplyGateLog("S", w_random)
    # elif gate_random == 5: qc.T(w_random); return ApplyGateLog("T", w_random)
    # elif gate_random == 6: qc.RX(w_random, theta_random); return ApplyGateLog("RX", w_random, -1, theta_random)
    # elif gate_random == 7: qc.RY(w_random, theta_random); return ApplyGateLog("RY", w_random, -1, theta_random)
    # elif gate_random == 8: qc.RZ(w_random, theta_random); return ApplyGateLog("RZ", w_random, -1, theta_random)
    # elif gate_random == 9: qc.P(w_random, theta_random); return ApplyGateLog("P", w_random, -1, theta_random)
    # else: qc.IP(w_random, theta_random); return ApplyGateLog("IP", w_random, -1, theta_random)

def apply_random_cx_gate(mut qc: QuantumCircuit, n: Int):
    var c_random = random_int(0, n)
    var t_random = random_int(0, n)
    if c_random == t_random:
        t_random = (t_random + 1) % n
    qc.CX(c_random, t_random)

def apply_random_cx_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
    var c_random = random_int(0, n)
    var t_random = random_int(0, n)
    if c_random == t_random:
        t_random = (t_random + 1) % n
    qc.CX(c_random, t_random)
    return ApplyGateLog("CX", c_random, t_random)

def random_pauli() -> String:
    var r = random_int(0, 4)
    if r == 0:
        return "X"
    elif r == 1:
        return "Y"
    elif r == 2:
        return "Z"
    else:
        return "I"

def random_pauli_coeff(mut seed: Int, range: Float64) -> Float64:
    var v: Float64 = 0.0
    while abs(v) < 0.05:
        v = round(random_float64(seed, -range, range))
    return v