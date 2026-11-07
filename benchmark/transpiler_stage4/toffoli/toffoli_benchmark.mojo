from gates import GateOp
from std.time import monotonic

from transpiler import CouplingMap
from transpiler import Target, target_ibm_basis, target_clifford_t, target_universal
from transpiler import toffoli_synthesize

comptime WARM = 5
comptime REPS = 200

def count(gates: List[GateOp], a: String, b: String) -> Int:
    var c = 0
    for i in range(len(gates)):
        if gates[i].name == a or gates[i].name == b: c += 1
    return c

def depth_of(gates: List[GateOp], nq: Int, only_t: Bool) -> Int:
    var qd = List[Int]()
    for _ in range(nq): qd.append(0)
    for gi in range(len(gates)):
        var m = 0
        for k in range(len(gates[gi].qubit)):
            var q = gates[gi].qubit[k]
            if qd[q] > m: m = qd[q]
        var is_t = gates[gi].name == "T" or gates[gi].name == "TDG"
        var inc = 1 if (is_t or not only_t) else 0
        for k in range(len(gates[gi].qubit)):
            qd[gates[gi].qubit[k]] = m + inc
    var d = 0
    for i in range(nq):
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

def run_case(method: String, basis: String, tgt: Target) raises:
    var label = method + "_" + basis
    var anc = List[Int]()
    var nq = 3
    try:
        var g = toffoli_synthesize(0, 1, 2, tgt, method, anc.copy())
        for _ in range(WARM):
            var w = toffoli_synthesize(0, 1, 2, tgt, method, anc.copy())
            _ = len(w)
        var ts = List[Int]()
        for _ in range(REPS):
            var t0 = monotonic()
            var w = toffoli_synthesize(0, 1, 2, tgt, method, anc.copy())
            ts.append(Int(monotonic() - t0))
            _ = len(w)
        print("RESULT", label, 2,
              "gates=" + String(len(g)),
              "cx=" + String(count(g, "CX", "CX")),
              "t=" + String(count(g, "T", "TDG")),
              "tdepth=" + String(depth_of(g, nq, True)),
              "depth=" + String(depth_of(g, nq, False)),
              "qubits=" + String(nq),
              "ns=" + String(median(ts)))
        for i in range(len(g)):
            var s = "GATE " + label + " 2 " + g[i].name
            for k in range(len(g[i].qubit)):
                s += " " + String(g[i].qubit[k])
            for k in range(len(g[i].theta)):
                s += " p=" + String(g[i].theta[k])
            print(s)
    except e:
        print("# ERROR", label, ":", e)

def main() raises:
    print("# Mojo Toffoli Synthesis Benchmark")
    print("# Timing: warm=" + String(WARM) + " reps=" + String(REPS) + " median")
    var cm = CouplingMap(20)
    var tgt_ibm = target_ibm_basis(20, cm)
    var tgt_ft = target_clifford_t(20, cm)
    var tgt_uni = target_universal(20, cm)
    var methods = List[String]()
    for m in ["standard", "relative_phase", "t_depth"]:
        methods.append(String(m))
    for i in range(len(methods)):
        run_case(methods[i], "ibm", tgt_ibm)
        run_case(methods[i], "ft", tgt_ft)
        run_case(methods[i], "uni", tgt_uni)
    print("# DONE")