from qmath import Complex, random_int, sqrt
from gates import *

struct QuantumCircuit(Copyable, Movable):
    var n: Int
    var psi: List[Complex]
    var gates: List[GateOp]

    def __init__(out self, n: Int):
        self.n = n
        var N = 1 << n
        self.psi = List[Complex]()
        self.gates = List[GateOp]()
        for i in range(N):
            if i == 0:
                self.psi.append(Complex(1.0, 0.0))
            else:
                self.psi.append(Complex(0.0, 0.0))

    def __copyinit__(out self, other: Self):
        self.n = other.n
        self.psi = other.psi.copy()
        self.gates = other.gates.copy()

    def __moveinit__(out self, owned other: Self):
        self.n = other.n
        self.psi = other.psi^
        self.gates = other.gates^

    def _q1(self, q: Int) -> List[Int]:
        var qubit = List[Int]()
        qubit.append(q)
        return qubit^

    def _q2(self, q1: Int, q2: Int) -> List[Int]:
        var qubit = List[Int]()
        qubit.append(q1)
        qubit.append(q2)
        return qubit^

    def _t(self, t: Float64) -> List[Float64]:
        var theta = List[Float64]()
        theta.append(t)
        return theta^

    def I(mut self, w: Int):
        self.psi = I(self.psi, w)
        self.gates.append(GateOp("I", self._q1(w)))

    def X(mut self, w: Int):
        self.psi = X(self.psi, w)
        self.gates.append(GateOp("X", self._q1(w)))

    def Y(mut self, w: Int):
        self.psi = Y(self.psi, w)
        self.gates.append(GateOp("Y", self._q1(w)))

    def Z(mut self, w: Int):
        self.psi = Z(self.psi, w)
        self.gates.append(GateOp("Z", self._q1(w)))

    def H(mut self, w: Int):
        self.psi = H(self.psi, w)
        self.gates.append(GateOp("H", self._q1(w)))

    def S(mut self, w: Int):
        self.psi = S(self.psi, w)
        self.gates.append(GateOp("S", self._q1(w)))

    def Sdg(mut self, w: Int):
        self.psi = Sdg(self.psi, w)
        self.gates.append(GateOp("SDG", self._q1(w)))

    def T(mut self, w: Int):
        self.psi = T(self.psi, w)
        self.gates.append(GateOp("T", self._q1(w)))

    def Tdg(mut self, w: Int):
        self.psi = Tdg(self.psi, w)
        self.gates.append(GateOp("TDG", self._q1(w)))

    def RX(mut self, w: Int, theta: Float64):
        self.psi = RX(self.psi, w, theta)
        self.gates.append(GateOp("RX", self._q1(w), self._t(theta)))

    def RY(mut self, w: Int, theta: Float64):
        self.psi = RY(self.psi, w, theta)
        self.gates.append(GateOp("RY", self._q1(w), self._t(theta)))

    def RZ(mut self, w: Int, theta: Float64):
        self.psi = RZ(self.psi, w, theta)
        self.gates.append(GateOp("RZ", self._q1(w), self._t(theta)))

    def P(mut self, w: Int, theta: Float64):
        self.psi = P(self.psi, w, theta)
        self.gates.append(GateOp("P", self._q1(w), self._t(theta)))

    def IP(mut self, w: Int, theta: Float64):
        self.psi = IP(self.psi, w, theta)
        self.gates.append(GateOp("IP", self._q1(w), self._t(theta)))
        
    def CX(mut self, c: Int, t: Int):
        self.psi = CX(self.psi, c, t)
        self.gates.append(GateOp("CX", self._q2(c, t)))

    def measure(mut self, w: Int) -> Int:
        var n = self.n
        var N = 1 << n
        var p0: Float64 = 0.0
        var p1: Float64 = 0.0
        for i in range(N):
            var bit = (i >> (n - w - 1)) & 1
            var p = self.psi[i].re * self.psi[i].re + self.psi[i].im * self.psi[i].im
            if bit == 0:
                p0 += p
            else:
                p1 += p
        var r = Float64(random_int(0, 2147483648)) / Float64(2147483647)
        var out: Int = 0
        if r >= p0:
            out = 1
        var new_psi = List[Complex]()
        var norm: Float64 = 0.0
        if out == 0:
            norm = p0
        else:
            norm = p1
        var inv_norm = 1.0 / sqrt(norm) if norm > 1e-15 else 0.0
        for i in range(N):
            var bit = (i >> (n - w - 1)) & 1
            if bit == out:
                new_psi.append(Complex(
                    self.psi[i].re * inv_norm,
                    self.psi[i].im * inv_norm
                ))
            else:
                new_psi.append(Complex(0.0, 0.0))
        self.psi = new_psi^
        self.gates.append(GateOp("MEASURE", self._q1(w)))
        return out

    def X_test(self):
        X_test(self.psi)

    def Y_test(self):
        Y_test(self.psi)

    def Z_test(self):
        Z_test(self.psi)

    def H_test(self):
        H_test(self.psi)
    
    def S_test(self):
        S_test(self.psi)

    def T_test(self):
        T_test(self.psi)

    def RX_test(self, theta: Float64):
        RX_test(self.psi, theta)

    def RY_test(self, theta: Float64):
        RY_test(self.psi, theta)

    def RZ_test(self, theta: Float64):
        RZ_test(self.psi, theta)

    def P_test(self, theta: Float64):
        P_test(self.psi, theta)
    
    def IP_test(self, theta: Float64):
        IP_test(self.psi, theta)

    def CX_test(self):
        CX_test(self.psi)

    def print_psi(self):
        print("Num Qubits:", self.n)
        for amp in range(len(self.psi)):
            print("psi[", amp, "] = ", self.psi[amp].re, " + ", self.psi[amp].im, "i")