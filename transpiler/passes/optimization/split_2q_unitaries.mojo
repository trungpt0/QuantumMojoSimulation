from dagcircuit import DAGCircuit
from gates import GateOp
from qmath import Matrix2x2, Matrix4x4

from transpiler.passes.synthesis import WeylDecomposition

struct Split2QUnitaries:
    var tol: Float64

    def __init__(out self, tol: Float64 = 1e-10):
        self.tol = tol

    def _u2_to_gate(self, U: Matrix2x2, q: Int) -> GateOp:
        var ql = List[Int]()
        ql.append(q)
        return GateOp("UnitaryGate1q", ql, U.serialize())^

    def _split_unitary_gate(out self, dag: DAGCircuit, nid: Int) -> List[GateOp]:
        var gate = dag.nodes[nid].gate.copy()
        var q0 = gate.qubit[0]
        var q1 = gate.qubit[1]
        var U = Matrix4x4.deserialize(gate.theta)
        # Case 1: U = Ua ⊗ Ub
        if U.is_tensor_product(self.tol):
            var factors = U.extract_factors(self.tol)
            var result = List[GateOp]()
            if not factors[0].is_identity(self.tol):
                result.append(self._u2_to_gate(factors[0], q0))
            if not factors[1].is_identity(self.tol):
                result.append(self._u2_to_gate(factors[1], q1))
            return result^
        # Case 2: KAK decomposition
        var weyl = WeylDecomposition(self.tol)

    def run(out self, dag: DAGCircuit) -> DAGCircuit:
        var dagc = dag.copy()
        var topo = dagc.topological_sort()
        var targets = List[Int]()
        for i in range(len(topo)):
            var nid = topo[i]
            if dagc.nodes[nid].type == "gate" and dagc.nodes[nid].gate.name == "UnitaryGate2q":
                targets.append(nid)
        for i in range(len(targets)):
            var nid = targets[i]
            var gate = self._split_unitary_gate(dagc, nid)
            var block = List[Int]()
            block.append(nid)
            dagc.replace_block_operation(gate, block)