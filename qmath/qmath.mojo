from std.time import monotonic
from std.math import atan2, cos, sin
from gates import GateOp
from gateop_shortcut import _CX

comptime PI = 3.141592653589793
comptime PI4 = 0.7853981633974483

struct Complex(Copyable, Movable):
    var re: Float64
    var im: Float64

    def __init__(out self, re: Float64, im: Float64):
        self.re = re
        self.im = im
    
    def add(self, other: Complex) -> Complex:
        return Complex(self.re + other.re, self.im + other.im)

    def sub(self, other: Complex) -> Complex:
        return Complex(self.re - other.re, self.im - other.im)

    def dif(self, other: Complex) -> Complex:
        return Complex(self.re - other.re, self.im - other.im)

    def mul_fnumber(self, num: Float64) -> Complex:
        return Complex(num * self.re, num * self.im)

    def mul(self, other: Complex) -> Complex:
        return Complex(
            self.re * other.re - self.im * other.im,
            self.re * other.im + self.im * other.re
        )

    def div(self, other: Complex) -> Complex:
        var denom = other.re * other.re + other.im * other.im
        return Complex(
            (self.re * other.re + self.im * other.im) / denom,
            (self.im * other.re - self.re * other.im) / denom
        )

    def norm(self) -> Float64:
        return self.re * self.re + self.im * self.im

    def abs(self) -> Float64:
        return sqrt(self.re * self.re + self.im * self.im)

    def pow(self, exp: Float64) -> Complex:
        var r = self.abs() 
        var theta = atan2(self.im, self.re)
        var r_exp = r ** exp
        var theta_exp = theta * exp
        return Complex(r_exp * cos(theta_exp), r_exp * sin(theta_exp))

struct nummojo:

    @staticmethod
    def bit_length(x: Int) -> Int:
        var v = x
        var l = 0
        while v != 0:
            v = v >> 1
            l += 1
        return l

struct BitMatrix(Copyable, Movable):
    var n: Int
    var w: Int
    var d: List[Int]
    var wbits: Int
    var wshift: Int
    var wmask: Int

    def __init__(out self, n: Int, wbits: Int = 32, wshift: Int = 5, wmask: Int = 31):
        self.wbits = wbits
        self.wshift = wshift
        self.wmask = wmask
        self.n = n
        self.w = (n + wbits - 1) // wbits
        if self.w == 0:
            self.w = 1
        self.d = List[Int]()
        for _ in range(n * self.w):
            self.d.append(0)

    @always_inline
    def get(self, r: Int, c: Int) -> Int:
        return (self.d[r * self.w + (c >> self.wshift)] >> (c & self.wmask)) & 1

    def set_one(mut self, r: Int, c: Int):
        var k = r * self.w + (c >> self.wshift)
        self.d[k] = self.d[k] | (1 << (c & self.wmask))

    def xor_row(mut self, t: Int, c: Int):
        var bt = t * self.w
        var bc = c * self.w
        for k in range(self.w):
            self.d[bt + k] = self.d[bt + k] ^ self.d[bc + k]

    def sub_row(self, r: Int, lo: Int, width: Int) -> Int:
        var p = 0
        for b in range(width):
            p = p | (self.get(r, lo + b) << b)
        return p

    def transposed(self) -> BitMatrix:
        var t = BitMatrix(self.n, self.wbits, self.wshift, self.wmask)
        for r in range(self.n):
            for c in range(self.n):
                if self.get(r, c) == 1:
                    t.set_one(c, r)
        return t^

    def permuted(self, o: List[Int]) -> BitMatrix:
        var b = BitMatrix(self.n, self.wbits, self.wshift, self.wmask)
        for i in range(self.n):
            for j in range(self.n):
                if self.get(o[i], o[j]) == 1:
                    b.set_one(i, j)
        return b^

    def equals(self, o: BitMatrix) -> Bool:
        if self.n != o.n:
            return False
        for k in range(len(self.d)):
            if self.d[k] != o.d[k]:
                return False
        return True

    def flip(mut self, r: Int, c: Int):
        var k = r * self.w + (c >> self.wshift)
        self.d[k] = self.d[k] ^ (1 << (c & self.wmask))

def bm_identity(n: Int, wbits: Int = 32, wshift: Int = 5, wmask: Int = 31) -> BitMatrix:
    var a = BitMatrix(n, wbits, wshift, wmask)
    for i in range(n):
        a.set_one(i, i)
    return a^

def bm_from_rows(rows: List[Int], n: Int, wbits: Int = 32, wshift: Int = 5, wmask: Int = 31) raises -> BitMatrix:
    if len(rows) != n:
        raise Error("bm_from_rows: len(rows) != n")
    var a = BitMatrix(n, wbits, wshift, wmask)
    for r in range(n):
        for c in range(n):
            if ((rows[r] >> c) & 1) == 1:
                a.set_one(r, c)
    return a^

def bm_from_flat(flat: List[Float64], n: Int, wbits: Int = 32, wshift: Int = 5, wmask: Int = 31) raises -> BitMatrix:
    if len(flat) < n * n:
        raise Error("bm_from_flat: len(flat) < n * n")
    var a = BitMatrix(n, wbits, wshift, wmask)
    for r in range(n):
        for c in range(n):
            if Int(flat[r * n + c]) != 0:
                a.set_one(r, c)
    return a^

def bm_is_invertible(a: BitMatrix) -> Bool:
    var m = a.copy()
    var n = m.n
    for c in range(n):
        var p = -1
        for r in range(c, n):
            if m.get(r, c) == 1:
                p = r
                break
        if p < 0:
            return False
        if p != c:
            m.xor_row(c, p)
        for r in range(c + 1, n):
            if m.get(r, c) == 1:
                m.xor_row(r, c)
    return True

def bm_inverse(a: BitMatrix) raises -> BitMatrix:
    var n = a.n
    var m = a.copy()
    var inv = bm_identity(n)
    for c in range(n):
        var p = -1
        for r in range(c, n):
            if m.get(r, c) == 1:
                p = r
                break
        if p < 0:
            raise Error("bm_inverse: singular matrix")
        if p != c:
            m.xor_row(c, p)
            inv.xor_row(c, p)
        for r in range(n):
            if r != c and m.get(r, c) == 1:
                m.xor_row(r, c)
                inv.xor_row(r, c)
    return inv^

def ops_count(ops: List[Int]) -> Int:
    return len(ops) // 2

def ops_apply(ops: List[Int], n: Int, wbits: Int = 32, wshift: Int = 5, wmask: Int = 31) -> BitMatrix:
    var a = bm_identity(n, wbits, wshift, wmask)
    for i in range(len(ops) // 2):
        a.xor_row(ops[2 * i + 1], ops[2 * i])
    return a^

def ops_depth(ops: List[Int], n: Int) -> Int:
    var qd = List[Int]()
    for _ in range(n):
        qd.append(0)
    var d = 0
    for i in range(len(ops) // 2):
        var c = ops[2 * i]
        var t = ops[2 * i + 1]
        var m = qd[c] if qd[c] > qd[t] else qd[t]
        qd[c] = m + 1
        qd[t] = m + 1
        if m + 1 > d:
            d = m + 1
    return d

def ops_is_adjacent(ops: List[Int]) -> Bool:
    for i in range(len(ops) // 2):
        var d = ops[2 * i] - ops[2 * i + 1]
        if d != 1 and d != -1:
            return False
    return True

def ops_reverse(ops: List[Int]) -> List[Int]:
    var o = List[Int]()
    for i in range(len(ops) // 2 - 1, -1, -1):
        o.append(ops[2 * i])
        o.append(ops[2 * i + 1])
    return o^

def ops_swap(ops: List[Int]) -> List[Int]:
    var o = List[Int]()
    for i in range(len(ops) // 2):
        o.append(ops[2 * i + 1])
        o.append(ops[2 * i])
    return o^

def ops_reverse_swap(ops: List[Int]) -> List[Int]:
    var o = List[Int]()
    for i in range(len(ops) // 2 - 1, -1, -1):
        o.append(ops[2 * i + 1])
        o.append(ops[2 * i])
    return o^

def ops_relabel(ops: List[Int], order: List[Int]) -> List[Int]:
    var o = List[Int]()
    for i in range(len(ops)):
        o.append(order[ops[i]])
    return o^

def ops_two_phase(ops1: List[Int], ops2: List[Int]) -> List[Int]:
    var out = List[Int]()
    out.reserve(len(ops1) + len(ops2))
    for i in range(len(ops2) // 2):
        out.append(ops2[2 * i + 1])
        out.append(ops2[2 * i])
    for i in range(len(ops1) // 2 - 1, -1, -1):
        out.append(ops1[2 * i])
        out.append(ops1[2 * i + 1])
    return out^

def ops_to_gates(ops: List[Int]) -> List[GateOp]:
    var g = List[GateOp]()
    g.reserve(len(ops) // 2)
    for i in range(len(ops) // 2):
        g.append(_CX(ops[2 * i], ops[2 * i + 1]))
    return g^

def gates_to_ops(gates: List[GateOp]) raises -> List[Int]:
    var o = List[Int]()
    for i in range(len(gates)):
        if gates[i].name != "CX":
            raise Error("gates_to_ops: just CX, not " + gates[i].name)
        o.append(gates[i].qubit[0])
        o.append(gates[i].qubit[1])
    return o^

def abs(x: Int) -> Int:
    return x if x >= 0 else -x

def abs(x: Float64) -> Float64:
    return x if x >= 0.0 else -x

def round(x: Float64, decimals: Int = 0) -> Float64:
    var factor = 1.0
    for _ in range(decimals):
        factor *= 10.0
    var shifted = x * factor
    var floored = Float64(Int(shifted + 0.5 if shifted >= 0.0 else shifted - 0.5))
    return floored / factor

def random_int(a: Int, b: Int) -> Int:
    if b <= a:
        return a
    var seed = Int(monotonic())
    seed ^= seed << 13
    seed ^= seed >> 7
    seed ^= seed << 17
    return a + (seed % (b - a))

def random_float64(mut seed: Int, lo: Float64, hi: Float64) -> Float64:
    if hi <= lo:
        return lo
    seed ^= seed << 13
    seed ^= seed >> 7
    seed ^= seed << 17
    var uint = Float64(seed & 0x7FFFFFFFFFFFFFFF) / Float64(0x8000000000000000)
    return lo + uint * (hi - lo)

def log2_int(x: Int) -> Int:
    var n = 0
    var v = x
    while v > 1:
        v = v >> 1
        n += 1
    return n

def inv() -> Float64:
    return 0.7071067811865475

def abs2(c: Complex) -> Float64:
    return c.re * c.re + c.im * c.im

def sqrt(x: Float64) -> Float64:
    """
    Newton-Raphson
    """
    if x < 0.0:
        print("Negative number")
    if x == 0.0:
        return 0.0
    var guess = x
    for _ in range(20):
        guess = 0.5 * (guess + x / guess)
    return guess

def bit_length(x: Int) -> Int:
    var v = x
    var l = 0
    while v != 0:
        v = v >> 1
        l += 1
    return l