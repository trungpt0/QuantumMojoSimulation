from dagcircuit import DAGCircuit
from gates import GateOp
from transpiler.passes.synthesis import tpar_algorithm

struct TParOptimization:    
    var min_t_gates: Int

    def __init__(out self, min_t_gates: Int = 2):
        self.min_t_gates = min_t_gates

    def _is_clifford_t(self, name: String) -> Bool:
        return (name == "X" or name == "Y" or name == "Z" or
                name == "S" or name == "SDG" or
                name == "H" or name == "CX" or
                name == "T" or name == "TDG")

    def _count_t_gate(self, gates: List[GateOp]) -> Int:
        var c = 0
        for i in range(len(gates)):
            var n = gates[i].name
            if n == "T" or n == "TDG": c += 1
        return c

    def run(self, dag: DAGCircuit) -> DAGCircuit:
        var dagc = dag.copy()
        var nq = dagc.qubits
        var topo = dagc.topological_sort()
        var clifford_t_gates = List[GateOp]()
        var passthrough = List[GateOp]()
        var measure_gates = List[GateOp]()
        for i in range(len(topo)):
            var nid = topo[i]
            if dagc.nodes[nid].type != "gate": continue
            var g = dagc.nodes[nid].gate.copy()
            if g.name == "MEASURE" or g.name == "BARRIER":
                measure_gates.append(g^)
            elif self._is_clifford_t(g.name):
                clifford_t_gates.append(g^)
            else:
                passthrough.append(g^)
        if self._count_t_gate(clifford_t_gates) < self.min_t_gates:
            return dagc^
        var optimized = tpar_algorithm(clifford_t_gates, nq, passthrough)
        var opt_dag = DAGCircuit(nq)
        for i in range(len(optimized)):
            opt_dag.add_operation(optimized[i])
        for i in range(len(passthrough)):
            opt_dag.add_operation(passthrough[i])
        for i in range(len(measure_gates)):
            opt_dag.add_operation(measure_gates[i])
        return opt_dag^