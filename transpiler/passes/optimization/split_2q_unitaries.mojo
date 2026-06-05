from dagcircuit import DAGCircuit
from gates import GateOp
from qmath import Complex, Matrix2x2, Matrix4x4, GateMatrix
from transpiler.passes.basis import OneQubitEulerDecomposer

struct Split2QUnitaries:
    var fidelity: Float64
    var split_swap: Bool

    def __init__(out self, fidelity: Float64 = 1.0 - 1e-16, split_swap: Bool = False):
        self.fidelity = fidelity
        self.split_swap = split_swap

    def _load_2x2(self, theta: List[Float64]) -> Matrix2x2:
        var m = Matrix2x2()
        for r in range(2):
            for c in range(2):
                var idx = (r * 2 + c) * 2
                m.set(r, c, Complex(theta[idx], theta[idx + 1]))
        return m^

    def _load_4x4(self, params: List[Float64]) -> Matrix4x4:
        return Matrix4x4.deserialize(params)

    def _avg_gate_fidelity_4x4(self, u4: Matrix4x4, gates_a: List[GateOp], gates_b: List[GateOp], q0: Int, q1: Int) -> Float64:
        var ua = Matrix2x2()
        for i in range(len(gates_a)):
            var m = GateMatrix.get_1q(gates_a[i].name, gates_a[i].theta)
            ua = m.mul(ua)
        var ub = Matrix2x2()
        for i in range(len(gates_b)):
            var m = GateMatrix.get_1q(gates_b[i].name, gates_b[i].theta)
            ub = m.mul(ub)
        var reconstructed = GateMatrix.tensor(ua, ub)
        var u4_dagger = u4.dagger()
        var product = u4_dagger.mul(reconstructed)
        var tr = product.trace()
        var tr_norm_sq = tr.re * tr.re + tr.im * tr.im
        var d: Float64 = 4.0
        return (tr_norm_sq + d) / (d * (d + 1))
    
    def _try_split_separable(self, u4: Matrix4x4, q0: Int, q1: Int, decomposer: OneQubitEulerDecomposer) -> Tuple[Bool, List[GateOp], List[GateOp]]:
        var empty_ua = List[GateOp]()
        var empty_ub = List[GateOp]()
        if not u4.is_tensor_product():
            return (False, empty_ua^, empty_ub^)
        var factor = u4.extract_factors()
        var ua = factor[0].copy()
        var ub = factor[1].copy()
        var gates_a = decomposer.run(ua, q0)
        var gates_b = decomposer.run(ub, q1)
        var f = self._avg_gate_fidelity_4x4(u4, gates_a, gates_b, q0, q1)
        if f >= self.fidelity:
            return (True, gates_a^, gates_b^)
        return (False, empty_ua^, empty_ub^)

    def _add_1q_unitary_gates(self, mut dag: DAGCircuit, u: Matrix2x2, q: Int, decomposer: OneQubitEulerDecomposer):
        if u.is_identity(): return
        var gates = decomposer.run(u, q)
        for i in range(len(gates)):
            dag.add_operation(gates[i])

    def run(self, dag: DAGCircuit) -> DAGCircuit:
        var decomposer = OneQubitEulerDecomposer()
        var dagc = dag.copy()
        var topo = dagc.topological_sort()
        for i in range(len(topo)):
            var nid = topo[i]
            if dagc.nodes[nid].type == "removed": continue
            var gate = dagc.nodes[nid].gate.copy()
            if (gate.name == "UnitaryGate1q" and len(gate.qubit) == 1 and len(gate.theta) == 8):
                var q = gate.qubit[0]
                var u2 = self._load_2x2(gate.theta)
                if u2.is_identity():
                    dagc.remove_operation(nid)
                    continue
                var gates = decomposer.run(u2, q)
                dagc.remove_operation(nid)
                for j in range(len(gates)):
                    dagc.add_operation(gates[j])
                continue
            if (gate.name != "UnitaryGate2q" or len(gate.qubit) != 2 or len(gate.theta) != 32):
                continue
            var q0 = gate.qubit[0]
            var q1 = gate.qubit[1]
            var u4 = self._load_4x4(gate.theta)
            var sep_result = self._try_split_separable(u4, q0, q1, decomposer)
            var sep_sucess = sep_result[0]
            if sep_sucess:
                dagc.remove_operation(nid)
                var factor = u4.extract_factors()
                var ua = factor[0].copy()
                var ub = factor[1].copy()
                self._add_1q_unitary_gates(dagc, ua, q0, decomposer)
                self._add_1q_unitary_gates(dagc, ub, q1, decomposer)
                continue
        dagc.finalize_operation()
        return dagc^