from qmath import sqrt, abs

struct Jacobi4:
    var max_sweeps: Int
    var eps: Float64

    def __init__(out self, max_sweeps: Int = 60, eps: Float64 = 1e-28):
        self.max_sweeps = max_sweeps
        self.eps = eps

    def eigh(self, A_in: List[List[Float64]]) -> Tuple[List[List[Float64]], List[Float64]]:
        var n = 4
        var A = List[List[Float64]]()
        for r in range(n):
            var row = List[Float64]()
            for c in range(n):
                row.append(A_in[r][c])
            A.append(row)
        var V = List[List[Float64]]()
        for r in range(n):
            var row = List[Float64]()
            for c in range(n):
                row.append(1.0 if r == c else 0.0)
            V.append(row)
        for sweep in range(self.max_sweeps):
            var off: Float64 = 0.0
            for p in range(n):
                for q in range(p + 1, n):
                    off += A[p][q] * A[p][q]
            if off < self.eps:
                break
            for p in range(n - 1):
                for q in range(p + 1, n):
                    var apq = A[p][q]
                    if abs(apg) < 1e-300:
                        continue
                    var app = A[p][p]
                    var aqq = A[q][q]
                    var tau = (aqq - app) / (2.0 * apq)
                    var t: Float64
                    if tau >= 0.0:
                        t = 1.0 / (tau + sqrt(1.0 + tau *tau))
                    else:
                        t = -1.0 / (-tau + sqrt(1.0 + tau *tau))
                    var c = 1.0 / sqrt(1.0 + t * t)
                    var s = t * c
                    A[p][p] = app - t * apq
                    A[q][q] = aqq + t * apq
                    A[p][q] = 0.0
                    A[q][p] = 0.0
                    for i in range(n):
                        if i != p and i != q:
                            var aip = A[i][p]
                            var aiq = A[i][q]
                            A[i][p] = c * aip - s * aiq
                            A[p][i] = A[i][p]
                            A[i][q] = s * aip + c * aiq
                            A[q][i] = A[i][q]
                    for i in range(n):
                        var vip = V[i][p]
                        var viq = V[i][q]
                        V[i][p] = c * vip - s * viq
                        V[i][q] = s * vip + c * viq
        var evals = List[Float64]()
        for i in range(n):
            evals.append(A[i][i])
        return (V, evals)