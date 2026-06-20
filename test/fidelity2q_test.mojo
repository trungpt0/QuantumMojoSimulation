from qmath import Matrix2x2, Matrix4x4, GateMatrix, Complex, PI
from dagcircuit import DAGCircuit
from gates import GateOp
from circuit import QuantumCircuit
from transpiler.passes.optimization import ConsolidateBlocks

def fidelity4x4(u1: Matrix4x4, u2: Matrix4x4) -> Float64:
    var u1d = u1.dagger()
    var prod = u1d.mul(u2)
    var tr = prod.get(0,0).re + prod.get(1,1).re + prod.get(2,2).re + prod.get(3,3).re
    var tri = prod.get(0,0).im + prod.get(1,1).im + prod.get(2,2).im + prod.get(3,3).im
    var mag2 = tr*tr + tri*tri
    return mag2 / 16.0

def build_before(q0: Int, q1: Int) -> Matrix4x4:
    var cb = ConsolidateBlocks()
    var g1 = GateOp("S", [2], [])
    var g2 = GateOp("CX", [2,0], [])
    # var g3 = GateOp("T", [1], [])
    # var g4 = GateOp("CX", [0,1], [])
    var res = Matrix4x4()
    res = cb._gate_to_4x4(g1, q0, q1).mul(res)
    res = cb._gate_to_4x4(g2, q0, q1).mul(res)
    # res = cb._gate_to_4x4(g3, q0, q1).mul(res)
    # res = cb._gate_to_4x4(g4, q0, q1).mul(res)
    return res^

def main() raises:
    var qc = QuantumCircuit(3)
    qc.S(2)
    qc.CX(2,0)
    var dag = DAGCircuit.from_circuit(qc)
    # dag.print_dag()
    var pass1 = ConsolidateBlocks()
    var dag1 = pass1.run(dag^)
    # dag1.print_dag()
    var u_mojo = Matrix4x4()
    var found = False
    for i in range(len(dag1.nodes)):
        if dag1.nodes[i].type == "gate":
            var g = dag1.nodes[i].gate.copy()
            if g.name == "UnitaryGate2q":
                for r in range(4):
                    for c in range(4):
                        var idx = (r*4 + c) * 2
                        u_mojo.set(r, c, Complex(g.theta[idx], g.theta[idx+1]))
                found = True
    var u_before = build_before(0, 1)
    print("U Before:")
    u_before.print_matrix()
    print("U Mojo:")
    u_mojo.print_matrix()
    if found:
        print("fidelity(before, mojo) =", fidelity4x4(u_before, u_mojo))
    else:
        print("No UnitaryGate2q found!")
