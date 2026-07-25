from dagcircuit import DAGCircuit
from gates import GateOp

struct RemoveDiagonalGatesBeforeMeasure:
    def __init__(out self):
        pass

    def _is_diagonal(self, name: String) -> Bool:
        return (name == "RZ" or name == "Z" or
                name == "S" or name == "SDG" or
                name == "T" or name == "TDG" or
                name == "P" or name == "IP")

    def run(self, dag: DAGCircuit) -> DAGCircuit:
        dagc = dag.copy()
        var topo = dagc.topological_sort()
        for i in range(len(topo)):
            var nid = topo[i]
            if dagc.nodes[nid].type == "removed": continue
            var gate = dagc.nodes[nid].gate.copy()
            if gate.name == "MEASURE" and len(gate.qubit) > 0:
                var preds = dagc.predecessors(nid)
                for j in range(len(preds)):
                    var pid = preds[j]
                    if dagc.nodes[pid].type == "gate":
                        if self._is_diagonal(dagc.nodes[pid].gate.name):
                            var pred_succs = dagc.successors(pid)
                            if len(pred_succs) == 1:
                                dagc.remove_operation(pid)
        return dagc^