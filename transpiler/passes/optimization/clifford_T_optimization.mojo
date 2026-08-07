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
        var all_gates = List[GateOp]()
        for i in range(len(optimized)):
            all_gates.append(optimized[i].copy())
        for i in range(len(passthrough)):
            all_gates.append(passthrough[i].copy())
        for i in range(len(measure_gates)):
            all_gates.append(measure_gates[i].copy())
        var block = List[Int]()
        for i in range(nq * 2, len(dagc.nodes)):
            block.append(i)
        dagc.replace_block_operations(all_gates, block)
        return dagc^