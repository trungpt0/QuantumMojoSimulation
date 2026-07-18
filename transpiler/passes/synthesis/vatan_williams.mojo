from gates import GateOp
from qmath import PI, abs

struct VatanWilliams:
    var tol: Float64

    def __init__(out self, tol: Float64 = 1e-10):
        self.tol = tol

    def synthesize(self, alpha: Float64, beta: Float64, gamma: Float64, q0: Int, q1: Int) -> List[GateOp]:
        var gates = List[GateOp]()
        var q0l = List[Int](); q0l.append(q0)
        var q1l = List[Int](); q1l.append(q1)
        var q01 = List[Int](); q01.append(q0); q01.append(q1)
        var q10 = List[Int](); q10.append(q1); q10.append(q0)
        gates.append(GateOp("CX", q10, List[Float64]()))
        var rz = 2.0 * gamma - PI / 2.0
        if abs(rz) > self.tol:
            var p = List[Float64](); p.append(rz)
            gates.append(GateOp("RZ", q0l, p))
        var ry1 = PI / 2.0 - 2.0 * alpha
        if abs(ry1) > self.tol:
            var p = List[Float64](); p.append(ry1)
            gates.append(GateOp("RY", q1l, p))
        gates.append(GateOp("CX", q01, List[Float64]()))
        var ry2 = 2.0 * beta - PI / 2.0
        if abs(ry2) > self.tol:
            var p = List[Float64](); p.append(ry2)
            gates.append(GateOp("RY", q1l, p))
        gates.append(GateOp("CX", q10, List[Float64]()))
        return gates^