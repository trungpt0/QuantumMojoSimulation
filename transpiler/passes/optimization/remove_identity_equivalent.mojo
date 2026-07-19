from dagcircuit import DAGCircuit
from gates import GateOp
from qmath import PI, abs

struct RemoveIdentityEquivalent:
    var approximation_degree: Float64

    def __init__(out self, approximation_degree: Float64 = 1.0):
        self.approximation_degree = approximation_degree

    def _is_identity(self, gate: GateOp) -> Bool:
        if gate.name == "I" or gate.name == "REMOVED": return True
        if gate.name == "RZ":
            var tol = 1e-10 * self.approximation_degree
            var theta = gate.theta[0] 
            if abs(theta) < tol: return True
            if abs(theta - 2 * PI) < tol: return True
        return False
    
    def run(self, dag: DAGCircuit) -> DAGCircuit:
        var dagc = dag.copy()
        var topo = dagc.topological_sort()
        for i in range(len(topo)):
            var nid = topo[i]
            var node = dagc.nodes[nid].copy()
            if node.type == "removed": continue
            if self._is_identity(node.gate):
                dagc.remove_operation(nid)
        return dagc^