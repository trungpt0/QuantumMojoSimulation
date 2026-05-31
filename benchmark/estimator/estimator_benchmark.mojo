from circuit import QuantumCircuit
from qmath import random_int
from qrandom import apply_random_single_qubit_gate_with_log, apply_random_cx_gate_with_log, random_pauli, random_pauli_coeff, ApplyGateLog
from primitives.estimator import SparsePauliOp, Estimator
from std.time import monotonic

def estimator_benchmark(nq: Int, ng: Int, h_terms: Int, pauli_coeff_range: Float64) raises:
    var qc = QuantumCircuit(nq)
    var seed = Int(monotonic())
    var gate_log = List[ApplyGateLog]()
    for _ in range(ng):
        var g: ApplyGateLog
        var choice = random_int(0, 2)
        if choice == 0:
            g = apply_random_single_qubit_gate_with_log(qc, nq)
        else:
            g = apply_random_cx_gate_with_log(qc, nq)
        # print("Gate:" + g.gate_name, "q1:" + String(g.q0), "q2:" + String(g.q1))
        gate_log.append(g^)
    # print("-----")
    # qc.print_psi()
    var H = List[SparsePauliOp]()
    var O_paulis = List[String]()
    var O_coeffs = List[Float64]()
    var O_terms = random_int(1, h_terms + 1)
    for _ in range(O_terms):
        var pauli: String = ""
        for _ in range(nq):
            pauli += random_pauli()
        var coeff = random_pauli_coeff(seed, pauli_coeff_range)
        # print("Pauli:", pauli, "Coeff:", coeff)
        H.append(SparsePauliOp(pauli, coeff))
        O_paulis.append(pauli)
        O_coeffs.append(coeff)
    var expected_value = Estimator().run(qc, H).expectation[0]
    var out: String = ""
    var f = open("benchmark/estimator/estimator_benchmark.txt", "a")
    out += "Qubits " + String(nq) + "\n"
    for i in range(len(gate_log)):
        var g = gate_log[i].copy()
        if g.gate_name == "CX":
            out += "Gate " + g.gate_name + " " + String(g.q0) + " " + String(g.q1) + "\n"
        elif g.gate_name == "RX" or g.gate_name == "RY" or g.gate_name == "RZ" or g.gate_name == "P" or g.gate_name == "IP":
            out += "Gate " + g.gate_name + " " + String(g.q0) + " " + String(g.theta) + "\n"
        else:
            out += "Gate " + g.gate_name + " " + String(g.q0) + "\n"
    for i in range(len(O_paulis)):
        out += "Observable " + O_paulis[i] + " " + String(O_coeffs[i]) + "\n"
    out += "Expected_value " + String(expected_value) + "\n"
    f.write(out)
    f.close()

def main() raises:
    var MIN_QUBITS: Int = 1
    var MAX_QUBITS: Int = 10
    var NUM_TRIALS: Int = 100
    var H_TERMS: Int = 5
    var PAULI_COEFF_RANGE: Float64 = 3.0
    var f = open("benchmark/estimator/estimator_benchmark.txt", "w")
    f.close()
    for _ in range(NUM_TRIALS):
        var n = random_int(MIN_QUBITS, MAX_QUBITS + 1)
        estimator_benchmark(n, n * n, H_TERMS, PAULI_COEFF_RANGE)