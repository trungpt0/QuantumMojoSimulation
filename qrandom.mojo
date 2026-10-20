from qmath import *
from circuit import QuantumCircuit
from std.time import monotonic
from gate_record import ApplyGateLog, ApplyUnitaryGateLog

struct ApplyRandomGateLog:
    
    @staticmethod
    def apply_random_single_qubit_gate(mut qc: QuantumCircuit, n: Int):
        var gate_random = random_int(0, 13)
        var w_random = random_int(0, n)
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        if gate_random == 0: qc.I(w_random)
        elif gate_random == 1: qc.X(w_random)
        elif gate_random == 2: qc.Y(w_random)
        elif gate_random == 3: qc.Z(w_random)
        elif gate_random == 4: qc.H(w_random)
        elif gate_random == 5: qc.S(w_random)
        elif gate_random == 6: qc.Sdg(w_random)
        elif gate_random == 7: qc.T(w_random)
        elif gate_random == 8: qc.Tdg(w_random)
        elif gate_random == 9: qc.RX(w_random, theta_random)
        elif gate_random == 10: qc.RY(w_random, theta_random)
        elif gate_random == 11: qc.RZ(w_random, theta_random)
        elif gate_random == 12: qc.P(w_random, theta_random)
        elif gate_random == 13: qc.IP(w_random, theta_random)
        elif gate_random == 14: qc.SX(w_random)
        else: qc.V(w_random)

    @staticmethod
    def apply_random_single_qubit_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var gate_random = random_int(0, 13)
        var w_random = random_int(0, n)
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        if gate_random == 0: qc.I(w_random); return ApplyGateLog("I", w_random)
        elif gate_random == 1: qc.X(w_random); return ApplyGateLog("X", w_random)
        elif gate_random == 2: qc.Y(w_random); return ApplyGateLog("Y", w_random)
        elif gate_random == 3: qc.Z(w_random); return ApplyGateLog("Z", w_random)
        elif gate_random == 4: qc.H(w_random); return ApplyGateLog("H", w_random)
        elif gate_random == 5: qc.S(w_random); return ApplyGateLog("S", w_random)
        elif gate_random == 6: qc.Sdg(w_random); return ApplyGateLog("SDG", w_random)
        elif gate_random == 7: qc.T(w_random); return ApplyGateLog("T", w_random)
        elif gate_random == 8: qc.Tdg(w_random); return ApplyGateLog("TDG", w_random)
        elif gate_random == 9: qc.RX(w_random, theta_random); return ApplyGateLog("RX", w_random, -1, theta_random)
        elif gate_random == 10: qc.RY(w_random, theta_random); return ApplyGateLog("RY", w_random, -1, theta_random)
        elif gate_random == 11: qc.RZ(w_random, theta_random); return ApplyGateLog("RZ", w_random, -1, theta_random)
        elif gate_random == 12: qc.P(w_random, theta_random); return ApplyGateLog("P", w_random, -1, theta_random)
        elif gate_random == 13: qc.IP(w_random, theta_random); return ApplyGateLog("IP", w_random, -1, theta_random)
        elif gate_random == 14: qc.SX(w_random); return ApplyGateLog("SX", w_random)
        else: qc.V(w_random); return ApplyGateLog("V", w_random)

    @staticmethod
    def apply_random_two_qubit_gate(mut qc: QuantumCircuit, n: Int):
        var gate_random = random_int(0, 1)
        var w1_random = random_int(0, n)
        var w2_random = random_int(0, n)
        if w1_random == w2_random:
            w2_random = (w2_random + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        if gate_random == 0: qc.CX(w1_random, w2_random)
        elif gate_random == 1: qc.CY(w1_random, w2_random)
        elif gate_random == 2: qc.CZ(w1_random, w2_random)
        elif gate_random == 3: qc.SWAP(w1_random, w2_random)
        elif gate_random == 4: qc.ECR(w1_random, w2_random)
        elif gate_random == 5: qc.RBS(w1_random, w2_random, theta_random)
        elif gate_random == 6: qc.CP(w1_random, w2_random, theta_random)
        elif gate_random == 7: qc.CRX(w1_random, w2_random, theta_random)
        elif gate_random == 8: qc.CRY(w1_random, w2_random, theta_random)
        else: qc.CRZ(w1_random, w2_random, theta_random)

    @staticmethod
    def apply_random_two_qubit_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var gate_random = random_int(0, 1)
        var w1_random = random_int(0, n)
        var w2_random = random_int(0, n)
        if w1_random == w2_random:
            w2_random = (w2_random + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        if gate_random == 0: qc.CX(w1_random, w2_random); return ApplyGateLog("CX", w1_random, w2_random)
        elif gate_random == 1: qc.CY(w1_random, w2_random); return ApplyGateLog("CY", w1_random, w2_random)
        elif gate_random == 2: qc.CZ(w1_random, w2_random); return ApplyGateLog("CZ", w1_random, w2_random)
        elif gate_random == 3: qc.SWAP(w1_random, w2_random); return ApplyGateLog("SWAP", w1_random, w2_random)
        elif gate_random == 4: qc.ECR(w1_random, w2_random); return ApplyGateLog("ECR", w1_random, w2_random)
        elif gate_random == 5: qc.RBS(w1_random, w2_random, theta_random); return ApplyGateLog("RBS", w1_random, w2_random, theta_random)
        elif gate_random == 6: qc.CP(w1_random, w2_random, theta_random); return ApplyGateLog("CP", w1_random, w2_random, theta_random)
        elif gate_random == 7: qc.CRX(w1_random, w2_random, theta_random); return ApplyGateLog("CRX", w1_random, w2_random, theta_random)
        elif gate_random == 8: qc.CRY(w1_random, w2_random, theta_random); return ApplyGateLog("CRY", w1_random, w2_random, theta_random)
        else: qc.CRZ(w1_random, w2_random, theta_random); return ApplyGateLog("CRZ", w1_random, w2_random, theta_random)

    @staticmethod
    def apply_random_cx_gate(mut qc: QuantumCircuit, n: Int):
        var c_random = random_int(0, n)
        var t_random = random_int(0, n)
        if c_random == t_random:
            t_random = (t_random + 1) % n
        qc.CX(c_random, t_random)

    @staticmethod
    def apply_random_cx_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var c_random = random_int(0, n)
        var t_random = random_int(0, n)
        if c_random == t_random:
            t_random = (t_random + 1) % n
        qc.CX(c_random, t_random)
        return ApplyGateLog("CX", c_random, t_random)

    @staticmethod
    def apply_random_cy_gate(mut qc: QuantumCircuit, n: Int):
        var c_random = random_int(0, n)
        var t_random = random_int(0, n)
        if c_random == t_random:
            t_random = (t_random + 1) % n
        qc.CY(c_random, t_random)

    @staticmethod
    def apply_random_cy_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var c_random = random_int(0, n)
        var t_random = random_int(0, n)
        if c_random == t_random:
            t_random = (t_random + 1) % n
        qc.CY(c_random, t_random)
        return ApplyGateLog("CY", c_random, t_random)

    @staticmethod
    def apply_random_cz_gate(mut qc: QuantumCircuit, n: Int):
        var c_random = random_int(0, n)
        var t_random = random_int(0, n)
        if c_random == t_random:
            t_random = (t_random + 1) % n
        qc.CZ(c_random, t_random)

    @staticmethod
    def apply_random_cz_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var c_random = random_int(0, n)
        var t_random = random_int(0, n)
        if c_random == t_random:
            t_random = (t_random + 1) % n
        qc.CZ(c_random, t_random)
        return ApplyGateLog("CZ", c_random, t_random)

    @staticmethod
    def apply_random_swap_gate(mut qc: QuantumCircuit, n: Int):
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        qc.SWAP(s0, s1)

    @staticmethod
    def apply_random_swap_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        qc.SWAP(s0, s1)
        return ApplyGateLog("SWAP", s0, s1)

    @staticmethod
    def apply_random_ecr_gate(mut qc: QuantumCircuit, n: Int):
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        qc.ECR(s0, s1)

    @staticmethod
    def apply_random_ecr_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        qc.ECR(s0, s1)
        return ApplyGateLog("ECR", s0, s1)

    @staticmethod
    def apply_random_rbs_gate(mut qc: QuantumCircuit, n: Int):
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.RBS(s0, s1, theta_random)

    @staticmethod
    def apply_random_rbs_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.RBS(s0, s1, theta_random)
        return ApplyGateLog("RBS", s0, s1, theta_random)

    @staticmethod
    def apply_random_cp_gate(mut qc: QuantumCircuit, n: Int):
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.CP(s0, s1, theta_random)

    @staticmethod
    def apply_random_cp_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.CP(s0, s1, theta_random)
        return ApplyGateLog("CP", s0, s1, theta_random)

    @staticmethod
    def apply_random_crx_gate(mut qc: QuantumCircuit, n: Int):
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.CRX(s0, s1, theta_random)

    @staticmethod
    def apply_random_crx_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.CRX(s0, s1, theta_random)
        return ApplyGateLog("CRX", s0, s1, theta_random)

    @staticmethod
    def apply_random_cry_gate(mut qc: QuantumCircuit, n: Int):
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.CRY(s0, s1, theta_random)

    @staticmethod
    def apply_random_rcy_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.CRY(s0, s1, theta_random)
        return ApplyGateLog("CRY", s0, s1, theta_random)

    @staticmethod
    def apply_random_crz_gate(mut qc: QuantumCircuit, n: Int):
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.CRZ(s0, s1, theta_random)

    @staticmethod
    def apply_random_crz_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var s0 = random_int(0, n)
        var s1 = random_int(0, n)
        if s0 == s1:
            s1 = (s1 + 1) % n
        var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
        qc.CRZ(s0, s1, theta_random)
        return ApplyGateLog("CRZ", s0, s1, theta_random)

    @staticmethod
    def apply_random_ccx_gate(mut qc: QuantumCircuit, n: Int):
        var c0 = random_int(0, n)
        var c1 = random_int(0, n - 1)
        if c0 >= c1:
            c1 += 1
        var t = random_int(0, n - 2)
        var lo = min(c0, c1)
        var hi = max(c0, c1)
        if t >= lo:
            t += 1
        if t >= hi:
            t += 1
        qc.CCX(c0, c1, t)

    @staticmethod
    def apply_random_ccx_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var c0 = random_int(0, n)
        var c1 = random_int(0, n - 1)
        if c0 >= c1:
            c1 += 1
        var t = random_int(0, n - 2)
        var lo = min(c0, c1)
        var hi = max(c0, c1)
        if t >= lo:
            t += 1
        if t >= hi:
            t += 1
        qc.CCX(c0, c1, t)
        return ApplyGateLog("CCX", c0, c1, t)

    @staticmethod
    def apply_random_ccy_gate(mut qc: QuantumCircuit, n: Int):
        var c0 = random_int(0, n)
        var c1 = random_int(0, n - 1)
        if c0 >= c1:
            c1 += 1
        var t = random_int(0, n - 2)
        var lo = min(c0, c1)
        var hi = max(c0, c1)
        if t >= lo:
            t += 1
        if t >= hi:
            t += 1
        qc.CCY(c0, c1, t)

    @staticmethod
    def apply_random_ccy_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var c0 = random_int(0, n)
        var c1 = random_int(0, n - 1)
        if c0 >= c1:
            c1 += 1
        var t = random_int(0, n - 2)
        var lo = min(c0, c1)
        var hi = max(c0, c1)
        if t >= lo:
            t += 1
        if t >= hi:
            t += 1
        qc.CCY(c0, c1, t)
        return ApplyGateLog("CCY", c0, c1, t)

    @staticmethod
    def apply_random_ccz_gate(mut qc: QuantumCircuit, n: Int):
        var c0 = random_int(0, n)
        var c1 = random_int(0, n - 1)
        if c0 >= c1:
            c1 += 1
        var t = random_int(0, n - 2)
        var lo = min(c0, c1)
        var hi = max(c0, c1)
        if t >= lo:
            t += 1
        if t >= hi:
            t += 1
        qc.CCZ(c0, c1, t)

    @staticmethod
    def apply_random_ccz_gate_with_log(mut qc: QuantumCircuit, n: Int) -> ApplyGateLog:
        var c0 = random_int(0, n)
        var c1 = random_int(0, n - 1)
        if c0 >= c1:
            c1 += 1
        var t = random_int(0, n - 2)
        var lo = min(c0, c1)
        var hi = max(c0, c1)
        if t >= lo:
            t += 1
        if t >= hi:
            t += 1
        qc.CCZ(c0, c1, t)
        return ApplyGateLog("CCZ", c0, c1, t)

    @staticmethod
    def apply_measure_with_log(mut qc: QuantumCircuit, w: Int) -> ApplyGateLog:
        qc.measure(w)
        return ApplyGateLog("MEASURE", w)

    @staticmethod
    def apply_measure_all_with_log(mut qc: QuantumCircuit) -> ApplyGateLog:
        qc.measure_all()
        return ApplyGateLog("MEASURE_ALL")

    @staticmethod
    def gate_with_log(gate_name: String, qubits: List[Int], params: List[Float64]) -> ApplyUnitaryGateLog:
        return ApplyUnitaryGateLog(gate_name, qubits, params)

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

def random_pauli_coeff_round(mut seed: Int, range: Float64) -> Float64:
    var v: Float64 = 0.0
    while abs(v) < 0.05:
        v = round(random_float64(seed, -range, range))
    return v

def random_pauli_coeff(mut seed: Int, range: Float64) -> Float64:
    var v: Float64 = 0.0
    v = random_float64(seed, -range, range)
    return v