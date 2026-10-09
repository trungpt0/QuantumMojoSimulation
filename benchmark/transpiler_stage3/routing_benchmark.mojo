from qmath import random_int 
from dagcircuit import DAGCircuit
from circuit import QuantumCircuit
from gate_record import ApplyGateLog
from std.time import monotonic
from qrandom import ApplyRandomGateLog
from transpiler import CouplingMap, SabreLayout, SabreSwap

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

def build_topologies(nq: Int, nc: Int, mut cms: List[CouplingMap], mut names: List[String]):
    cms.append(CouplingMap.linear(nc))
    names.append("Linear")
    if nc >= 3:
        cms.append(CouplingMap.ring(nc))
        names.append("Ring")
    cms.append(CouplingMap.full(nc))
    names.append("Full")
    if nq <= 5:
        cms.append(CouplingMap.manila())
        names.append("Manila(5)")
    if nq <= 20:
        cms.append(CouplingMap.ibm_q20_tokyo())
        names.append("IBM_q20_tokyo(20)")

def edges_line(cm: CouplingMap) -> String:
    var s = String("Edges")
    for u in range(cm.nq):
        for k in range(len(cm.edges[u])):
            var v = cm.edges[u][k]
            if u < v:
                s += " " + String(u) + " " + String(v)
    return s + "\n"

def case_header(case_id: Int, label: String, nq: Int, nc: Int) -> String:
    return ("Case " + String(case_id) + " " + label + "\n"
            + "Qubits " + String(nq) + "\n"
            + "Physical " + String(nc) + "\n")

def append_file(path: String, text: String) raises:
    var f = open(path, "a")
    f.write(text)
    f.close()

def count_swaps(dag: DAGCircuit) -> Int:
    var cnt = 0
    var topo = dag.topological_sort()
    for i in range(len(topo)):
        var name = dag.nodes[topo[i]].gate.name
        if name == "SWAP": cnt += 1
    return cnt

def dump_routed_dag(dag: DAGCircuit) -> String:
    var s = String("RoutedGates\n")
    var topo = dag.topological_sort()
    for i in range(len(topo)):
        var g = dag.nodes[topo[i]].gate.copy()
        if len(g.qubit) == 2:
            s += "Gate " + g.name + " " + String(g.qubit[0]) + " " + String(g.qubit[1]) + "\n"
        elif len(g.qubit) == 1:
            s += "Gate " + g.name + " " + String(g.qubit[0]) + "\n"
    s += "EndRoutedGates\n"
    return s

def run_routing_passes(
    mut out: String,
    dag: DAGCircuit,
    nq: Int,
    nc: Int,
    sabre_layout: SabreLayout,
    mut sabre_swap: SabreSwap
):
    var cms = List[CouplingMap]()
    var names = List[String]()
    build_topologies(nq, nc, cms, names)
    for i in range(len(cms)):
        out += "Topology " + names[i] + " " + String(cms[i].nq) + "\n"
        out += edges_line(cms[i])
        var dag_layout = sabre_layout.run(dag, cms[i])
        out += "InitialLayout " + String(dag_layout.layout) + "\n"
        var t0 = Int(monotonic())
        var routed_dag = sabre_swap.run(dag_layout, cms[i])
        var dt = Int(monotonic()) - t0
        var swaps = count_swaps(routed_dag)
        out += "MojoSwapCount " + String(swaps) + "\n"
        out += "MojoRuntime_ns " + String(dt) + "\n"
        out += dump_routed_dag(routed_dag)

def random_case(
    path: String,
    case_id: Int,
    label: String,
    nq: Int,
    ng: Int,
    nc: Int,
    sabre_layout: SabreLayout,
    mut sabre_swap: SabreSwap
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
    out += "OriginalGates\n"
    for i in range(len(gate_log)):
        var g = gate_log[i].copy()
        out += gate_line(g)
    out += "EndOriginalGates\n"
    var dag = DAGCircuit.from_circuit(qc)
    run_routing_passes(out, dag, nq, nc, sabre_layout, sabre_swap)
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
    sabre_layout: SabreLayout,
    mut sabre_swap: SabreSwap
) raises:
    var qc = QuantumCircuit(nq)
    var out = case_header(case_id, label, nq, nc)
    out += "OriginalGates\n"
    for i in range(len(q0s)):
        qc.CX(q0s[i], q1s[i])
        out += "Gate CX " + String(q0s[i]) + " " + String(q1s[i]) + "\n"
    for _ in range(n_1q):
        var g = ApplyRandomGateLog.apply_random_single_qubit_gate_with_log(qc, nq)
        out += gate_line(g)
    out += "EndOriginalGates\n"
    var dag = DAGCircuit.from_circuit(qc)
    run_routing_passes(out, dag, nq, nc, sabre_layout, sabre_swap)
    out += "EndCase\n"
    append_file(path, out)

def main() raises:
    var path = String("benchmark/transpiler_stage3/routing_benchmark.txt")
    var sabre_layout = SabreLayout(trials=10)
    var sabre_swap = SabreSwap(trials=20)
    var f = open(path, "w")
    f.write("SabreSwap Trials " + String(sabre_swap.trials)
            + " Weight " + String(sabre_swap.weight)
            + " E_size " + String(sabre_swap.E_size)
            + " Delta " + String(sabre_swap.delta)
            + " Valve_limit " + String(sabre_swap.valve_limit) + "\n")
    f.close()
    var case_id = 0
    fixed_case(path, case_id, "Chain", 5, 7, [0, 1, 2, 3], [1, 2, 3, 4], 2, sabre_layout, sabre_swap)
    case_id += 1
    fixed_case(path, case_id, "Triangle", 3, 5, [0, 1, 0], [1, 2, 2], 1, sabre_layout, sabre_swap)
    case_id += 1
    fixed_case(path, case_id, "Star", 4, 6, [0, 0, 0], [1, 2, 3], 1, sabre_layout, sabre_swap)
    case_id += 1
    fixed_case(path, case_id, "Cycle", 6, 6, [0, 1, 2, 3, 4, 5], [1, 2, 3, 4, 5, 0], 2, sabre_layout, sabre_swap)
    case_id += 1
    fixed_case(path, case_id, "AllPairs", 5, 7,
               [0, 0, 0, 0, 1, 1, 1, 2, 2, 3],
               [1, 2, 3, 4, 2, 3, 4, 3, 4, 4], 3, sabre_layout, sabre_swap)
    case_id += 1
    for nq in range(3, 7):
        for _ in range(2):
            var nc = nq + nq // random_int(1, 4)
            random_case(path, case_id, "ScaleQubits", nq, nq * 3, nc, sabre_layout, sabre_swap)
            case_id += 1
    for ng in [10, 25, 50]:
        random_case(path, case_id, "ScaleGates", 5, ng, 7, sabre_layout, sabre_swap)
        case_id += 1
    append_file(path, "Total " + String(case_id) + "\n")