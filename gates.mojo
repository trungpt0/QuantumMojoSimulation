from qmath import Complex, inv
from std.math import cos, sin
from apply_gate import apply_single_qubit_gate, apply_cx_gate
from qutils import assert_equal

def X(psi: List[Complex], w: Int) -> List[Complex]:
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(0.0, 0.0),
        Complex(1.0, 0.0),
        Complex(1.0, 0.0),
        Complex(0.0, 0.0)
    )

def Y(psi: List[Complex], w: Int) -> List[Complex]:
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(0.0, 0.0),
        Complex(0.0, -1.0),
        Complex(0.0, 1.0),
        Complex(0.0, 0.0)
    )

def Z(psi: List[Complex], w: Int) -> List[Complex]:
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(1.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, 0.0),
        Complex(-1.0, 0.0)
    )

def H(psi: List[Complex], w: Int) -> List[Complex]:
    var inv = inv()
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(inv, 0.0),
        Complex(inv, 0.0),
        Complex(inv, 0.0),
        Complex(-inv, 0.0)
    )

def S(psi: List[Complex], w: Int) -> List[Complex]:
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(1.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, 1.0)
    )

def T(psi: List[Complex], w: Int) -> List[Complex]:
    var inv = inv()
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(1.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, 0.0),
        Complex(inv, inv)
    )

def RX(psi: List[Complex], w: Int, theta: Float64) -> List[Complex]:
    var c = cos(theta / 2.0)
    var s = sin(theta / 2.0)
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(c, 0.0),
        Complex(0.0, -s),
        Complex(0.0, -s),
        Complex(c, 0.0)
    )

def RY(psi: List[Complex], w: Int, theta: Float64) -> List[Complex]:
    var c = cos(theta / 2.0)
    var s = sin(theta / 2.0)
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(c, 0.0),
        Complex(-s, 0.0),
        Complex(s, 0.0),
        Complex(c, 0.0)
    )

def RZ(psi: List[Complex], w: Int, theta: Float64) -> List[Complex]:
    var c = cos(theta / 2.0)
    var s = sin(theta / 2.0)
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(c, -s),
        Complex(0.0, 0.0),
        Complex(0.0, 0.0),
        Complex(c, s)
    )

def P(psi: List[Complex], w: Int, theta: Float64) -> List[Complex]:
    var c = cos(theta)
    var s = sin(theta)
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(1.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, 0.0),
        Complex(c, s)
    )

def IP(psi: List[Complex], w: Int, theta: Float64) -> List[Complex]:
    var c = cos(theta)
    var s = sin(theta)
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(1.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, 0.0),
        Complex(c, -s)
    )

def CX(psi: List[Complex], c: Int, t: Int) -> List[Complex]:
    return apply_cx_gate(psi, c, t)

def X_test(psi: List[Complex]):
    var psi_test = X(psi, 0)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "X gate")

def Y_test(psi: List[Complex]):
    var psi_test = Y(psi, 0)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 1.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "Y gate")

def Z_test(psi: List[Complex]):
    var psi_test = Z(psi, 0)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "Z gate")

def H_test(psi: List[Complex]):
    var psi_test = H(psi, 0)
    var inv = inv()
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(inv, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(inv, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "H gate")

def S_test(psi: List[Complex]):
    var psi_test = S(psi, 0)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "S gate")

def T_test(psi: List[Complex]):
    var psi_test = T(psi, 0)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "T gate")

def RX_test(psi: List[Complex], theta: Float64):
    var psi_test = RX(psi, 0, theta)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, -1.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "RX gate")

def RY_test(psi: List[Complex], theta: Float64):
    var psi_test = RY(psi, 0, theta)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "RY gate")

def RZ_test(psi: List[Complex], theta: Float64):
    var psi_test = RZ(psi, 0, theta)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(0.0, -1.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "RZ gate")

def P_test(psi: List[Complex], theta: Float64):
    var psi_test = P(psi, 0, theta)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "P gate")

def IP_test(psi: List[Complex], theta: Float64):
    var psi_test = IP(psi, 0, theta)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "IP gate")

def CX_test(psi: List[Complex]):
    var psi_test = CX(psi, 0, 1)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "CX gate")