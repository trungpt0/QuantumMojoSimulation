from qmath import Matrix4x4, Matrix2x2, Complex
from std.math import cos, sin, atan2

struct TensorFactorize:
    """
    SO(4) = SU(2) ⊗ SU(2)
    """
    var tol: Float64

    def __init__(out self, tol: Float64 = 1e-10):
        self.tol = tol

    def _dominant_left_sv(self, M: List[List[Complex]]) -> List[Complex]:
        var v = List[Complex]()
        for i in range(4):
            v.append(Complex(0.5, 0.0))
        for _iter in range(50):
            var u = List[Complex]()
            for i in range(4):
                var s = Complex(0.0, 0.0)
                for j in range(4):
                    s = s.add(M[i][j].mul(v[j]))
                u.append(s)
            for j in range(4):
                var s = Complex(0.0, 0.0)
                for i in range(4):
                    var Mij_c = Complex(M[i][j].re, -M[i][j].im)
                    s = s.add(Mij_c.mul(u[i]))
                v_new.append(s)
            var n_sq: Float64 = 0.0
            for j in range(4):
                n_sq += v_new[j].re*v_new[j].re + v_new[j].im*v_new[j].im
            var n = n_sq ** 0.5
            if n < 1e-15: break
            for j in range(4):
                v[j] = Complex(v_new[j].re / n, v_new[j].im / n)
        var u_final = List[Complex]()
        for i in range(4):
            var s = Complex(0.0, 0.0)
            for j in range(4):
                s = s.add(M[i][j].mul(v[j]))
            u_final.append(s)
        var n_sq: Float64 = 0.0
        for i in range(4):
            n_sq += u_final[i].re*u_final[i].re + u_final[i].im*u_final[i].im
        var n = n_sq ** 0.5
        if n > 1e-15:
            for i in range(4):
                u_final[i] = Complex(u_final[i].re / n, u_final[i].im / n)
        return u_final^

    def _to_su2(self, M: Matrix2x2) -> Matrix2x2:
        var det = M.get(0,0).mul(M.get(1,1)).sub(M.get(0,1).mul(M.get(1,0)))
        var det_norm = (det.re*det.re + det.im*det.im) ** 0.5
        if det_norm < 1e-12:
            return Matrix2x2()
        var phase = Complex(det.re / det_norm, det.im / det_norm)
        var atan2_ph = atan2(phase.im, phase.re) / 2.0
        var ph_half = Complex(cos(atan2_ph), sin(atan2_ph))
        var ph_inv  = Complex(ph_half.re, -ph_half.im)
        var result = Matrix2x2()
        for r in range(2):
            for c in range(2):
                result.set(r, c, ph_inv.mul(M.get(r, c)))
        return result^
    
    def factorize(self, K: Matrix4x4) -> Tuple[Matrix2x2, Matrix2x2]:
        var M = List[List[Complex]]()
        for a in range(4):
            var row = List[Complex]()
            for b in range(4):
                row.append(Complex(0.0, 0.0))
            M.append(row)
        for i0 in range(2):
            for j0 in range(2):
                var a = i0 * 2 + j0
                for i1 in range(2):
                    for j1 in range(2):
                        var b = i1 * 2 + j1
                        M[a][b] = K.get(i0*2+i1, j0*2+j1)
        var u_vec = self._dominant_left_sv(M)
        var sigma_sq: Float64 = 0.0
        for i in range(4):
            sigma_sq += u_vec[i].re*u_vec[i].re + u_vec[i].im*u_vec[i].im
        var v_vec = List[Complex]()
        for j in range(4):
            var s = Complex(0.0, 0.0)
            for i in range(4):
                var Mij_conj = Complex(M[i][j].re, -M[i][j].im)
                s = s.add(Mij_conj.mul(u_vec[i]))
            v_vec.append(s)
        var v_norm_sq: Float64 = 0.0
        for j in range(4):
            v_norm_sq += v_vec[j].re*v_vec[j].re + v_vec[j].im*v_vec[j].im
        var v_norm = v_norm_sq ** 0.5
        if v_norm > 1e-12:
            for j in range(4):
                v_vec[j] = Complex(v_vec[j].re / v_norm, v_vec[j].im / v_norm)
        var Kl = Matrix2x2()
        var Kr = Matrix2x2()
        for i0 in range(2):
            for j0 in range(2):
                Kl.set(i0, j0, u_vec[i0*2+j0])
        for i1 in range(2):
            for j1 in range(2):
                Kr.set(i1, j1, Complex(v_vec[i1*2+j1].re, -v_vec[i1*2+j1].im))
        Kl = self._to_su2(Kl)
        Kr = self._to_su2(Kr)
        return (Kl, Kr)
        