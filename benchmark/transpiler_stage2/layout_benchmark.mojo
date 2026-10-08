from qmath import random_int 
from dagcircuit import DAGCircuit
from circuit import QuantumCircuit
from gate_record import ApplyGateLog
from std.time import monotonic
from qrandom import ApplyRandomGateLog
from transpiler import CouplingMap, VF2Layout, SabreLayout

def gate_line(g: ApplyGateLog) -> String:
    if g.gate_name == "REMOVED":
        return ""
    elif g.gate_name == "CX":
        return "Gate CX " + String(g.q0) + " " + String(g.q1) + "\n"
    elif g.gate_name == "RX" or g.gate_name == "RY" or g.gate_name == "RZ" or g.gate_name == "P" or g.gate_name == "IP":
        return "Gate " + g.gate_name + " " + String(g.q0) + " " + String(g.theta) + "\n"
    elif g.gate_name == "MEASURE":
        return "Gate MEASURE " + String(g.q0) + "\n"
    elif g.gate_name == "MEASURE_ALL":
        return "Gate MEASURE_ALL\n"
    else:
        return "Gate " + g.gate_name + " " + String(g.q0) + "\n"

def grid_map(nc: Int) -> CouplingMap:
    var cols = 1
    while cols * cols < nc:
        cols += 1
    var rows = (nc + cols - 1) // cols
    var cm = CouplingMap(rows * cols)
    for r in range(rows):
        for c in range(cols):
            var idx = r * cols + c
            if c + 1 < cols: cm.add_edge(idx, idx + 1)
            if r + 1 < rows: cm.add_edge(idx, idx + cols)
    return cm^

def build_topologies(nq: Int, nc: Int, mut cms: List[CouplingMap], mut names: List[String]):
    cms.append(CouplingMap.linear(nc))
    names.append("Linear")
    if nc >= 3:
        cms.append(CouplingMap.ring(nc))
        names.append("Ring")
    cms.append(CouplingMap.full(nc))
    names.append("Full")
    # var g = grid_map(nc)
    # names.append("Grid(" + String(g.nq) + ")")
    # cms.append(g^)
    if nq <= 5:
        cms.append(CouplingMap.manila())
        names.append("Manila(5)")
    if nq <= 20:
        cms.append(CouplingMap.ibm_q20_tokyo())
        names.append("IBM_q20_tokyo(20)")
    
def phys_dist(cm: CouplingMap, a: Int, b: Int) -> Int:
    var p = cm.shortest_path(a, b)
    if len(p) == 0:
        return -1
    return len(p) - 1

def eval_layout(
    layout: List[Int],
    nq: Int,
    cm: CouplingMap,
    q0s: List[Int],
    q1s: List[Int]
) -> String:
    var valid = len(layout) >= nq
    if valid:
        var seen = List[Bool]()
        for _ in range(cm.nq):
            seen.append(False)
        for v in range(nq):
            var p = layout[v]
            if p < 0 or p >= cm.nq:
                valid = False
                break
            if seen[p]:
                valid = False
                break
            seen[p] = True
    var n_conn = 0
    var est = 0
    if valid:
        for i in range(len(q0s)):
            var p0 = layout[q0s[i]]
            var p1 = layout[q1s[i]]
            if cm.connected(p0, p1):
                n_conn += 1
            else:
                var d = phys_dist(cm, p0, p1)
                if d > 1:
                    est += d - 1
    var perfect = valid and n_conn == len(q0s)
    return ("Valid " + String(valid)
            + " Perfect " + String(perfect)
            + " Connected " + String(n_conn) + "/" + String(len(q0s))
            + " EstSwaps " + String(est))

def edges_line(cm: CouplingMap) -> String:
    var s = String("Edges")
    for u in range(cm.nq):
        for k in range(len(cm.edges[u])):
            var v = cm.edges[u][k]
            if u < v:
                s += " " + String(u) + " " + String(v)
    return s + "\n"

def run_passes(
    mut out: String,
    dag: DAGCircuit,
    nq: Int,
    nc: Int,
    q0s: List[Int],
    q1s: List[Int],
    vf2: VF2Layout,
    sabre: SabreLayout
):
    var cms = List[CouplingMap]()
    var names = List[String]()
    build_topologies(nq, nc, cms, names)
    for i in range(len(cms)):
        out += "Topology " + names[i] + " " + String(cms[i].nq) + "\n"
        out += edges_line(cms[i])
        var t0 = Int(monotonic())
        var r1 = vf2.run(dag, cms[i])
        var dt = Int(monotonic()) - t0
        out += "VF2 " + String(r1.layout) + "\n"
        out += "VF2Eval " + eval_layout(r1.layout, nq, cms[i], q0s, q1s) + " Runtime_ns " + String(dt) + "\n"
        t0 = Int(monotonic())
        var r2 = sabre.run(dag, cms[i])
        dt = Int(monotonic()) - t0
        out += "Sabre " + String(r2.layout) + "\n"
        out += "SabreEval " + eval_layout(r2.layout, nq, cms[i], q0s, q1s) + " Runtime_ns " + String(dt) + "\n"

def case_header(case_id: Int, label: String, nq: Int, nc: Int) -> String:
    return ("Case " + String(case_id) + " " + label + "\n"
            + "Qubits " + String(nq) + "\n"
            + "Physical " + String(nc) + "\n")

def append_file(path: String, text: String) raises:
    var f = open(path, "a")
    f.write(text)
    f.close()

def random_case(
    path: String,
    case_id: Int,
    label: String,
    nq: Int,
    ng: Int,
    nc: Int,
    vf2: VF2Layout,
    sabre: SabreLayout
) raises:
    var qc = QuantumCircuit(nq)
    var gate_log = List[ApplyGateLog]()
    for _ in range(ng):
        var g: ApplyGateLog
        if random_int(0, 2) == 0 or nq == 1:
            g = ApplyRandomGateLog.apply_random_single_qubit_gate_with_log(qc, nq)
        else:
            g = ApplyRandomGateLog.apply_random_cx_gate_with_log(qc, nq)
        gate_log.append(g^)
    var out = case_header(case_id, label, nq, nc)
    var q0s = List[Int]()
    var q1s = List[Int]()
    for i in range(len(gate_log)):
        var g = gate_log[i].copy()
        out += gate_line(g)
        if g.gate_name == "CX":
            q0s.append(g.q0)
            q1s.append(g.q1)
    var dag = DAGCircuit.from_circuit(qc)
    run_passes(out, dag, nq, nc, q0s, q1s, vf2, sabre)
    out += "EndCase\n"
    append_file(path, out)

def fixed_case(
    path: String,
    case_id: Int,
    label: String,
    nq: Int,
    nc: Int,
    q0s: List[Int],
    q1s: List[Int],
    n_1q: Int,
    vf2: VF2Layout,
    sabre: SabreLayout
) raises:
    var qc = QuantumCircuit(nq)
    var out = case_header(case_id, label, nq, nc)
    for i in range(len(q0s)):
        qc.CX(q0s[i], q1s[i])
        out += "Gate CX " + String(q0s[i]) + " " + String(q1s[i]) + "\n"
    for _ in range(n_1q):
        var g = ApplyRandomGateLog.apply_random_single_qubit_gate_with_log(qc, nq)
        out += gate_line(g)
    var dag = DAGCircuit.from_circuit(qc)
    run_passes(out, dag, nq, nc, q0s, q1s, vf2, sabre)
    out += "EndCase\n"
    append_file(path, out)

def main() raises:
    var path = String("benchmark/transpiler_stage2/layout_benchmark.txt")
    var vf2 = VF2Layout()
    var sabre = SabreLayout()
    var f = open(path, "w")
    f.write("VF2Layout Call_limit " + String(vf2.call_limit)
            + " Max_solutions " + String(vf2.max_solutions) + "\n")
    f.write("SabreLayout Trials " + String(sabre.trials)
            + " Iter " + String(sabre.iter)
            + " Weight " + String(sabre.weight)
            + " E_size " + String(sabre.E_size)
            + " Delta " + String(sabre.delta)
            + " Valve_limit " + String(sabre.valve_limit) + "\n")
    f.close()
    var case_id = 0
    fixed_case(path, case_id, "Chain", 5, 7, [0, 1, 2, 3], [1, 2, 3, 4], 0, vf2, sabre)
    case_id += 1
    fixed_case(path, case_id, "Triangle", 3, 5, [0, 1, 0], [1, 2, 2], 0, vf2, sabre)
    case_id += 1
    fixed_case(path, case_id, "Star", 4, 6, [0, 0, 0], [1, 2, 3], 0, vf2, sabre)
    case_id += 1
    fixed_case(path, case_id, "Cycle", 6, 6, [0, 1, 2, 3, 4, 5], [1, 2, 3, 4, 5, 0], 0, vf2, sabre)
    case_id += 1
    fixed_case(path, case_id, "AllPairs", 5, 7,
               [0, 0, 0, 0, 1, 1, 1, 2, 2, 3],
               [1, 2, 3, 4, 2, 3, 4, 3, 4, 4], 0, vf2, sabre)
    case_id += 1
    fixed_case(path, case_id, "RepeatedPair", 2, 2, [0, 0, 0], [1, 1, 1], 0, vf2, sabre)
    case_id += 1
    fixed_case(path, case_id, "No2Q", 4, 6, List[Int](), List[Int](), 8, vf2, sabre)
    case_id += 1
    fixed_case(path, case_id, "Overflow", 6, 4, [0, 1, 2, 3, 4], [1, 2, 3, 4, 5], 0, vf2, sabre)
    case_id += 1
    for nq in range(2, 11):
        for _ in range(3):
            var nc = nq + nq // random_int(1, 5)
            random_case(path, case_id, "ScaleQubits", nq, nq * nq, nc, vf2, sabre)
            case_id += 1
    for ng in [5, 10, 25, 50, 100, 200]:
        random_case(path, case_id, "ScaleGates", 5, ng, 7, vf2, sabre)
        case_id += 1
    for nc in [4, 5, 8, 12, 20]:
        random_case(path, case_id, "ScalePhysical", 4, 16, nc, vf2, sabre)
        case_id += 1
    append_file(path, "Total " + String(case_id) + "\n")