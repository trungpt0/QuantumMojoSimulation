from qmath import Matrix2x2, Matrix4x4, Complex, inv, abs
from std.math import atan2, cos, sin
from transipler.passes.synthesis import MagicBasis
from transpiler.passes.synthesis import TakagiUnitarySymmetric

struct WeylDecomposition:
    var tol: Float64
    var takagi: TakagiUnitarySymmetric

    def __init__(out self, tol: Float64 = 1e-10):
        self.tol = tol
        self.takagi = TakagiUnitarySymmetric()

    def _diag4(self, evals: List[Complex]) -> Matrix4x4:
        var D = Matrix4x4()
        for r in range(4):
            for c in range(4):
                D.set(r, c, Complex(0.0, 0.0))
        for i in range(4):
            D.set(i, i, evals[i])
        return D^

    def _pauli_XX(self) -> Matrix4x4:
        var M = Matrix4x4()
        for r in range(4):
            for c in range(4):
                M.set(r, c, Complex(0.0, 0.0))
        var one = Complex(1.0, 0.0)
        M.set(0, 3, one); M.set(1, 2, one)
        M.set(2, 1, one); M.set(3, 0, one)
        return M^

    def _pauli_YY(self) -> Matrix4x4:
        var M = Matrix4x4()
        for r in range(4):
            for c in range(4):
                M.set(r, c, Complex(0.0, 0.0))
        M.set(0, 3, Complex(-1.0, 0.0))
        M.set(1, 2, Complex(1.0, 0.0))
        M.set(2, 1, Complex(1.0, 0.0))
        M.set(3, 0, Complex(-1.0, 0.0))
        return M^

    def _pauli_ZZ(self) -> Matrix4x4:
        var M = Matrix4x4()
        for r in range(4):
            for c in range(4):
                M.set(r, c, Complex(0.0, 0.0))
        M.set(0, 0, Complex(1.0, 0.0))
        M.set(1, 1, Complex(-1.0, 0.0))
        M.set(2, 2, Complex(-1.0, 0.0))
        M.set(3, 3, Complex(1.0, 0.0))
        return M^
    
    def decompose(self, U: Matrix4x4) -> Tuple[
        Matrix4x4,      # K1
        Float64,        # alpha
        Float64,        # beta
        Float64,        # gamma
        Matrix4x4,      # K2
        Float64,        # global phase
    ]:
        var detU = U.determinant()
        # var phase = detU.pow(1.0 / 4.0)
        var theta = atan2(detU.im, detU.re)
        var phase = Complex(cos(theta * 0.25), sin(theta * 0.25))
        var Usu4 = Matrix4x4()
        for r in range(4):
            for c in range(4):
                var v = U.get(r, c)
                Usu4.set(r, c, v.div(phase))
        # ----------------------------------------
        # ASSERT 1: check SU(4) projection
        # var detUsu4 = Usu4.determinant()
        # assert abs(detUsu4.re - 1.0) < 1e-6
        # assert abs(detUsu4.im) < 1e-6
        # ----------------------------------------
        # Step 1: U' = B† U B
        var Up = MagicBasis.to_magic_basis(Usu4)
        # ----------------------------------------
        # var Up_dag = Up.dagger()
        # var I = Up_dag.mul(Up)
        # ASSERT 2: unitary check
        # for i in range(4):
        #     for j in range(4):
        #         var expected = Complex(1.0 if i == j else 0.0, 0.0)
        #         assert abs(I.get(i,j).re - expected.re) < 1e-6
        #         assert abs(I.get(i,j).im - expected.im) < 1e-6
        # ----------------------------------------
        # Step 2: M2 = Θ (U'†) U' = (U'†) U' = U'† U'
        var UpT = Up.transpose()
        var M2 = UpT.mul(Up)
        # ----------------------------------------
        # ASSERT 3: M2 must be symmetric
        # var err = 0.0
        # for i in range(4):
        #     for j in range(4):
        #         err += abs(M2.get(i,j).re - M2.get(j,i).re)
        # assert err < 1e-6
        # ----------------------------------------
        # Step 3: M2 = P D P⊤, where D ∈ exp(h) and P ∈ SO(4)
        var pd = takagi.decompose(M2)
        var P = pd[0]
        var D = pd[1]
        # Step 4: D¹ᐟ² and K' = U' P D⁻¹ᐟ² P†
        var sqrtD = List[Complex]()
        for i in range(4):
            var theta = atan2(D[i].im, D[i].re)
            sqrtD.append(Complex(cos(theta * 0.5), sin(theta * 0.5)))
        var prob = Complex(1.0, 0.0)
        for i in range(4):
            prob = prob.mul(sqrtD[i])
        if prob.re < 0.0:
            sqrtD[0] = Complex(-sqrtD[0].re, -sqrtD[0].im)
        var isqrtD = List[Complex]()
        for i in range(4):
            isqrtD.append(Complex(sqrtD[i].re, -sqrtD[i].im))
        var D12  = self._diag4(sqrtD)
        var Dm12 = self._diag4(isqrtD)
        Pd = P.dagger()
        var Kp = Up.mul(P.mul(Dm12.mul(Pd)))
        # Step 5: K1 = B K' P B† and K2 = B P† B† and A = B D¹ᐟ² B†
        K1 = MagicBasis.from_magic_basis(Kp.mul(P))
        K2 = MagicBasis.from_magic_basis(Pd)
        A = MagicBasis.from_magic_basis(D12)
        # Step 6: α, β and γ
        var theta_vec = List[Complex]()
        for i in range(4):
            theta_vec.append(Complex(atan2(sqrtD[i].im, sqrtD[i].re), 0.0))
        var H = MagicBasis.from_magic_basis(self._diag4(theta_vec))
        var alpha = H.mul(self._pauli_XX()).trace().re / 4.0
        var beta = H.mul(self._pauli_YY()).trace().re / 4.0
        var gamma = H.mul(self._pauli_ZZ()).trace().re / 4.0
        var gp_angle = atan2(phase.im, phase.re)
        return (K1, alpha, beta, gamma, K2, gp_angle)

struct WeylChamber:

        