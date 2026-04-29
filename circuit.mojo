from qmath import *
from gates import *

struct QuantumCircuit:
    var n: Int
    var psi: List[Complex]

    def __init__(out self, n: Int):
        self.n = n
        var N = 1 << n
        self.psi = List[Complex]()
        for i in range(N):
            if i == 0:
                self.psi.append(Complex(1.0, 0.0))
            else:
                self.psi.append(Complex(0.0, 0.0))

    def X(mut self, w: Int):
        self.psi = X(self.psi, w)

    def Y(mut self, w: Int):
        self.psi = Y(self.psi, w)

    def Z(mut self, w: Int):
        self.psi = Z(self.psi, w)

    def H(mut self, w: Int):
        self.psi = H(self.psi, w)

    def S(mut self, w: Int):
        self.psi = S(self.psi, w)

    def Sdg(mut self, w: Int):
        self.psi = Sdg(self.psi, w)

    def T(mut self, w: Int):
        self.psi = T(self.psi, w)

    def RX(mut self, w: Int, theta: Float64):
        self.psi = RX(self.psi, w, theta)

    def RY(mut self, w: Int, theta: Float64):
        self.psi = RY(self.psi, w, theta)

    def RZ(mut self, w: Int, theta: Float64):
        self.psi = RZ(self.psi, w, theta)

    def P(mut self, w: Int, theta: Float64):
        self.psi = P(self.psi, w, theta)

    def IP(mut self, w: Int, theta: Float64):
        self.psi = IP(self.psi, w, theta)
        
    def CX(mut self, c: Int, t: Int):
        self.psi = CX(self.psi, c, t)

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