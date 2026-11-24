from std.math import sqrt, cos, sin, atan2
from qmath import CMatrix, PI
from gates import GateOp
from gateop_shortcut import _RZ, _RY, _RX, _SX

comptime ANG_EPS = 1e-12

def wrap_angle(a: Float64) -> Float64:
    var x = a
    while x > PI:
        x -= 2.0 * PI
    while x <= -PI:
        x += 2.0 * PI
    return x

struct Gate1Q:

    @staticmethod
    def _put(mut m: CMatrix, i: Int, j: Int, re: Float64, im: Float64):
        m.re[i * 2 + j] = re
        m.im[i * 2 + j] = im

    @staticmethod
    def rz(a: Float64) -> CMatrix:
        var m = CMatrix(2)
        Gate1Q._put(m, 0, 0, cos(0.5 * a), -sin(0.5 * a))
        Gate1Q._put(m, 1, 1, cos(0.5 * a), sin(0.5 * a))
        return m^

    @staticmethod
    def ry(a: Float64) -> CMatrix:
        var m = CMatrix(2)
        Gate1Q._put(m, 0, 0, cos(0.5 * a), 0.0)
        Gate1Q._put(m, 0, 1, -sin(0.5 * a), 0.0)
        Gate1Q._put(m, 1, 0, sin(0.5 * a), 0.0)
        Gate1Q._put(m, 1, 1, cos(0.5 * a), 0.0)
        return m^

    @staticmethod
    def rx(a: Float64) -> CMatrix:
        var m = CMatrix(2)
        Gate1Q._put(m, 0, 0, cos(0.5 * a), 0.0)
        Gate1Q._put(m, 0, 1, 0.0, -sin(0.5 * a))
        Gate1Q._put(m, 1, 0, 0.0, -sin(0.5 * a))
        Gate1Q._put(m, 1, 1, cos(0.5 * a), 0.0)
        return m^

    @staticmethod
    def h() -> CMatrix:
        var r = 0.7071067811865476
        var m = CMatrix(2)
        Gate1Q._put(m, 0, 0, r, 0.0)
        Gate1Q._put(m, 0, 1, r, 0.0)
        Gate1Q._put(m, 1, 0, r, 0.0)
        Gate1Q._put(m, 1, 1, -r, 0.0)
        return m^

    @staticmethod
    def sx() -> CMatrix:
        var m = CMatrix(2)
        Gate1Q._put(m, 0, 0, 0.5, 0.5)
        Gate1Q._put(m, 0, 1, 0.5, -0.5)
        Gate1Q._put(m, 1, 0, 0.5, -0.5)
        Gate1Q._put(m, 1, 1, 0.5, 0.5)
        return m^

    @staticmethod
    def u(theta: Float64, phi: Float64, lam: Float64) -> CMatrix:
        var c = cos(0.5 * theta)
        var s = sin(0.5 * theta)
        var m = CMatrix(2)
        Gate1Q._put(m, 0, 0, c, 0.0)
        Gate1Q._put(m, 0, 1, -cos(lam) * s, -sin(lam) * s)
        Gate1Q._put(m, 1, 0, cos(phi) * s, sin(phi) * s)
        Gate1Q._put(m, 1, 1, cos(phi + lam) * c, sin(phi + lam) * c)
        return m^

    @staticmethod
    def of(g: GateOp) raises -> CMatrix:
        var nm = g.name
        if nm == "RZ":
            return Gate1Q.rz(g.theta[0])
        if nm == "RY":
            return Gate1Q.ry(g.theta[0])
        if nm == "RX":
            return Gate1Q.rx(g.theta[0])
        if nm == "SX":
            return Gate1Q.sx()
        if nm == "H":
            return Gate1Q.h()
        if nm == "U":
            return Gate1Q.u(g.theta[0], g.theta[1], g.theta[2])
        raise Error("Gate1Q.of: not support " + nm)

struct EulerDecomposer(Copyable, Movable):
    var basis: String
    var eps: Float64

    def __init__(out self, basis: String = "ZYZ", eps: Float64 = ANG_EPS) raises:
        if basis != "ZYZ" and basis != "ZXZ" and basis != "ZSX" and basis != "U":
            raise Error("EulerDecomposer: not support " + basis)
        self.basis = basis
        self.eps = eps

    @staticmethod
    def angles(u: CMatrix) -> Tuple[Float64, Float64, Float64]:
        var ar = u.re[0]
        var ai = u.im[0]
        var cr = u.re[1]
        var ci = u.im[1]
        var br = u.re[2]
        var bi = u.im[2]
        var dr = u.re[3]
        var di = u.im[3]
        var detr = ar * dr - ai * di - (cr * br - ci * bi)
        var deti = ar * di + ai * dr - (cr * bi + ci * br)
        var gam = 0.5 * atan2(deti, detr)
        var pr = cos(-gam)
        var pi = sin(-gam)
        var a2r = ar * pr - ai * pi
        var a2i = ar * pi + ai * pr
        var b2r = br * pr - bi * pi
        var b2i = br * pi + bi * pr
        var na = sqrt(a2r * a2r + a2i * a2i)
        var nb = sqrt(b2r * b2r + b2i * b2i)
        var theta = 2.0 * atan2(nb, na)
        var phi: Float64
        var lam: Float64
        if nb < 1e-12:
            lam = -2.0 * atan2(a2i, a2r)
            phi = 0.0
        elif na < 1e-12:
            lam = 0.0
            phi = 2.0 * atan2(b2i, b2r)
        else:
            var arga = atan2(a2i, a2r)
            var argb = atan2(b2i, b2r)
            phi = argb - arga
            lam = -arga - argb
        return (theta, phi, lam)

    def _push(self, mut g: List[GateOp], q: Int, name: String, a: Float64):
        var w = wrap_angle(a)
        if abs(w) <= self.eps:
            return
        if name == "RZ":
            g.append(_RZ(q, w))
        elif name == "RY":
            g.append(_RY(q, w))
        else:
            g.append(_RX(q, w))
    
    def _push_u(self, mut g: List[GateOp], q: Int, theta: Float64, phi: Float64, lam: Float64):
        var qs = List[Int]()
        qs.append(q)
        var ps = List[Float64]()
        ps.append(theta)
        ps.append(phi)
        ps.append(lam)
        g.append(GateOp("U", qs, ps))
    
    def gates(self, u: CMatrix, q: Int) raises -> List[GateOp]:
        if u.n != 2:
            raise Error("EulerDecomposer: just decompose one-qubit gate")
        var t = EulerDecomposer.angles(u)
        var theta = wrap_angle(t[0])
        var phi = t[1]
        var lam = t[2]
        var g = List[GateOp]()
        if abs(theta) <= self.eps:
            if self.basis == "U":
                var w = wrap_angle(phi + lam)
                if abs(w) > self.eps:
                    self._push_u(g, q, 0.0, 0.0, w)
            else:
                self._push(g, q, "RZ", phi + lam)
            return g^
        if abs(theta - PI) <= self.eps:
            var delta = 0.0
            if self.basis == "ZXZ":
                delta = 0.5 * PI - lam
            elif self.basis == "ZYZ" or self.basis == "ZSX":
                delta = -lam
            phi += delta
            lam += delta
        if self.basis == "ZSX" and abs(theta - 0.5 * PI) <= self.eps:
            self._push(g, q, "RZ", lam - 0.5 * PI)
            g.append(_SX(q))
            self._push(g, q, "RZ", phi + 0.5 * PI)
            return g^
        if self.basis == "ZYZ":
            self._push(g, q, "RZ", lam)
            self._push(g, q, "RY", theta)
            self._push(g, q, "RZ", phi)
        elif self.basis == "ZXZ":
            self._push(g, q, "RZ", lam - 0.5 * PI)
            self._push(g, q, "RX", theta)
            self._push(g, q, "RZ", phi + 0.5 * PI)
        elif self.basis == "ZSX":
            self._push(g, q, "RZ", lam)
            g.append(_SX(q))
            self._push(g, q, "RZ", theta + PI)
            g.append(_SX(q))
            self._push(g, q, "RZ", phi + PI)
        else:
            self._push_u(g, q, theta, wrap_angle(phi), wrap_angle(lam))
        return g^

    @staticmethod
    def matrix(gates: List[GateOp], q: Int) raises -> CMatrix:
        var m = CMatrix.identity(2)
        for i in range(len(gates)):
            if gates[i].qubit[0] != q:
                continue
            m = Gate1Q.of(gates[i]).matmul(m)
        return m^

    def verify(self, u: CMatrix) raises -> Float64:
        return phase_error(u, EulerDecomposer.matrix(self.gates(u, 0), 0))

def mat_rz(a: Float64) -> CMatrix:
    return Gate1Q.rz(a)

def mat_ry(a: Float64) -> CMatrix:
    return Gate1Q.ry(a)

def mat_rx(a: Float64) -> CMatrix:
    return Gate1Q.rx(a)

def mat_h() -> CMatrix:
    return Gate1Q.h()

def mat_sx() -> CMatrix:
    return Gate1Q.sx()

def mat_u(theta: Float64, phi: Float64, lam: Float64) -> CMatrix:
    return Gate1Q.u(theta, phi, lam)

def zyz_angles(u: CMatrix) -> Tuple[Float64, Float64, Float64]:
    return EulerDecomposer.angles(u)

def one_qubit_gates(u: CMatrix, q: Int, basis: String = "ZYZ") raises -> List[GateOp]:
    return EulerDecomposer(basis).gates(u, q)

def one_qubit_matrix(gates: List[GateOp], q: Int) raises -> CMatrix:
    return EulerDecomposer.matrix(gates, q)