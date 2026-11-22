from std.time import monotonic
from std.math import atan2, cos, sin, sqrt
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

struct CMatrix(Copyable, Movable):
    var n: Int
    var re: List[Float64]
    var im: List[Float64]

    def __init__(out self, n: Int):
        self.n = n
        self.re = List[Float64]()
        self.im = List[Float64]()
        for _ in range(n * n):
            self.re.append(0.0)
            self.im.append(0.0)

    @staticmethod
    def identity(n: Int) -> CMatrix:
        var m = CMatrix(n)
        for i in range(n):
            m.re[i * n + i] = 1.0
        return m^

    @staticmethod
    def from_flat(flat: List[Float64], n: Int) raises -> CMatrix:
        if len(flat) < 2 * n * n:
            raise Error("from_flat: len(flat) < 2 * n * n")
        var m = CMatrix(n)
        for k in range(n * n):
            m.re[k] = flat[2 * k]
            m.im[k] = flat[2 * k + 1]
        return m^

    @staticmethod
    def from_parts(re: List[Float64], im: List[Float64], n: Int) raises -> CMatrix:
        if len(re) < n * n or len(im) < n * n:
            raise Error("from_parts: len(re) < n * n or len(im) < n * n")
        var m = CMatrix(n)
        for k in range(n * n):
            m.re[k] = re[k]
            m.im[k] = im[k]
        return m^

    def to_flat(self) -> List[Float64]:
        var f = List[Float64]()
        for k in range(self.n * self.n):
            f.append(self.re[k])
            f.append(self.im[k])
        return f^

    @always_inline
    def get_re(self, i: Int, j: Int) -> Float64:
        return self.re[i * self.n + j]

    @always_inline
    def get_im(self, i: Int, j: Int) -> Float64:
        return self.im[i * self.n + j]

    @always_inline
    def set(mut self, i: Int, j: Int, re: Float64, im: Float64):
        self.re[i * self.n + j] = re
        self.im[i * self.n + j] = im

    def adjoint(self) -> CMatrix:
        var n = self.n
        var a = CMatrix(n)
        for i in range(n):
            for j in range(n):
                a.re[j * n + i] = self.re[i * n + j]
                a.im[j * n + i] = -self.im[i * n + j]
        return a^

    def transpose(self) -> CMatrix:
        var n = self.n
        var t = CMatrix(n)
        for i in range(n):
            for j in range(n):
                t.re[j * n + i] = self.re[i * n + j]
                t.im[j * n + i] = self.im[i * n + j]
        return t^

    def conj(self) -> CMatrix:
        var c = self.copy()
        for k in range(len(c.im)):
            c.im[k] = -c.im[k]
        return c^

    def matmul(self, b: CMatrix) -> CMatrix:
        var n = self.n
        var c = CMatrix(n)
        for i in range(n):
            for k in range(n):
                var ar = self.re[i * n + k]
                var ai = self.im[i * n + k]
                if ar == 0.0 and ai == 0.0:
                    continue
                for j in range(n):
                    var br = b.re[k * n + j]
                    var bi = b.im[k * n + j]
                    c.re[i * n + j] += ar * br - ai * bi
                    c.im[i * n + j] += ar * bi + ai * br
        return c^

    def scaled(self, cr: Float64, ci: Float64) -> CMatrix:
        var m = CMatrix(self.n)
        for k in range(len(self.re)):
            m.re[k] = cr * self.re[k] - ci * self.im[k]
            m.im[k] = cr * self.im[k] + ci * self.re[k]
        return m^

    def add(self, b: CMatrix) -> CMatrix:
        var m = CMatrix(self.n)
        for k in range(len(self.re)):
            m.re[k] = self.re[k] + b.re[k]
            m.im[k] = self.im[k] + b.im[k]
        return m^

    def sub(self, b: CMatrix) -> CMatrix:
        var m = CMatrix(self.n)
        for k in range(len(self.re)):
            m.re[k] = self.re[k] - b.re[k]
            m.im[k] = self.im[k] - b.im[k]
        return m^

    def block(self, r0: Int, c0: Int, m: Int) -> CMatrix:
        var b = CMatrix(m)
        for i in range(m):
            for j in range(m):
                b.re[i * m + j] = self.re[(r0 + i) * self.n + c0 + j]
                b.im[i * m + j] = self.im[(r0 + i) * self.n + c0 + j]
        return b^

    def max_abs(self) -> Float64:
        var e = 0.0
        for k in range(len(self.re)):
            var x = sqrt(self.re[k] * self.re[k] + self.im[k] * self.im[k])
            if x > e:
                e = x
        return e

    def frobenius(self) -> Float64:
        var s = 0.0
        for k in range(len(self.re)):
            s += self.re[k] * self.re[k] + self.im[k] * self.im[k]
        return sqrt(s)

    def dist_identity(self) -> Float64:
        var n = self.n
        var e = 0.0
        for i in range(n):
            for j in range(n):
                var r = self.re[i * n + j] - (1.0 if i == j else 0.0)
                var x = sqrt(r * r + self.im[i * n + j] * self.im[i * n + j])
                if x > e:
                    e = x
        return e

    def is_unitary(self, tol: Float64 = 1e-8) -> Bool:
        return self.matmul(self.adjoint()).dist_identity() <= tol

def phase_error(a: CMatrix, b: CMatrix) -> Float64:
    var sr = 0.0
    var si = 0.0
    for k in range(len(a.re)):
        sr += a.re[k] * b.re[k] + a.im[k] * b.im[k]
        si += a.re[k] * b.im[k] - a.im[k] * b.re[k]
    var r = sqrt(sr * sr + si * si)
    var pr = 1.0
    var pi = 0.0
    if r > 0.0:
        pr = sr / r
        pi = si / r
    var e = 0.0
    for k in range(len(a.re)):
        var dr = b.re[k] - (pr * a.re[k] - pi * a.im[k])
        var di = b.im[k] - (pr * a.im[k] + pi * a.re[k])
        var x = sqrt(dr * dr + di * di)
        if x > e:
            e = x
    return e

def cdet(m: CMatrix) -> Tuple[Float64, Float64]:
    var a = m.copy()
    var n = a.n
    var dr = 1.0
    var di = 0.0
    for c in range(n):
        var p = c
        var best = -1.0
        for r in range(c, n):
            var v = a.re[r * n + c] * a.re[r * n + c] + a.im[r * n + c] * a.im[r * n + c]
            if v > best:
                best = v
                p = r
        if best < 1e-300:
            return (0.0, 0.0)
        if p != c:
            for k in range(n):
                var tr = a.re[c * n + k]
                var ti = a.im[c * n + k]
                a.re[c * n + k] = a.re[p * n + k]
                a.im[c * n + k] = a.im[p * n + k]
                a.re[p * n + k] = tr
                a.im[p * n + k] = ti
            dr = -dr
            di = -di
        var pr = a.re[c * n + c]
        var pi = a.im[c * n + c]
        var ndr = dr * pr - di * pi
        var ndi = dr * pi + di * pr
        dr = ndr
        di = ndi
        var den = pr * pr + pi * pi
        var ir = pr / den
        var ii = -pi / den
        for r in range(c + 1, n):
            var xr = a.re[r * n + c]
            var xi = a.im[r * n + c]
            var fr = xr * ir - xi * ii
            var fi = xr * ii + xi * ir
            for k in range(c, n):
                var br = a.re[c * n + k]
                var bi = a.im[c * n + k]
                a.re[r * n + k] -= fr * br - fi * bi
                a.im[r * n + k] -= fr * bi + fi * br
    return (dr, di)

def kron2(a: CMatrix, b: CMatrix) -> CMatrix:
    var g = CMatrix(4)
    for i in range(2):
        for j in range(2):
            var ar = a.re[i * 2 + j]
            var ai = a.im[i * 2 + j]
            for k in range(2):
                for l in range(2):
                    var br = b.re[k * 2 + l]
                    var bi = b.im[k * 2 + l]
                    var idx = (2 * i + k) * 4 + (2 * j + l)
                    g.re[idx] = ar * br - ai * bi
                    g.im[idx] = ar * bi + ai * br
    return g^

def kron(a: CMatrix, b: CMatrix) -> CMatrix:
    var na = a.n
    var nb = b.n
    var n = na * nb
    var g = CMatrix(n)
    for i in range(na):
        for j in range(na):
            var ar = a.re[i * na + j]
            var ai = a.im[i * na + j]
            if ar == 0.0 and ai == 0.0:
                continue
            for k in range(nb):
                for l in range(nb):
                    var br = b.re[k * nb + l]
                    var bi = b.im[k * nb + l]
                    var idx = (i * nb + k) * n + (j * nb + l)
                    g.re[idx] = ar * br - ai * bi
                    g.im[idx] = ar * bi + ai * br
    return g^

def _rot_cols(mut m: CMatrix, p: Int, q: Int, g: List[Float64]):
    var n = m.n
    for k in range(n):
        var xr = m.re[k * n + p]
        var xi = m.im[k * n + p]
        var yr = m.re[k * n + q]
        var yi = m.im[k * n + q]
        m.re[k * n + p] = xr * g[0] - xi * g[1] + yr * g[4] - yi * g[5]
        m.im[k * n + p] = xr * g[1] + xi * g[0] + yr * g[5] + yi * g[4]
        m.re[k * n + q] = xr * g[2] - xi * g[3] + yr * g[6] - yi * g[7]
        m.im[k * n + q] = xr * g[3] + xi * g[2] + yr * g[7] + yi * g[6]

def _rot_rows_adj(mut m: CMatrix, p: Int, q: Int, g: List[Float64]):
    var n = m.n
    for k in range(n):
        var xr = m.re[p * n + k]
        var xi = m.im[p * n + k]
        var yr = m.re[q * n + k]
        var yi = m.im[q * n + k]
        m.re[p * n + k] = g[0] * xr + g[1] * xi + g[4] * yr + g[5] * yi
        m.im[p * n + k] = g[0] * xi - g[1] * xr + g[4] * yi - g[5] * yr
        m.re[q * n + k] = g[2] * xr + g[3] * xi + g[6] * yr + g[7] * yi
        m.im[q * n + k] = g[2] * xi - g[3] * xr + g[6] * yi - g[7] * yr

def herm_eig(h: CMatrix, mut vecs: CMatrix) -> List[Float64]:
    var n = h.n
    var a = h.copy()
    vecs = CMatrix.identity(n)
    var total = 0.0
    for k in range(n * n):
        total += a.re[k] * a.re[k] + a.im[k] * a.im[k]
    var g = List[Float64]()
    for _ in range(8):
        g.append(0.0)
    for _ in range(100):
        var off = 0.0
        for p in range(n):
            for q in range(p + 1, n):
                off += a.re[p * n + q] * a.re[p * n + q] + a.im[p * n + q] * a.im[p * n + q]
        if off <= 1e-30 * (total + 1e-300):
            break
        for p in range(n - 1):
            for q in range(p + 1, n):
                var xr = a.re[p * n + q]
                var xi = a.im[p * n + q]
                var r = sqrt(xr * xr + xi * xi)
                if r < 1e-300:
                    continue
                var er = xr / r
                var ei = xi / r
                var th = 0.5 * atan2(2.0 * r, a.re[q * n + q] - a.re[p * n + p])
                var c = cos(th)
                var s = sin(th)
                g[0] = c
                g[1] = 0.0
                g[2] = s
                g[3] = 0.0
                g[4] = -s * er
                g[5] = s * ei
                g[6] = c * er
                g[7] = -c * ei
                _rot_cols(a, p, q, g)
                _rot_rows_adj(a, p, q, g)
                _rot_cols(vecs, p, q, g)
                a.re[p * n + q] = 0.0
                a.im[p * n + q] = 0.0
                a.re[q * n + p] = 0.0
                a.im[q * n + p] = 0.0
                a.im[p * n + p] = 0.0
                a.im[q * n + q] = 0.0
    var vals = List[Float64]()
    for i in range(n):
        vals.append(a.re[i * n + i])
    return vals^

def unitary_eig(x: CMatrix, mut v: CMatrix, mut ang: List[Float64]) raises:
    var m = x.n
    var xa = x.adjoint()
    for t in [0.7123456789, 1.3141592653, 0.2718281828, 2.2360679775, 0.5772156649]:
        var h = CMatrix(m)
        for k in range(m * m):
            var h1r = 0.5 * (x.re[k] + xa.re[k])
            var h1i = 0.5 * (x.im[k] + xa.im[k])
            var h2r = 0.5 * (x.im[k] - xa.im[k])
            var h2i = -0.5 * (x.re[k] - xa.re[k])
            h.re[k] = h1r + t * h2r
            h.im[k] = h1i + t * h2i
        _ = herm_eig(h, v)
        var d = v.adjoint().matmul(x).matmul(v)
        var off = 0.0
        for i in range(m):
            for j in range(m):
                if i != j:
                    var e = sqrt(d.re[i * m + j] * d.re[i * m + j] + d.im[i * m + j] * d.im[i * m + j])
                    if e > off:
                        off = e
        if off < 1e-9:
            ang.clear()
            for j in range(m):
                ang.append(atan2(d.im[j * m + j], d.re[j * m + j]))
            return
        raise Error("unitary_eig: failed")

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

# def sqrt(x: Float64) -> Float64:
#     """
#     Newton-Raphson
#     """
#     if x < 0.0:
#         print("Negative number")
#     if x == 0.0:
#         return 0.0
#     var guess = x
#     for _ in range(20):
#         guess = 0.5 * (guess + x / guess)
#     return guess

def bit_length(x: Int) -> Int:
    var v = x
    var l = 0
    while v != 0:
        v = v >> 1
        l += 1
    return l