from gates import GateOp
from transpiler import Target, target_ibm_basis, target_clifford_t, target_universal
from transpiler import CouplingMap
from transpiler import mcx_synthesize, toffoli_standard, toffoli_relative_phase, toffoli_t_depth_optimal
from std.time import monotonic

comptime WARM = 3
comptime REPS = 50
comptime MAX_DUMP_QUBITS = 10

def count_cx(gates: List[GateOp]) -> Int:
    var c = 0
    for i in range(len(gates)):
        var name = gates[i].name
        if name == "CX" or name == "CNOT": c += 1
    return c

def count_t(gates: List[GateOp]) -> Int:
    var c = 0
    for i in range(len(gates)):
        var name = gates[i].name
        if name == "T" or name == "TDG": c += 1
    return c

def circuit_depth(gates: List[GateOp], n_qubits: Int) -> Int:
    var qubit_depth = List[Int]()
    for _ in range(n_qubits): qubit_depth.append(0)
    for gi in range(len(gates)):
        var max_d = 0
        for qi in range(len(gates[gi].qubit)):
            var q = gates[gi].qubit[qi]
            if q < n_qubits and qubit_depth[q] > max_d:
                max_d = qubit_depth[q]
        for qi in range(len(gates[gi].qubit)):
            var q = gates[gi].qubit[qi]
            if q < n_qubits:
                qubit_depth[q] = max_d + 1
    var max_depth = 0
    for i in range(n_qubits):
        if qubit_depth[i] > max_depth: max_depth = qubit_depth[i]
    return max_depth

def arity_ok(gates: List[GateOp], n_qubits: Int) -> Bool:
    for i in range(len(gates)):
        var name = gates[i].name
        var k = len(gates[i].qubit)
        for qi in range(k):
            if gates[i].qubit[qi] < 0 or gates[i].qubit[qi] >= n_qubits:
                return False
        if (name == "CX" or name == "CNOT") and k != 2: return False
        if name == "CCX" and k != 3: return False
        if (name == "H" or name == "T" or name == "TDG" or name == "RZ"
                or name == "SX" or name == "X") and k != 1:
            return False
    return True

def median(mut ts: List[Int]) -> Int:
    for i in range(1, len(ts)):
        var key = ts[i]
        var j = i - 1
        while j >= 0 and ts[j] > key:
            ts[j + 1] = ts[j]
            j -= 1
        ts[j + 1] = key
    return ts[len(ts) // 2]

def time_synth(controls: List[Int], tgt_q: Int, tgt: Target, method: String, ancilla: List[Int]) raises -> Int:
    for _ in range(WARM):
        var g = mcx_synthesize(controls, tgt_q, tgt, method, ancilla.copy())
        _ = len(g)
    var ts = List[Int]()
    for _ in range(REPS):
        var t0 = monotonic()
        var g = mcx_synthesize(controls, tgt_q, tgt, method, ancilla.copy())
        ts.append(Int(monotonic() - t0))
        _ = len(g)
    return median(ts)

def toffoli_by_name(name: String) raises -> List[GateOp]:
    if name == "standard":
        return toffoli_standard(0, 1, 2)
    elif name == "relative_phase":
        return toffoli_relative_phase(0, 1, 2)
    elif name == "t_depth":
        return toffoli_t_depth_optimal(0, 1, 2)
    raise Error("toffoli invalid method: " + name)

def time_toffoli(name: String) raises -> Int:
    for _ in range(WARM):
        var g = toffoli_by_name(name)
        _ = len(g)
    var ts = List[Int]()
    for _ in range(REPS):
        var t0 = monotonic()
        var g = toffoli_by_name(name)
        ts.append(Int(monotonic() - t0))
        _ = len(g)
    return median(ts)

def dump_gates(label: String, n_ctrl: Int, gates: List[GateOp]):
    for i in range(len(gates)):
        var s = "GATE " + label + " " + String(n_ctrl) + " " + gates[i].name
        for qi in range(len(gates[i].qubit)):
            s += " " + String(gates[i].qubit[qi])
        for pi in range(len(gates[i].theta)):
            s += " p=" + String(gates[i].theta[pi])
        print(s)

def report(label: String, n_ctrl: Int, gates: List[GateOp], n_qubits: Int, ns: Int):
    var ok = 1 if arity_ok(gates, n_qubits) else 0
    print("RESULT", label, n_ctrl,
          "gates="  + String(len(gates)),
          "cx="     + String(count_cx(gates)),
          "t="      + String(count_t(gates)),
          "depth="  + String(circuit_depth(gates, n_qubits)),
          "qubits=" + String(n_qubits),
          "arity="  + String(ok),
          "ns="     + String(ns))
    if n_qubits <= MAX_DUMP_QUBITS:
        dump_gates(label, n_ctrl, gates)

def run_case(
    label: String, 
    n_ctrl: Int, 
    controls: List[Int], 
    tgt_q: Int,
    tgt: Target, 
    method: String, 
    ancilla: List[Int],
    n_qubits: Int
) raises:
    try:
        var g  = mcx_synthesize(controls, tgt_q, tgt, method, ancilla.copy())
        var ns = time_synth(controls, tgt_q, tgt, method, ancilla)
        report(label, n_ctrl, g, n_qubits, ns)
    except e:
        print("# ERROR", label, "n=" + String(n_ctrl) + ":", e)

def main() raises:
    print("# Mojo MCX Synthesis Benchmark")
    print("# Format: RESULT method n_controls gates= cx= t= depth= qubits= arity= ns=")
    print("# Timing: warm=" + String(WARM) + " reps=" + String(REPS) + " median")
    var cm_dummy = CouplingMap(20)
    var tgt_ibm  = target_ibm_basis(20, cm_dummy)
    var tgt_ft   = target_clifford_t(20, cm_dummy)
    var tgt_uni  = target_universal(20, cm_dummy)
    for n_ctrl in [1, 2, 3, 4, 5, 6, 7, 8, 10, 12]:
        var controls = List[Int]()
        for i in range(n_ctrl): controls.append(i)
        var tgt_q = n_ctrl
        var no_anc = List[Int]()
        run_case("noancilla_ibm", n_ctrl, controls, tgt_q, tgt_ibm,
             "noancilla", no_anc, n_ctrl + 1)
        run_case("noancilla_ft", n_ctrl, controls, tgt_q, tgt_ft,
             "noancilla", no_anc, n_ctrl + 1)
        run_case("noancilla_uni", n_ctrl, controls, tgt_q, tgt_uni,
             "noancilla", no_anc, n_ctrl + 1)
        if n_ctrl <= 5:
            run_case("gray_code", n_ctrl, controls, tgt_q, tgt_ibm,
                 "gray_code", no_anc, n_ctrl + 1)
        if n_ctrl >= 3:
            var n_anc = n_ctrl - 2
            var anc_start = n_ctrl + 1
            var ancilla = List[Int]()
            for i in range(n_anc): ancilla.append(anc_start + i)
            run_case("vchain", n_ctrl, controls, tgt_q, tgt_ft,
                 "vchain", ancilla, anc_start + n_anc)
        if n_ctrl >= 3:
            var anc_r = List[Int]()
            anc_r.append(n_ctrl + 1)
            run_case("recursion", n_ctrl, controls, tgt_q, tgt_ft,
                 "recursion", anc_r, n_ctrl + 2)
    print("# SECTION: toffoli_methods")
    for name in ["standard", "relative_phase", "t_depth"]:
        var g  = toffoli_by_name(name)
        var ns = time_toffoli(name)
        report("toffoli_" + name, 2, g, 3, ns)
    print("# DONE")