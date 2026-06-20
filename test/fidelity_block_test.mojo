from qmath import PI, sqrt, Complex, Matrix2x2, Matrix4x4, GateMatrix
from dagcircuit import DAGCircuit
from gates import GateOp
from circuit import QuantumCircuit
from transpiler.passes.optimization import ConsolidateBlocks

struct FullMatrix(Copyable, Movable):
    var dim: Int
    var data: List[Complex]

    def __init__(out self, n_qubits: Int):
        self.dim = 1 << n_qubits
        self.data = List[Complex]()
        for _ in range(self.dim * self.dim):
            self.data.append(Complex(0.0, 0.0))
        for i in range(self.dim):
            self.data[i * self.dim + i] = Complex(1.0, 0.0)
            
    def __copy__(self) -> Self:
        var m = FullMatrix(self.dim)
        m.dim = self.dim
        m.data = self.data.copy()
        return m^
    
    # def __moveinit__(out self, owned other: Self):
    #     self.dim = other.dim
    #     self.data = other.data^
    
    def get(self, r: Int, c: Int) -> Complex:
        return self.data[r * self.dim + c].copy()

    def set(mut self, r: Int, c: Int, v: Complex):
        self.data[r * self.dim + c] = v.copy()

    def mul(self, other: FullMatrix) -> FullMatrix:
        var res = FullMatrix(0)
        res.dim = self.dim
        res.data = List[Complex]()
        for _ in range(self.dim * self.dim):
            res.data.append(Complex(0.0, 0.0))
        for r in range(self.dim):
            for c in range(self.dim):
                var s = Complex(0.0, 0.0)
                for k in range(self.dim):
                    s = s.add(self.get(r, k).mul(other.get(k, c)))
                res.set(r, c, s)
        return res^
    
    def dagger(self) -> FullMatrix:
        var res = FullMatrix(0)
        res.dim = self.dim
        res.data = List[Complex]()
        for _ in range(self.dim * self.dim):
            res.data.append(Complex(0.0, 0.0))
        for r in range(self.dim):
            for c in range(self.dim):
                var v = self.get(r, c)
                res.set(c, r, Complex(v.re, -v.im))
        return res^

    def trace(self) -> Complex:
        var t = Complex(0.0, 0.0)
        for i in range(self.dim):
            t = t.add(self.get(i, i))
        return t^

def fidelity_full(u1: FullMatrix, u2: FullMatrix) -> Float64:
    var dag = u1.dagger()
    var prod = dag.mul(u2)
    var tr = prod.trace()
    var mag2 = tr.re * tr.re + tr.im * tr.im
    var d = Float64(u1.dim)
    return mag2 / (d * d)

def embed_1q_full(n_qubits: Int, q: Int, m: Matrix2x2) -> FullMatrix:
    var dim = 1 << n_qubits
    var res = FullMatrix(0)
    res.dim = dim
    res.data = List[Complex]()
    for _ in range(dim * dim):
        res.data.append(Complex(0.0, 0.0))
    for i in range(dim):
        var bi = (i >> q) & 1
        var i0 = i & ~(1 << q)
        for bj in range(2):
            var j = i0 | (bj << q)
            var v = m.get(bi, bj)
            if v.norm() > 1e-15:
                res.set(i, j, v)
    return res^

def embed_2q_full(n_qubits: Int, q0: Int, q1: Int, m: Matrix4x4) -> FullMatrix:
    var dim = 1 << n_qubits
    var res = FullMatrix(0)
    res.dim = dim
    res.data = List[Complex]()
    for _ in range(dim * dim):
        res.data.append(Complex(0.0, 0.0))
    var mask = ~((1 << q0) | (1 << q1))
    for i in range(dim):
        var bi0 = (i >> q0) & 1
        var bi1 = (i >> q1) & 1
        var i_other = i & mask
        var row_local = bi0 * 2 + bi1
        for bj0 in range(2):
            for bj1 in range(2):
                var col_local = bj0 * 2 + bj1
                var v = m.get(row_local, col_local)
                if v.norm() > 1e-15:
                    var j = i_other | (bj0 << q0) | (bj1 << q1)
                    res.set(i, j, v)
    return res^

def gate_to_full(n_qubits: Int, gate: GateOp) -> FullMatrix:
    var name = gate.name
    var qubits = gate.qubit.copy()
    var params = gate.theta.copy()
    if name == "UnitaryGate1q":
        var m = Matrix2x2(
            Complex(params[0], params[1]),
            Complex(params[2], params[3]),
            Complex(params[4], params[5]),
            Complex(params[6], params[7])
        )
        return embed_1q_full(n_qubits, qubits[0], m)
    elif name == "UnitaryGate2q":
        var m = Matrix4x4()
        for r in range(4):
            for c in range(4):
                var idx = (r * 4 + c) * 2
                m.set(r, c, Complex(params[idx], params[idx + 1]))
        return embed_2q_full(n_qubits, qubits[0], qubits[1], m)
    elif len(qubits) == 1:
        var m1 = GateMatrix.get_1q(name, params)
        return embed_1q_full(n_qubits, qubits[0], m1)
    elif len(qubits) == 2:
        var m4 = GateMatrix.get_2q(name)
        return embed_2q_full(n_qubits, qubits[0], qubits[1], m4)
    else:
        return FullMatrix(n_qubits)

def circuit_to_full_unitary(n_qubits: Int, gates: List[GateOp]) -> FullMatrix:
    var res = FullMatrix(n_qubits)
    for i in range(len(gates)):
        var gm = gate_to_full(n_qubits, gates[i])
        res = gm.mul(res)
    return res^

def dag_to_gate_list(dag: DAGCircuit) -> List[GateOp]:
    var topo = dag.topological_sort()
    var gates = List[GateOp]()
    for i in range(len(topo)):
        var nid = topo[i]
        if dag.nodes[nid].type == "gate":
            gates.append(dag.nodes[nid].gate.copy())
    return gates^

def main() raises:
    var n_qubits = 4
    var qc = QuantumCircuit(n_qubits)
    qc.CX(0,1)
    qc.CX(2,3)
    qc.CX(0,1)
    qc.Y(0)
    qc.RY(1,2.9311059457992767)
    qc.CX(1,3)
    qc.CX(3,2)
    qc.CX(1,2)
    qc.IP(3,1.1655308744818134)
    qc.Z(3)
    qc.Tdg(2)
    qc.S(0)
    qc.X(1)
    qc.IP(2,2.0891591146372126)
    qc.CX(1,2)
    qc.Sdg(1)
    var dag = DAGCircuit.from_circuit(qc)
    var gates_before = dag_to_gate_list(dag)
    print("Number of gates before: ", len(gates_before))
    var u_before = circuit_to_full_unitary(n_qubits, gates_before)
    var pass1 = ConsolidateBlocks()
    var dag1 = pass1.run(dag^)
    print("---Debug")
    var gates_mojo = dag_to_gate_list(dag1)
    print("Number of gates mojo: ", len(gates_mojo))
    for i in range(len(gates_mojo)):
        var g = gates_mojo[i].copy()
        print("  ", g.name, g.qubit)
    var u_mojo = circuit_to_full_unitary(n_qubits, gates_mojo)
    var fid = fidelity_full(u_before, u_mojo)
    print("fidelity(before, mojo) =", fid)
