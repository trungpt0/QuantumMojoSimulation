from qmath import Matrix4x4

struct WeylDecomposition:
    var tol: Float64

    def __init__(out self, tol: Float64 = 1e-10):
        self.tol = tol

    def decompose(self, U: Matrix4x4) -> Tuple[
        Matrix4x4,      # K1
        Float64,        # alpha
        Float64,        # beta
        Float64,        # gamma
        Matrix4x4,      # K2
        Float64,        # global phase
    ]:
        var detU = U.determinant()
        var phase = detU.pow(1.0 / 4.0)