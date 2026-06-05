from qmath import random_int 
from dagcircuit import DAGCircuit
from circuit import QuantumCircuit
from gate_record import ApplyGateLog, ApplyUnitaryGateLog
from std.time import monotonic
from qrandom import ApplyRandomGateLog
from transpiler.passes.optimization import RemoveIdentityEquivalent, RemoveDiagonalGatesBeforeMeasure, InverseCancellation, CommutativeInverseCancellation, ConsolidateBlocks, Split2QUnitaries

def optimization_benchmark(nq: Int, ng: Int) raises:
    var qc = QuantumCircuit(nq)
    var seed = Int(monotonic())
    var gate_log = List[ApplyGateLog]()
    var dag_gate_log = List[ApplyUnitaryGateLog]()
    for _ in range(ng):
        var g: ApplyGateLog
        var choice = random_int(0, 2)
        if choice == 0:
            g = ApplyRandomGateLog.apply_random_single_qubit_gate_with_log(qc, nq)
        else:
            if nq == 1:
                g = ApplyRandomGateLog.apply_random_single_qubit_gate_with_log(qc, nq)
            else:
                g = ApplyRandomGateLog.apply_random_cx_gate_with_log(qc, nq)
        gate_log.append(g^)
    var out: String = ""
    var f = open("benchmark/transpiler_stage1/opt_benchmark.txt", "a")
    out += "Qubits " + String(nq) + "\n"
    for i in range(len(gate_log)):
        var g = gate_log[i].copy()
        if g.gate_name == "CX":
            out += "GateBefore " + g.gate_name + " " + String(g.q0) + " " + String(g.q1) + "\n"
        elif g.gate_name == "RX" or g.gate_name == "RY" or g.gate_name == "RZ" or g.gate_name == "P" or g.gate_name == "IP":
            out += "GateBefore " + g.gate_name + " " + String(g.q0) + " " + String(g.theta) + "\n"
        else:
            out += "GateBefore " + g.gate_name + " " + String(g.q0) + "\n" 
    var dag = DAGCircuit.from_circuit(qc)
    var pass1 = RemoveIdentityEquivalent()
    var dag1 = pass1.run(dag^)
    for i in range(len(dag1.nodes)):
        if dag1.nodes[i].type == "gate":
            var g = ApplyRandomGateLog.gate_with_log(dag1.nodes[i].gate.name, dag1.nodes[i].gate.qubit, dag1.nodes[i].gate.theta)
            dag_gate_log.append(g^)
    for i in range(len(dag_gate_log)):
        var g = dag_gate_log[i].copy()
        out += "GateAfter " + g.gate_name + " "
        for j in range(len(g.qubits)):
            out += String(g.qubits[j]) + " "
        for k in range(len(g.params)):
            out += String(g.params[k]) + " "
        out += "\n"
    f.write(out)
    f.close()

def main() raises:
    var MIN_QUBITS: Int = 1
    var MAX_QUBITS: Int = 5
    var NUM_TRIALS: Int = 10
    var f = open("benchmark/transpiler_stage1/opt_benchmark.txt", "w")
    f.close()
    for _ in range(NUM_TRIALS):
        var n = random_int(MIN_QUBITS, MAX_QUBITS + 1)
        optimization_benchmark(n, n * n)