from qmath import Complex, Matrix2x2, sqrt
from gates import GateOp
from transpiler.passes.basis import OneQubitEulerDecomposer

def make_identity() -> Matrix2x2:
    var m = Matrix2x2()
    return m^

def make_hadamard() -> Matrix2x2:
    var s = 1 / sqrt(2)
    var m = Matrix2x2()
    m.set(0, 0, Complex(s, 0.0))
    m.set(0, 1, Complex(s, 0.0))
    m.set(1, 0, Complex(s, 0.0))
    m.set(1, 1, Complex(-s, 0.0))
    return m^

def make_pauli_x() -> Matrix2x2:
    var m = Matrix2x2()
    m.set(0, 0, Complex(0.0, 0.0))
    m.set(0, 1, Complex(1.0, 0.0))
    m.set(1, 0, Complex(1.0, 0.0))
    m.set(1, 1, Complex(0.0, 0.0))
    return m^

def make_pauli_y() -> Matrix2x2:
    var m = Matrix2x2()
    m.set(0, 0,  Complex(0.0,  0.0))
    m.set(0, 1,  Complex(0.0, -1.0))
    m.set(1, 0,  Complex(0.0,  1.0))
    m.set(1, 1,  Complex(0.0,  0.0))
    return m^

def make_t_gate() -> Matrix2x2:
    var m = Matrix2x2()
    m.set(0, 0, Complex(1.0, 0.0))
    m.set(0, 1, Complex(0.0, 0.0))
    m.set(1, 0, Complex(0.0, 0.0))
    var s = 1.0 / sqrt(2.0)
    m.set(1, 1, Complex(s, s))
    return m^

def print_gates(gates: List[GateOp]):
    if len(gates) == 0:
        print("  (empty)")
        return
    for i in range(len(gates)):
        var g = gates[i].copy()
        if len(g.theta) > 0:
            print("  ", g.name, "(", g.theta[0], ")")
        else:
            print("  ", g.name)

def run_test(name: String, u: Matrix2x2):
    var dec = OneQubitEulerDecomposer()
    var gates = dec.run(u, 0)
    var f = dec.verify(u, gates)
    var passed = f > 1.0 - 1e-8
    if passed:
        print("PASS", name, "| fidelity =", f)
    else:
        print("FAIL", name, "| fidelity =", f)
    print_gates(gates)
    print()

def main():
    print("=== OneQubitEulerDecomposer Tests ===")
    print()

    run_test("Identity",  make_identity())
    run_test("Hadamard",  make_hadamard())
    run_test("Pauli X",   make_pauli_x())
    run_test("Pauli Y",   make_pauli_y())
    run_test("T gate",    make_t_gate())