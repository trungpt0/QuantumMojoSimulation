from dagcircuit import DAGCircuit
from gates import GateOp

struct RemoveDiagonalGatesBeforeMeasure:
    def __init__(out self):
        pass

    def _is_diagonal(self, name: String) -> Bool:
        return (name == "RZ" or name == "Z" or
                name == "S" or name == "SDG" or
                name == "T" or name == "TDG" or
                name == "P")

    def run(self, owned dag: DAGCircuit) -> DAGCircuit:
        var topo = dag.topological_sort()
        for i in range(len(topo)):
            var nid = topo[i]
            if dag.nodes[nid].type == "removed": continue
            var gate = dag.nodes[nid].gate
            if gate.name == "MEASURE" and len(gate.qubit) > 0:
                var preds = dag.predecessors(nid)
                for j in range(len(preds)):
                    var pid = preds[j]
                    if dag.nodes[pid].type == "gate":
                        if self._is_diagonal(dag.nodes[pid].gate.name):
                            var pred_succs = dag.successors(pid)
                            if len(pred_succs == 1):
                                dag.remove_node(pid)
        return dag^