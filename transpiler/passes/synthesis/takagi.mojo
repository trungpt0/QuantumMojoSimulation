from qmath import Matrix4x4, Complex
from transpiler.passes.synthesis import Jacobi4

struct TakagiUnitarySymmetric:
    var jacobi: Jacobi4
    
    def __init__(out self):
        self.jacobi = Jacobi4(60, 1e-28)

    def decompose(self, M: Matrix4x4) -> Tuple[Matrix4x4, List[Complex]]:
        var X = List[List[Complex]]()
        var Y = List[List[Complex]]()
        for r in range(4):
            var rowX = List[Complex]()
            var rowY = List[Complex]()
            for c in range(4):
                var v = M.get(r, c)
                rowX.append(v.re)
                rowY.append(v.im)
            X.append(rowX)
            Y.append(rowY)
        var c1: Float64 = 0.7361265311
        var c2: Float64 = 0.2984718253
        var combo = List[List[Float64]]()
        for r in range(4):
            var row = List[Float64]()
            for c in range(4):
                row.append(c1 * X[r][c] + c2 * Y[r][c])
            combo.append(row)
        var eig = self.jacobi.eigh(combo)
        var Vreal = eig[0]
        var det = self._det4_real(Vreal)
        if det < 0.0:
            for r in range(4):
                Vreal[r][0] = -Vreal[r][0]
        var P = Matrix4x4()
        for r in range(4):
            for c in range(4):
                P.set(r, c, Complex(Vreal[r][c], 0.0))
        var Pt = P.transpose()
        var PtMP = Pt.mul(M.mul(P))
        var D = List[Complex]()
        for i in range(4):
            D.append(PtMP.get(i, i))
        return (P, D)