from dagcircuit import DAGCircuit
from gates import GateOp
from qmath import PI, abs

struct InverseCancellation:

    def __init__(out self):
        pass
    
    def _param_sum(self, g1: GateOp, g2: GateOp, tol: Float64 = 1e-10) -> Bool:
        if len(g1.theta) == 0 or len(g2.theta) == 0:
            return False
        var PI2: Float64 = PI * PI
        var s = g1.theta[0] + g2.theta[0]
        while s > PI: s -= PI2
        while s < -PI: s += PI2
        return abs(s) < tol

    def _are_inverses(self, g1: GateOp, g2: GateOp) -> Bool:
        if len(g1.qubit) != len(g2.qubit): return False
        for i in range(len(g1.qubit)):
            if g1.qubit[i] != g2.qubit[i]: return False
        if g1.name == "I" and g2.name == "I": return True
        if g1.name == "H" and g2.name == "H": return True
        if g1.name == "X" and g2.name == "X": return True
        if g1.name == "Y" and g2.name == "Y": return True
        if g1.name == "Z" and g2.name == "Z": return True
        if g1.name == "CX" and g2.name == "CX": return True
        if g1.name == "S" and g2.name == "SDG": return True
        if g1.name == "SDG" and g2.name == "S": return True
        if g1.name == "T" and g2.name == "TDG": return True
        if g1.name == "TDG" and g2.name == "T": return True
        if g1.name == "RX" and g2.name == "RX":
            return self._param_sum(g1, g2)
        if g1.name == "RY" and g2.name == "RY":
            return self._param_sum(g1, g2)
        if g1.name == "RZ" and g2.name == "RZ":
            return self._param_sum(g1, g2)
        if g1.name == "P" and g2.name == "P":
            return self._param_sum(g1, g2)
        if g1.name == "IP" and g2.name == "IP":
            return self._param_sum(g1, g2)
        if (g1.name == "P" and g2.name == "IP") or (g1.name == "IP" and g2.name == "P"):
            return self._param_sum(g1, g2)
        return False

    def _direct_successor_on_qubits(self, dag: DAGCircuit, nid: Int) -> Int:
        var gate = dag.nodes[nid].gate.copy()
        var cgate: Int = -1
        for i in range(len(gate.qubit)):
            var q = gate.qubit[i]
            var next_q: Int = -1
            for e in range(len(dag.edges)):
                var edge = dag.edges[e].copy()
                if edge.src == nid and edge.qubit == q:
                    if dag.nodes[edge.dst].type == "gate":
                        next_q = edge.dst
                    break
            if next_q < 0:
                return -1
            if cgate < 0:
                cgate = next_q
            elif cgate != next_q:
                return -1
        return cgate

    def run(self, dag: DAGCircuit) -> DAGCircuit:
        var dagc = dag.copy()
        var changed = True
        while changed:
            changed = False
            var topo = dagc.topological_sort()
            for i in range(len(topo)):
                var nid = topo[i]
                if dagc.nodes[nid].type == "removed": continue
                if dagc.nodes[nid].type != "gate": continue
                var sid = self._direct_successor_on_qubits(dagc, nid)
                if sid < 0:
                    continue
                if self._are_inverses(dagc.nodes[nid].gate, dagc.nodes[sid].gate):
                    dagc.remove_operation(nid)
                    dagc.remove_operation(sid)
                    changed = True
                    break
        return dagc^
        