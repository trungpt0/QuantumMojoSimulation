from qmath import GateMatrix, Matrix2x2, Complex, sqrt, abs, PI
from gates import GateOp
from std.math import atan2, cos, sin

struct EulerSU2:
    var tol: Float64

    def __init__(out self, tol: Float64 = 1e-10):
        self.tol = tol

    def _csqrt(self, z: Complex) -> Complex:
        var theta = atan2(z.im, z.re)
        var r = z.abs()
        return Complex(r * cos(theta * 0.5), r * sin(theta * 0.5))

    def decompose(self, G: Matrix2x2) -> Tuple[Float64, Float64, Float64]:
        var Y = GateMatrix.get_1q("Y", List[Float64]())
        var Gd = G.dagger()
        # Step 1: M² = Y G† Y G
        var M2 = Y.mul(Gd.mul(Y.mul(G)))
        # Step 2: M² = P D P†
        var a = M2.get(0, 0)
        var b = M2.get(0, 1)
        var c = M2.get(1, 0)
        var d = M2.get(1, 1)
        var tr = a.add(d)
        var det = a.mul(d).sub(b.mul(c))
        var disc = self._csqrt(tr.mul(tr).sub(det.mul(Complex(4.0, 0.0))))
        var lam1 = tr.add(disc).div(Complex(2.0, 0.0))
        var lam2 = tr.sub(disc).div(Complex(2.0, 0.0))
        var v1 = List[Complex]()
        if b.abs() > self.tol:
            v1.append(b)
            v1.append(lam1.sub(a))
        if c.abs() > self.tol:
            v1.append(lam1.sub(d))
            v1.append(c)
        else:
            v1.append(Complex(1.0, 0.0))
            v1.append(Complex(0.0, 0.0))
        var norm = sqrt(v1[0].abs()**2 + v1[1].abs()**2)
        v1[0] = v1[0].div(Complex(norm, 0.0))
        v1[1] = v1[1].div(Complex(norm, 0.0))
        var ref_comp = v1[0]
        if v1[0].abs() < self.tol:
            ref_comp = v1[1]
        var phi = -atan2(ref_comp.im, ref_comp.re)
        var rephase = Complex(cos(phi), sin(phi))
        v1[0] = v1[0].mul(rephase)
        v1[1] = v1[1].mul(rephase)
        var v2 = List[Complex]()
        v2.append(Complex(-v1[1].re, v1[1].im))
        v2.append(Complex(v1[0].re, -v1[0].im))
        var P = Matrix2x2()
        P.set(0, 0, v1[0]); P.set(0, 1, v2[0])
        P.set(1, 0, v1[1]); P.set(1, 1, v2[1])
        # Step 3: K = G M†
        var sqrtD = List[Complex]()
        sqrtD.append(self._csqrt(lam1))
        sqrtD.append(self._csqrt(lam2))
        var prod = sqrtD[0].mul(sqrtD[1])
        if prod.re < 0.0:
            sqrtD[0] = Complex(-sqrtD[0].re, -sqrtD[0].im)
        var Dm12 = Matrix2x2()
        Dm12.set(0, 0, Complex(sqrtD[0].re, -sqrtD[0].im))
        Dm12.set(1, 1, Complex(sqrtD[1].re, -sqrtD[1].im))
        Dm12.set(0, 1, Complex(0.0, 0.0))
        Dm12.set(1, 0, Complex(0.0, 0.0))
        var Pd = P.dagger()
        var M  = P.mul(Dm12.mul(Pd)).dagger()
        var K = G.mul(M.dagger())    
        # Step 4: extract the angles A, B and C
        var alpha = atan2(K.get(0, 1).re, K.get(0, 0).re)
        var gamma = atan2(P.get(0, 1).re, P.get(0, 0).re)
        var beta = atan2(sqrtD[0].im, sqrtD[0].re)
        var A = alpha + gamma
        var B = beta
        var C = -gamma
        return (A, B, C)

struct EulerSU2ToGates:
    var tol: Float64

    def __init__(out self, tol: Float64 = 1e-10):
        self.tol = tol
        
    def synthesize(self, A: Float64, B: Float64, C: Float64, q: Int) -> List[GateOp]:
        var gates = List[GateOp]()
        var ql = List[Int]()
        ql.append(q)
        var theta_C = -2.0 * C
        if abs(theta_C) > self.tol:
            var p = List[Float64]()
            p.append(theta_C)
            gates.append(GateOp("RY", ql, p))
        var theta_B = -2.0 * B
        if abs(theta_B) > self.tol:
            var p = List[Float64]()
            p.append(theta_B)
            gates.append(GateOp("RZ", ql, p))
        var theta_A = -2.0 * A
        if abs(theta_A) self.tol:
            var p = List[Float64](); p.append(theta_A)
            gates.append(GateOp("RY", ql, p))
        return gates^