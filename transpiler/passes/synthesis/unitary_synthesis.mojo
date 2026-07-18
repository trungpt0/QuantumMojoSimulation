from dagcircuit import DAGCircuit
from gates import GateOp
from qmath import Matrix2x2, Matrix4x4

from transpiler.passes.synthesis import WeylDecomposition
from transpiler.passes.synthesis import TensorFactorize
from transpiler.passes.synthesis import VatanWilliams
from transpiler.passes.synthesis import EulerSU2, EulerSU2ToGates

struct UnitarySynthesis:
    var tol: Float64
    var euler: EulerSU2
    var etg: EulerSU2ToGates

    def __init__(out self, tol: Float64 = 1e-10):
        self.tol = tol
        self.euler = EulerSU2(tol)
        self.etg = EulerSU2ToGates(tol)

    def _u2_to_rot_gates(self, u: Matrix2x2, q: Int) -> List[GateOp]:
        var abc = self.euler.decompose(u)
        return self.e2g.synthesize(abc.get[0](), abc.get[1](), abc.get[2](), q)^

    def _extend(self, mut dst: List[GateOp], src: List[GateOp]):
        for i in range(len(src)):
            dst.append(src[i])

    def _split_unitary_gate(out self, dag: DAGCircuit, nid: Int) -> List[GateOp]:
        var gate = dag.nodes[nid].gate.copy()
        var q0 = gate.qubit[0]
        var q1 = gate.qubit[1]
        var U = Matrix4x4.deserialize(gate.theta)
        var result = List[GateOp]()
        # Case 1: U = Ua ⊗ Ub
        if U.is_tensor_product(self.tol):
            var factors = U.extract_factors(self.tol)
            var Ua = factors[0]
            var Ub = factors[1]
            if not Ua.is_identity(self.tol):
                self._extend(result, self._u2_to_rot_gates(Ua, q0))
            if not Ub.is_identity(self.tol):
                self._extend(result, self._u2_to_rot_gates(Ub, q1))
            return result^
        # Case 2: KAK decomposition
        var weyl = WeylDecomposition(self.tol)
        var kak = weyl.decompose(U)
        var K1 = kak[0]
        var alpha = kak[1]
        var beta = kak[2]
        var gamma = kak[3]
        var K2 = kak[4]
        var global_phase = kak[5]
        var tf = TensorFactorize(self.tol)
        var k1 = tf.factorize(K1)
        var K1l = k1[0]
        var K1r = k1[1]
        var k2 = tf.factorize(K2)
        var K2l = k2[0]
        var K2r = k2[1]
        var result = List[GateOp]()
        if not K2l.is_identity(self.tol):
            self._extend(result, self._u2_to_rot_gates(K2l, q0))
        if not K2r.is_identity(self.tol):
            self._extend(result, self._u2_to_rot_gates(K2r, q1))
        var vw = VatanWilliams(self.tol)
        var canon = vw.synthesize(alpha, beta, gamma, q0, q1)
        self._extend(result, canon)
        if not K1l.is_identity(self.tol):
            self._extend(result, self._u2_to_rot_gates(K1l, q0))
        if not K1r.is_identity(self.tol):
            self._extend(result, self._u2_to_rot_gates(K1r, q1))
        return result^

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
        return dagc^