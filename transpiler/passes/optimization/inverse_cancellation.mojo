from dagcircuit import DAGCircuit
from gates import GateOp
from qmath import PI, abs

struct InverseCancellation:

    def __init__(out self):
        pass
    
    def _param_sum(self, g1: GateOp, g2: GateOp, tol: Float64 = 1e-10) -> Bool:
        if len(g1.theta) == 0 or len(g2.theta) == 0:
            return False
        var PI2: Float64 = 2 * PI
        var s = g1.theta[0] + g2.theta[0]
        while s > PI: s -= PI2
        while s < -PI: s += PI2
        return abs(s) < tol

    def _are_inverses(self, g1: GateOp, g2: GateOp) -> Bool:
        if len(g1.qubit) != len(g2.qubit): return False
        var nq = len(g1.qubit)
        for i in range(nq):
            if g1.qubit[i] != g2.qubit[i]: return False
        var n1 = g1.name
        var n2 = g2.name
        if n1 == "I" and n2 == "I": return True
        if n1 == "H" and n2 == "H": return True
        if n1 == "X" and n2 == "X": return True
        if n1 == "Y" and n2 == "Y": return True
        if n1 == "Z" and n2 == "Z": return True
        if n1 == "CX" and n2 == "CX": return True
        if n1 == "S" and n2 == "SDG": return True
        if n1 == "SDG" and n2 == "S": return True
        if n1 == "T" and n2 == "TDG": return True
        if n1 == "TDG" and n2 == "T": return True
        if n1 == "RX" and n2 == "RX":
            return self._param_sum(g1, g2)
        if n1 == "RY" and n2 == "RY":
            return self._param_sum(g1, g2)
        if n1 == "RZ" and n2 == "RZ":
            return self._param_sum(g1, g2)
        if n1 == "P" and n2 == "P":
            return self._param_sum(g1, g2)
        if n1 == "IP" and n2 == "IP":
            return self._param_sum(g1, g2)
        if (n1 == "P" and n2 == "IP") or (n1 == "IP" and n2 == "P"):
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
        