from qmath import inv, Complex
from std.math import sin, cos, abs, sqrt

struct Matrix2x2(Copyable, Movable):
    """
    @params: 
    a: 00 
    b: 01
    c: 10
    d: 11
    """
    var matrix: List[Complex]

    def __init__(out self):
        """I gate"""
        self.matrix = List[Complex]()
        self.matrix.append(Complex(1.0, 0.0))
        self.matrix.append(Complex(0.0, 0.0))
        self.matrix.append(Complex(0.0, 0.0))
        self.matrix.append(Complex(1.0, 0.0))

    def __init__(out self, a: Complex, b: Complex, c: Complex, d: Complex):
        self.matrix = List[Complex]()
        self.matrix.append(a.copy())
        self.matrix.append(b.copy())
        self.matrix.append(c.copy())
        self.matrix.append(d.copy())

    def __copy__(self):
        var m = Matrix2x2.__new__(Matrix2x2)
        m.matrix = self.matrix
        return m
    
    def __moveinit__(out self, owned other: Self):
        self.matrix = other.matrix^

    def get(self, r: Int, c: Int) -> Complex:
        return self.matrix[r * 2 + c].copy()

    def set(mut self, r: Int, c: Int, cp: Complex):
        self.matrix[r * 2 + c] = cp.copy()

    def mul(self, other: Matrix2x2) -> Matrix2x2:
        var res = Matrix2x2()
        for r in range(2):
            for c in range(2):
                var sum = Complex(0.0, 0.0)
                for k in range(2):
                    sum = sum.add(self.get(r, k).mul(other.get(k, c)))
                res.set(r, c, sum)
        return res^

    def dagger(self) -> Matrix2x2:
        return Matrix2x2(
            Complex(self.get(0,0).re, -self.get(0,0).im),
            Complex(self.get(1,0).re, -self.get(1,0).im),
            Complex(self.get(0,1).re, -self.get(0,1).im),
            Complex(self.get(1,1).re, -self.get(1,1).im)
        )

    def trace(self) -> Complex:
        return self.get(0,0).add(self.get(1,1))

    def det(self) -> Complex:
        return self.get(0,0).mul(self.get(1,1)).sub(self.get(0,1).mul(self.get(1.0)))

    def is_identity(self, tol: Float64 = 1e-10) -> Bool:
        if self.get(0,1).norm() > tol: return False
        if self.get(1,0).norm() > tol: return False
        if abs(self.get(0,0).norm() - 1.0) > tol: return False
        if abs(self.get(1,1).norm() - 1.0) > tol: return False
        var diff = self.get(0,0).sub(self.get(1,1))
        return diff.norm() < tol

    def print_matrix(self):
        print("Matrix 2x2:")
        for r in range(2):
            var s = "["
            for c in range(2):
                var v = self.get(r,c)
                s += "(" + String(v.re) + "+" + String(v.im) + "i"
                if c < 1: s += ", "
            s += "]"
            print(s)

struct Matrix4x4(Copyable, Movable):
    var matrix: List[Complex]

    def __init__(out self):
        self.matrix = List[Complex]()
        for i in range(16):
            if i % 5 == 0:
                self.matrix.append(Complex(1.0, 0.0))
            else:
                self.matrix.append(Complex(0.0, 0.0))
        
    def __init__(out self, matrix: List[Complex]):
        self.matrix = matrix.copy()

    def __copy__(self) -> Self:
        var m = Matrix4x4.__new__(Matrix4x4)
        m.matrix = self.matrix
        return m 
    
    def __moveinit__(out self, owned other: Self):
        self.matrix = other.matrix^

    def get(self, r: Int, c: Int) -> Complex:
        return self.matrix[r * 4 + c].copy()

    def set(mut self, r: Int, c: Int, cp: Complex):
        self.matrix[r * 4 + c] = cp.copy()
    
    def mul(self, other: Matrix4x4) -> Matrix4x4:
        var res = Matrix4x4()
        for r in range(4):
            for c in range(4):
                var sum = Complex(0.0, 0.0)
                for k in range(4):
                    sum = sum.add(self.get(r, k).mul(other.get(k, c)))
                res.set(r, c, sum)
        return res^

    def dagger(self) -> Matrix4x4:
        var res = Matrix4x4()
        for r in range(4):
            for c in range(4):
                var cp = self.get(r, c)
                res.set(c, r, Complex(cp.re, -cp.im))
        return res^

    def trace(self) -> Complex:
        var t = Complex(0.0, 0.0)
        for i in range(4):
            t = t.add(self.get(i, i))
        return t
    
    def is_identity(self, tol: Float64 = 1e-10) -> Bool:
        for r in range(4):
            for c in range(4):
                var cp = self.get(r, c)
                if r == c:
                    if abs(cp.norm() - 1.0) > tol: return False
                else:
                    if cp.norm() > tol: return False
        var refm = self.get(0, 0)
        for i in range(1, 4):
            var d = self.get(i, i).sub(refm)
            if d.norm() > tol: return False
        return True

    def is_unitary(self, tol = Float64 = 1e-10) -> Float64:
        var dagger = self.dagger()
        var product = dagger.mul(self)
        return product.is_identity(tol)
    
    def is_tensor_product(self, tol: Float64 = 1e-10) -> Bool:
        var ref_block = List[Complex]()
        var ref_i: Int = -1
        for i in range(2):
            for k in range(2):
                var block_norm: Float64 = 0.0
                for di in range(2):
                    for dk in range(2):
                        block_norm += self.get(2 * i + di, 2 * k + dk).norm()
                if block_norm > tol:
                    ref_i = i
                    for di in range(2):
                        for dk in range(2):
                            ref_block.append(self.get(2 * i + di, 2 * k + dk))
                    break
            if ref_i >= 0: break
        if ref_i < 0: return True
        for i in range(2):
            for k in range(2):
                var scalar = Complex(0.0, 0.0)
                var found_scalar = False
                for di in range(2):
                    for dk in range(2):
                        var ref_elem = ref_block[di * 2 + dk].copy()
                        if ref_elem.norm() > tol:
                            scalar = self.get(2 * i + di, 2 * k + dk).div(ref_elem)
                            found_scalar = True
                            break
                    if found_scalar:
                        break
                if not found_scalar:
                    scalar = Complex(0.0, 0.0)
                for di in range(2):
                    for dk in range(2):
                        var expected = scalar.mul(ref_block[di * 2 + dk])
                        var actual = self.get(2 * i + di, 2 * k + dk)
                        if expected.sub(actual).norm() > tol:
                            return False
        return True

    def extract_factors(self, tol: Float64 = 1e-10) -> Tuple[Matrix2x2, Matrix2x2]:
        var ua = Matrix2x2()
        var ub = Matrix2x2()
        for i in range(2):
            for j in range(2):
                var block_norm: Float64 = 0.0
                for di in range(2):
                    for dk in range(2):
                        block_norm += self.get(2 * i + di, 2 * k + dk).norm()
                if block_norm > tol:
                    ref_i = i
                    ref_k = k
                    for di in range(2):
                        for dk in range(2):
                            ref_block.append(self.get(2 * i + di, 2 * k + dk))
                    break
            if ref_i >= 0:
                break
        if ref_i < 0:
            return (ua, ub)
        ub.set(0, 0, ref_block[0])
        ub.set(0, 1, ref_block[1])
        ub.set(1, 0, ref_block[2])
        ub.set(1, 1, ref_block[3])
        var pivot_di: Int = -1
        var pivot_dk: Int = -1
        for di in range(2):
            for dk in range(2):
                if ref_block[di * 2 + dk].norm() > tol:
                    pivot_di = di
                    pivot_dk = dk
                    break
            if pivot_di >= 0:
                break
        var pivot_val = ref_block[pivot_di * 2 + pivot_dk]
        var lambdas = List[Complex]()
        for i in range(2):
            for k in range(2):
                var block_elem = self.get(2 * i + pivot_di, 2 * k + pivot_dk)
                lambdas.append(block_elem.div(pivot_val))
        ua.set(0, 0, lambdas[0])
        ua.set(0, 1, lambdas[1])
        ua.set(1, 0, lambdas[2])
        ua.set(1, 1, lambdas[3])
        return (ua, ub)

    def serialize(self) -> List[Float64]:
        var result = List[Float64]()
        for r in range(4):
            for c in range(4):
                var v = self.get(r, c)
                result.append(v.re)
                result.append(v.im)
        return result^

    @staticmethod
    def deserialize(params: List[Float64]) -> Matrix4x4:
        var m = Matrix4x4()
        for r in range(4):
            for c in range(4):
                var idx = (r * 4 + c) * 2
                m.set(r, c, Complex(params[idx], params[idx + 1]))
        return m^

    def norm_frobenius(self) -> Float64:
        var s: Float64 = 0.0
        for i in range(16):
            var v = self.matrix[i]
            s += v.re * v.re + v.im * v.im
        return sqrt(s)

    def fidelity(self, other: Matrix4x4) -> Float64:
        var dagger = self.dagger()
        var product = dagger.mul(other)
        var tr = product.trace()
        tr_norm_sq = tr.re * tr.re + tr.im * tr.im
        return (tr_norm_sq + d) / (d * (d + 1))

    def print_matrix(self):
        print("Matrix 4x4:")
        for r in range(4):
            var s = "["
            for c in range(4):
                var v = self.get(r, c)
                s += "(" + String(v.re) + "+" + String(v.im) + "i)"
                if c < 3: s += ", "
            s += "]"
            print(s)
                    
struct GateMatrix:
    @staticmethod
    def get_1q(name: String, params: List[Float64]) -> Matrix2x2:
        var inv = inv()
        if name == "I":
            return Matrix2x2(
                Complex(1.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, 0.0),
                Complex(1.0, 0.0)
            )
        elif name == "X":
            return Matrix2x2(
                Complex(0.0, 0.0),
                Complex(1.0, 0.0),
                Complex(1.0, 0.0),
                Complex(0.0, 0.0)
            )
        elif name == "Y":
            return Matrix2x2(
                Complex(0.0, 0.0),
                Complex(0.0, -1.0),
                Complex(0.0, 1.0),
                Complex(0.0, 0.0)
            )
        elif name == "Z":
            return Matrix2x2(
                Complex(1.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, 0.0),
                Complex(-1.0, 0.0)
            )
        elif name == "H":
            return Matrix2x2(
                Complex(inv, 0.0),
                Complex(inv, 0.0),
                Complex(inv, 0.0),
                Complex(-inv, 0.0)
            )
        elif name == "S":
            return Matrix2x2(
                Complex(1.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, 1.0)
            )
        elif name == "SDG":
            return Matrix2x2(
                Complex(1.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, -1.0)
            )
        elif name == "T":
            return Matrix2x2(
                Complex(1.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, 0.0),
                Complex(inv, inv)
            )
        elif name == "TDG":
            return Matrix2x2(
                Complex(1.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, 0.0),
                Complex(inv, -inv)
            )
        elif name == "RX" and len(params) > 0:
            var theta = params[0]
            var c = cos(theta / 2.0)
            var s = sin(theta / 2.0)
            return Matrix2x2(
                Complex(c, 0.0),
                Complex(0.0, -s),
                Complex(0.0, -s),
                Complex(c, 0.0)
            )
        elif name == "RY" and len(params) > 0:
            var theta = params[0]
            var c = cos(theta / 2.0)
            var s = sin(theta / 2.0)
            return Matrix2x2(
                Complex(c, 0.0),
                Complex(-s, 0.0),
                Complex(s, 0.0),
                Complex(c, 0.0)
            )
        elif name == "RZ" and len(params) > 0:
            var theta = params[0]
            var c = cos(theta / 2.0)
            var s = sin(theta / 2.0)
            return Matrix2x2(
                Complex(c, -s),
                Complex(0.0, 0.0),
                Complex(0.0, 0.0),
                Complex(c, s)
            )
        elif name == "P" and len(params) > 0:
            var theta = params[0]
            var c = cos(theta / 2.0)
            var s = sin(theta / 2.0)
            return Matrix2x2(
                Complex(1.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, 0.0),
                Complex(c, s)
            )
        elif name == "IP" and len(params) > 0:
            var theta = params[0]
            var c = cos(theta / 2.0)
            var s = sin(theta / 2.0)
            return Matrix2x2(
                Complex(1.0, 0.0),
                Complex(0.0, 0.0),
                Complex(0.0, 0.0),
                Complex(c, -s)
            )
        return Matrix2x2()

    @staticmethod
    def get_2q(name: String) -> Matrix4x4:
        var m = Matrix4x4()
        if name == "CX":
            m.set(0, 0, Complex(1.0, 0.0))
            m.set(1, 1, Complex(1.0, 0.0))
            m.set(2, 3, Complex(1.0, 0.0))
            m.set(3, 2, Complex(1.0, 0.0))
            m.set(2, 2, Complex(0.0, 0.0))
            m.set(3, 3, Complex(0.0, 0.0))
        elif name == "CZ":
            m.set(3, 3, Complex(-1.0,0.0))
        elif name == "SWAP":
            m.set(1, 1, Complex(0.0,0.0))
            m.set(2, 2, Complex(0.0,0.0))
            m.set(1, 2, Complex(1.0,0.0))
            m.set(2, 1, Complex(1.0,0.0))
        return m^

    @staticmethod
    def tensor(a: Matrix2x2, b: Matrix2x2) -> Matrix4x4:
        var res = Matrix4x4()
        for i in range(2):
            for j in range(2):
                var aij = a.get(i, j)
                for k in range(2):
                    for l in range(2):
                        res.set(i * 2 + k, j * 2 + l, aij.mul(b.get(k, l)))
        return res^
    
    @staticmethod
    def embed_1q_in_4x4(m: Matrix2x2, qubit: Int, q0: Int, q1: Int) -> Matrix4x4:
        var eye = Matrix2x2()
        if qubit == q0:
            return GateMatrix.tensor(m, eye)
        else:
            return GateMatrix.tensor(eye, m)