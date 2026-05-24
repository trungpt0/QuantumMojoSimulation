from qmath import inv, Complex
from std.math import sin, cos

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
                    sum = sum.add(self.get(r, k)).mul(other.get(k, c))
                res.set(r, c, sum)
        return res^

struct GateMaxtrix:
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