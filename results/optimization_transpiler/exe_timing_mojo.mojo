from qmath import random_int 
from dagcircuit import DAGCircuit
from circuit import QuantumCircuit
from gate_record import ApplyGateLog, ApplyUnitaryGateLog
from std.time import monotonic
from qrandom import ApplyRandomGateLog
from transpiler.passes.optimization import RemoveIdentityEquivalent, RemoveDiagonalGatesBeforeMeasure, InverseCancellation, CommutativeInverseCancellation, ConsolidateBlocks

def make_random_circuit(nq: Int, ng: Int, measurement: Bool = False) raises -> QuantumCircuit:
    var qc = QuantumCircuit(nq)
    var seed = Int(monotonic())
    var gate_log = List[ApplyGateLog]()
    var g: ApplyGateLog
    for _ in range(ng):
        var choice = random_int(0,2)
        if choice == 0:
            g = ApplyRandomGateLog.apply_random_single_qubit_gate_with_log(qc, nq)
        else:
            if nq == 1:
                g = ApplyRandomGateLog.apply_random_single_qubit_gate_with_log(qc, nq)
            else:
                g = ApplyRandomGateLog.apply_random_cx_gate_with_log(qc, nq)
        gate_log.append(g^)
    if measurement:
        for i in range(nq):
            g = ApplyRandomGateLog.apply_measure_with_log(qc, i)    
            gate_log.append(g^)
    var out: String = ""
    var f = open("results/optimization_transpiler/data/circuit_data.txt", "a")
    out += "Qubits " + String(nq) + "\n"
    for i in range(len(gate_log)):
        var g = gate_log[i].copy()
        if g.gate_name == "REMOVED":
            continue
        elif g.gate_name == "CX":
            out += "Gate " + g.gate_name + " " + String(g.q0) + " " + String(g.q1) + "\n"
        elif g.gate_name == "RX" or g.gate_name == "RY" or g.gate_name == "RZ" or g.gate_name == "P" or g.gate_name == "IP":
            out += "Gate " + g.gate_name + " " + String(g.q0) + " " + String(g.theta) + "\n"
        elif g.gate_name == "MEASURE":
            out += "Gate " + g.gate_name + " " + String(g.q0) + "\n"
        elif g.gate_name == "MEASURE_ALL":
            out += "Gate " + g.gate_name + "\n"
        else:
            out += "Gate " + g.gate_name + " " + String(g.q0) + "\n"
    f.write(out)
    f.close()
    return qc^

def time_remove_identity(nq: Int, ng: Int) raises:
    comptime N_RUNS = 30
    comptime N_ITER = 500
    var total: Int = 0
    for _ in range(N_RUNS):
        qc = make_random_circuit(nq, ng, measurement=False)
        var dt = 0
        for _ in range(N_ITER):
            var dag = DAGCircuit.from_circuit(qc)
            var t0 = monotonic()
            var _ = RemoveIdentityEquivalent().run(dag^)
            var t1 = monotonic()
            dt += Int(t1 - t0)
        var dts = dt // N_ITER 
        total += dts
    var avg = total // N_RUNS
    var f = open("results/optimization_transpiler/data/exe_timing_mojo_data.txt", "a")
    f.write("RemoveIdentityEquivalent " + String(avg) + "\n")
    f.close()

def time_inverse_cancellation(nq: Int, ng: Int) raises:
    comptime N_RUNS = 30
    comptime N_ITER = 500
    var total: Int = 0
    for _ in range(N_RUNS):
        qc = make_random_circuit(nq, ng, measurement=False)
        var dt = 0
        for _ in range(N_ITER):
            var dag = DAGCircuit.from_circuit(qc)
            var t0 = monotonic()
            var _ = InverseCancellation().run(dag^)
            var t1 = monotonic()
            dt += Int(t1 - t0)
        var dts = dt // N_ITER
        total += dts
    var avg = total // N_RUNS
    var f = open("results/optimization_transpiler/data/exe_timing_mojo_data.txt", "a")
    f.write("InverseCancellation " + String(avg) + "\n")
    f.close()

def time_commutative_inverse_cancellation(nq: Int, ng: Int) raises:
    comptime N_RUNS = 30
    comptime N_ITER = 500
    var total: Int = 0
    for _ in range(N_RUNS):
        qc = make_random_circuit(nq, ng, measurement=False)
        var dt = 0
        for _ in range(N_ITER):
            var dag = DAGCircuit.from_circuit(qc)
            var t0 = monotonic()
            var _ = CommutativeInverseCancellation().run(dag^)
            var t1 = monotonic()
            dt += Int(t1 - t0)
        var dts = dt // N_ITER
        total += dts
    var avg = total // N_RUNS
    var f = open("results/optimization_transpiler/data/exe_timing_mojo_data.txt", "a")
    f.write("CommutativeInverseCancellation " + String(avg) + "\n")
    f.close()

def time_consolidate_blocks(nq: Int, ng: Int) raises:
    comptime N_RUNS = 30
    comptime N_ITER = 500
    var total: Int = 0
    for _ in range(N_RUNS):
        qc = make_random_circuit(nq, ng, measurement=False)
        var dt = 0
        for _ in range(N_ITER):
            var dag = DAGCircuit.from_circuit(qc)
            var t0 = monotonic()
            var _ = ConsolidateBlocks().run(dag^)
            var t1 = monotonic()
            dt += Int(t1 - t0)
        var dts = dt // N_ITER
        total += dts
    var avg = total // N_RUNS
    var f = open("results/optimization_transpiler/data/exe_timing_mojo_data.txt", "a")
    f.write("ConsolidateBlocks " + String(avg) + "\n")
    f.close()

def time_remove_diagonal(nq: Int, ng: Int) raises:
    comptime N_RUNS = 30
    comptime N_ITER = 500
    var total: Int = 0
    for _ in range(N_RUNS):
        qc = make_random_circuit(nq, ng, measurement=True)
        var dt = 0
        for _ in range(N_ITER):
            var dag = DAGCircuit.from_circuit(qc)
            var t0 = monotonic()
            var _ = RemoveDiagonalGatesBeforeMeasure().run(dag^)
            var t1 = monotonic()
            dt += Int(t1 - t0)
        var dts = dt // N_ITER
        total += dts
    var avg = total // N_RUNS
    var f = open("results/optimization_transpiler/data/exe_timing_mojo_data.txt", "a")
    f.write("RemoveDiagonalGatesBeforeMeasure " + String(avg) + "\n")
    f.close()

def time_all_passes(nq: Int, ng: Int) raises:
    comptime N_RUNS = 50
    comptime N_ITER = 500
    var total: Int = 0
    for _ in range(N_RUNS):
        qc = make_random_circuit(nq, ng, measurement=False)
        var dt = 0
        for _ in range(N_ITER):
            var dag = DAGCircuit.from_circuit(qc)
            var t0 = monotonic()
            var dag2 = RemoveIdentityEquivalent().run(dag^)
            var dag3 = InverseCancellation().run(dag2^)
            var dag4 = CommutativeInverseCancellation().run(dag3^)
            var _    = ConsolidateBlocks().run(dag4^)
            var t1 = monotonic()
            dt += Int(t1 - t0)
        var dts = dt // N_ITER
        total += dts
    var avg = total // N_RUNS
    var f = open("results/optimization_transpiler/data/exe_timing_mojo_data.txt", "a")
    f.write("AllOptimization " + String(avg) + "\n")
    f.close()

def main() raises:
    var f = open("results/optimization_transpiler/data/circuit_data.txt", "w")
    f.close()
    f = open("results/optimization_transpiler/data/exe_timing_mojo_data.txt", "w")
    f.close()
    var MAX_QUBITS = 15
    # print("DEBUG: nanosecond")
    # print("before")
    # var t0 = monotonic()
    # print(t0)
    # var _ = input()
    # var t1 = monotonic()
    # print(t1)
    # print("delta =", t1 - t0)
    # print("END: nanosecond")
    for nq in range(1, MAX_QUBITS + 1):
        var ng = nq * nq
        f = open("results/optimization_transpiler/data/exe_timing_mojo_data.txt", "a")
        f.write("Qubits " + String(nq) + "\n")
        f.close()
        # var qc = make_random_circuit(nq, ng, measurement=False)
        # var mqc = make_random_circuit(nq, ng, measurement=True)
        time_remove_identity(nq, ng)
        time_remove_diagonal(nq, ng)
        time_inverse_cancellation(nq, ng)
        time_commutative_inverse_cancellation(nq, ng)
        time_consolidate_blocks(nq, ng)
        time_all_passes(nq, ng)