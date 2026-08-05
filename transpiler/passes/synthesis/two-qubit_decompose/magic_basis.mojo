from qmath import Matrix4x4, Matrix2x2, Complex

struct MagicBasis:
    @staticmethod
    def magic_basis() -> Matrix4x4:
        """
        B = 1/sqrt(2) * [[1, i, 0, 0],
                         [0, 0, i, 1],
                         [0, 0, i,-1],
                         [1,-i, 0, 0]]
        """
        var inv = 1.0 / (2.0 ** 0.5)
        var r = Complex(inv, 0.0)
        var i = Complex(0.0, inv)
        var z = Complex(0.0, 0.0)
        var mi = Complex(0.0, -inv)
        var B = Matrix4x4()
        B.set(0, 0, r); B.set(0, 1, i); B.set(0, 2, z); B.set(0, 3, z)
        B.set(1, 0, z); B.set(1, 1, z); B.set(1, 2, i); B.set(1, 3, r)
        B.set(2, 0, z); B.set(2, 1, z); B.set(2, 2, i); B.set(2, 3, mi)
        B.set(3, 0, r); B.set(3, 1, mi); B.set(3, 2, z); B.set(3, 3, z)
        return B^
    
    @staticmethod
    def to_magic_basis(U: Matrix4x4) -> Matrix4x4:
        """
        U' = B† U B
        """
        var B = MagicBasis.magic_basis()
        var Bd = B.dagger()
        return Bd.mul(U.mul(B))

    @staticmethod
    def from_magic_basis(U: Matrix4x4) -> Matrix4x4:
        """
        U = B U' B†
        """
        var B = MagicBasis.magic_basis()
        var Bd = B.dagger()
        return B.mul(U.mul(Bd))