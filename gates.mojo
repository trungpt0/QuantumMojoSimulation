from qmath import Complex, inv
from std.math import cos, sin
from apply_gate import *
from qutils import assert_equal

struct GateOp(Copyable, Movable):
    var name: String
    var qubit: List[Int]
    var theta: List[Float64]

    def __init__(out self, name: String, qubit: List[Int]):
        self.name = name
        self.qubit = qubit.copy()
        self.theta = List[Float64]()

    def __init__(out self, name: String, qubit: List[Int], theta: List[Float64]):
        self.name = name
        self.qubit = qubit.copy()
        self.theta = theta.copy()

    def __str__(self) -> String:
        var s = self.name + "("
        for i in range(len(self.qubit)):
            if i > 0: s += ","
            s += String(self.qubit[i])
        if len(self.theta) > 0:
            s += "|"
            for i in range(len(self.theta)):
                if i > 0: s += ","
                s += String(self.theta[i])
        s += ")"
        return s
    
    def _q(self, q: Int) -> List[Int]:
        var qubit = List[Int]()
        qubit.append(q)
        return qubit^

    def _t(self, t: Float64) -> List[Float64]:
        var theta = List[Float64]()
        theta.append(t)
        return theta^

def I(psi: List[Complex], w: Int) -> List[Complex]:
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(1.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, 0.0),
        Complex(1.0, 0.0)
    )

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

def Sdg(psi: List[Complex], w: Int) -> List[Complex]:
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(1.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, -1.0)
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

def Tdg(psi: List[Complex], w: Int) -> List[Complex]:
    var inv = inv()
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(1.0, 0.0),
        Complex(0.0, 0.0),
        Complex(0.0, 0.0),
        Complex(inv, -inv)
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

def SX(psi: List[Complex], w: Int) -> List[Complex]:
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(0.5, 0.5),
        Complex(0.5, -0.5),
        Complex(0.5, -0.5),
        Complex(0.5, 0.5)
    )

def V(psi: List[Complex], w: Int) -> List[Complex]:
    return apply_single_qubit_gate(
        psi,
        w,
        Complex(0.5, 0.5),
        Complex(0.5, -0.5),
        Complex(0.5, -0.5),
        Complex(0.5, 0.5)
    )

def CX(psi: List[Complex], c: Int, t: Int) -> List[Complex]:
    return apply_cx_gate(psi, c, t)

def CY(psi: List[Complex], c: Int, t: Int) -> List[Complex]:
    return apply_cy_gate(psi, c, t)

def CZ(psi: List[Complex], c: Int, t: Int) -> List[Complex]:
    return apply_cz_gate(psi, c, t)

def SWAP(psi: List[Complex], w0: Int, w1: Int) -> List[Complex]:
    return apply_swap_gate(psi, w0, w1)

def ECR(psi: List[Complex], w0: Int, w1: Int) -> List[Complex]:
    return apply_ecr_gate(psi, w0, w1)

def CCX(psi: List[Complex], w0: Int, w1: Int, w2: Int) -> List[Complex]:
    return apply_ccx_gate(psi, w0, w1, w2)

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

def SX_test(psi: List[Complex]):
    var psi_test = SX(psi, 0)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(0.5, 0.5))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.5, -0.5))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "SX gate")

def V_test(psi: List[Complex]):
    var psi_test = V(psi, 0)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(0.5, 0.5))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.5, -0.5))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "V gate")

def CX_test(psi: List[Complex]):
    var psi_test = CX(psi, 0, 1)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "CX gate")

def CY_test(psi: List[Complex]):
    var psi_test = CY(psi, 0, 1)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "CY gate")

def CZ_test(psi: List[Complex]):
    var psi_test = CZ(psi, 0, 1)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "CZ gate")

def SWAP_test(psi: List[Complex]):
    var psi_test = SWAP(psi, 0, 1)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "SWAP gate")

def ECR_test(psi: List[Complex]):
    var psi_test = ECR(psi, 0, 1)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(inv(), 0.0))
    psi_expe.append(Complex(0.0, -inv()))
    assert_equal(psi_test, psi_expe, "ECR gate")

def CCX_test(psi: List[Complex]):
    var psi_test = CCX(psi, 0, 1, 2)
    var psi_expe = List[Complex]()
    psi_expe.append(Complex(1.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    psi_expe.append(Complex(0.0, 0.0))
    assert_equal(psi_test, psi_expe, "CCX gate")