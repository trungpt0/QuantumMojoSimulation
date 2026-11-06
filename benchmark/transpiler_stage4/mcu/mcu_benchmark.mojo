from gates import GateOp
from transpiler import Target, target_ibm_basis, target_custom, CouplingMap, mcmt_synthesize
from std.time import monotonic

comptime WARM = 3
comptime REPS = 30
comptime MAX_DUMP_QUBITS = 10
comptime LAM = 0.7
comptime TH = 0.9
comptime PHI = 0.4

def count_cx(gates: List[GateOp]) -> Int:
    var c = 0
    for i in range(len(gates)):
        if gates[i].name == "CX": c += 1
    return c

def count_t(gates: List[GateOp]) -> Int:
    var c = 0
    for i in range(len(gates)):
        if gates[i].name == "T" or gates[i].name == "TDG": c += 1
    return c

def circuit_depth(gates: List[GateOp], n_qubits: Int) -> Int:
    var qd = List[Int]()
    for _ in range(n_qubits): qd.append(0)
    for gi in range(len(gates)):
        var m = 0
        for qi in range(len(gates[gi].qubit)):
            var q = gates[gi].qubit[qi]
            if q < n_qubits and qd[q] > m: m = qd[q]
        for qi in range(len(gates[gi].qubit)):
            var q = gates[gi].qubit[qi]
            if q < n_qubits: qd[q] = m + 1
    var d = 0
    for i in range(n_qubits):
        if qd[i] > d: d = qd[i]
    return d

def median(mut ts: List[Int]) -> Int:
    for i in range(1, len(ts)):
        var key = ts[i]
        var j = i - 1
        while j >= 0 and ts[j] > key:
            ts[j + 1] = ts[j]
            j -= 1
        ts[j + 1] = key
    return ts[len(ts) // 2]

def dump_gates(label: String, n_ctrl: Int, gates: List[GateOp]):
    for i in range(len(gates)):
        var s = "GATE " + label + " " + String(n_ctrl) + " " + gates[i].name
        for qi in range(len(gates[i].qubit)):
            s += " " + String(gates[i].qubit[qi])
        for pi in range(len(gates[i].theta)):
            s += " p=" + String(gates[i].theta[pi])
        print(s)

def report(label: String, n_ctrl: Int, gates: List[GateOp], n_qubits: Int, ns: Int):
    print("RESULT", label, n_ctrl,
          "gates="  + String(len(gates)),
          "cx="     + String(count_cx(gates)),
          "t="      + String(count_t(gates)),
          "depth="  + String(circuit_depth(gates, n_qubits)),
          "qubits=" + String(n_qubits),
          "ns="     + String(ns))
    if n_qubits <= MAX_DUMP_QUBITS:
        dump_gates(label, n_ctrl, gates)

def run_case(label: String, n: Int, k: Int, gate: String, params: List[Float64],
             tgt: Target, method: String) raises:
    var controls = List[Int]()
    for i in range(n): controls.append(i)
    var targets = List[Int]()
    for j in range(k): targets.append(n + j)
    var n_anc = n - 1 if (method == "vchain" and n >= 2) else 0
    var ancilla = List[Int]()
    for i in range(n_anc): ancilla.append(n + k + i)
    var nq = n + k + n_anc
    try:
        var g = mcmt_synthesize(controls, targets, tgt, gate, params, method, ancilla.copy())
        for _ in range(WARM):
            var w = mcmt_synthesize(controls, targets, tgt, gate, params, method, ancilla.copy())
            _ = len(w)
        var ts = List[Int]()
        for _ in range(REPS):
            var t0 = monotonic()
            var w = mcmt_synthesize(controls, targets, tgt, gate, params, method, ancilla.copy())
            ts.append(Int(monotonic() - t0))
            _ = len(w)
        report(label, n, g, nq, median(ts))
    except e:
        print("# ERROR", label, "n=" + String(n) + ":", e)

def run_all(n: Int, tgt: Target, basis: String) raises:
    var p_lam = List[Float64]()
    p_lam.append(LAM)
    var p_th = List[Float64]()
    p_th.append(TH)
    var p_u = List[Float64]()
    p_u.append(TH)
    p_u.append(PHI)
    p_u.append(LAM)
    var none = List[Float64]()
    for method in ["noancilla", "vchain"]:
        var sfx = "_" + String(method) + "_" + basis
        run_case("mcphase" + sfx, n, 1, "P",  p_lam, tgt, method)
        run_case("mcrz" + sfx,    n, 1, "RZ", p_th,  tgt, method)
        run_case("mcry" + sfx,    n, 1, "RY", p_th,  tgt, method)
        run_case("mcrx" + sfx,    n, 1, "RX", p_th,  tgt, method)
        run_case("mcu" + sfx,     n, 1, "U",  p_u,   tgt, method)
        run_case("mcmt_x2" + sfx, n, 2, "X",  none,  tgt, method)
        run_case("mcmt_y2" + sfx, n, 2, "Y",  none,  tgt, method)
        run_case("mcmt_z2" + sfx, n, 2, "Z",  none,  tgt, method)
        run_case("mcmt_h2" + sfx, n, 2, "H",  none,  tgt, method)

def main() raises:
    print("# Mojo MCU Synthesis Benchmark")
    print("# Timing: warm=" + String(WARM) + " reps=" + String(REPS) + " median")
    var cm = CouplingMap(30)
    var tgt_ibm = target_ibm_basis(30, cm)
    var uni = List[String]()
    for g in ["CX", "CCX", "RZ", "SX", "X", "H", "T", "TDG", "S", "SWAP", "MEASURE"]:
        uni.append(g)
    var tgt_uni = target_custom(30, cm, uni)     # trùng uni_basis bên Qiskit
    for n in [1, 2, 3, 4, 5, 6, 7, 8, 10]:
        run_all(n, tgt_ibm, "ibm")
        run_all(n, tgt_uni, "uni")
    print("# DONE")