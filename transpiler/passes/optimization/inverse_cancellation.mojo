from dagcircuit import DAGCircuit
from gates import GateOp

struct InverseCancellation:

    def __init__(out self):
        pass
        
    def _are_inverses(self, g1: GateOp, g2: GateOp) -> Bool:
        if len(g1.qubit) != len(g2.qubit): return False
        for i in range(len(g1.qubit)):
            if g1.qubit[i] != g2.qubit[i]: return False
        if g1.name == "H" and g2.name == "H": return True
        if g1.name == "X" and g2.name == "X": return True
        if g1.name == "Y" and g2.name == "Y": return True
        if g1.name == "Z" and g2.name == "Z": return True
        if g1.name == "CX" and g2.name == "CX": return True
        if g1.name == "S" and g2.name == "SDG": return True
        if g1.name == "SDG" and g2.name == "S": return True
        if g1.name == "T" and g2.name == "TDG": return True
        if g1.name == "TDG" and g2.name == "T": return True
        return False

    def run(self, dag: DAGCircuit) -> DAGCircuit:
        var dagc = dag.copy()
        var changed = True
        while changed:
            changed = False
            var topo = dagc.topological_sort()
            for i in range(len(topo)):
                var nid = topo[i]
                if dagc.nodes[nid].type == "removed": continue
                var succs = dagc.successors(nid)
                for j in range(len(succs)):
                    var sid = succs[j]
                    if dagc.nodes[sid].type != "gate": continue
                    if self._are_inverses(dagc.nodes[nid].gate, dagc.nodes[sid].gate):
                        dagc.remove_operation(nid)
                        dagc.remove_operation(sid)
                        changed = True
                        break
                if changed: break
        return dagc^
        