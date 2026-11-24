from gates import GateOp
from qmath import CMatrix, phase_error, kron2
from transpiler import KAKDecomposer, Gate1Q
from std.time import monotonic
from std.math import cos, sin

comptime PI = 3.141592653589793
comptime PI2 = 6.283185307179586
comptime N_RAND = 200
comptime REPS = 20

def unitary_of(gates: List[GateOp], n: Int) raises -> CMatrix:
    var d = 1 << n
    var u = CMatrix.identity(d)
    for gi in range(len(gates)):
        var name = gates[gi].name
        if name == "CX":
            var bc = 1 << (n - 1 - gates[gi].qubit[0])
            var bt = 1 << (n - 1 - gates[gi].qubit[1])
            for r in range(d):
                if (r & bc) != 0 and (r & bt) == 0:
                    var r2 = r | bt
                    for k in range(d):
                        var tr = u.re[r * d + k]
                        var ti = u.im[r * d + k]
                        u.re[r * d + k] = u.re[r2 * d + k]
                        u.im[r * d + k] = u.im[r2 * d + k]
                        u.re[r2 * d + k] = tr
                        u.im[r2 * d + k] = ti
        elif name == "RZ":
            var b = 1 << (n - 1 - gates[gi].qubit[0])
            var h = 0.5 * gates[gi].theta[0]
            for r in range(d):
                var s = sin(h) if (r & b) != 0 else -sin(h)
                var c = cos(h)
                for k in range(d):
                    var xr = u.re[r * d + k]
                    var xi = u.im[r * d + k]
                    u.re[r * d + k] = c * xr - s * xi
                    u.im[r * d + k] = c * xi + s * xr
        elif name == "RY":
            var b = 1 << (n - 1 - gates[gi].qubit[0])
            var c = cos(0.5 * gates[gi].theta[0])
            var s = sin(0.5 * gates[gi].theta[0])
            for r in range(d):
                if (r & b) != 0:
                    continue
                var r2 = r | b
                for k in range(d):
                    var xr = u.re[r * d + k]
                    var xi = u.im[r * d + k]
                    var yr = u.re[r2 * d + k]
                    var yi = u.im[r2 * d + k]
                    u.re[r * d + k] = c * xr - s * yr
                    u.im[r * d + k] = c * xi - s * yi
                    u.re[r2 * d + k] = s * xr + c * yr
                    u.im[r2 * d + k] = s * xi + c * yi
        else:
            raise Error("unitary_of: not support " + name)
    return u^

struct LCG(Copyable, Movable):
    var s: Int

    def __init__(out self, seed: Int):
        self.s = seed & 0x7FFFFFFF

    def next(mut self) -> Int:
        self.s = (self.s * 1664525 + 1013904223) & 0x7FFFFFFF
        return self.s

    def below(mut self, n: Int) -> Int:
        return (self.next() >> 8) % n

    def unit(mut self) -> Float64:
        return Float64(self.next() >> 7) / 16777216.0

def random_unitary(n: Int, seed: Int) -> CMatrix:
    var d = 1 << n
    var u = CMatrix.identity(d)
    var rng = LCG(seed)
    for _ in range(4 * d * d):
        var i = rng.below(d)
        var j = rng.below(d - 1)
        if j >= i:
            j += 1
        var th = rng.unit() * PI2
        var ph = rng.unit() * PI2
        var c = cos(th)
        var s = sin(th)
        var er = cos(ph)
        var ei = sin(ph)
        for k in range(d):
            var xr = u.re[i * d + k]
            var xi = u.im[i * d + k]
            var yr = u.re[j * d + k]
            var yi = u.im[j * d + k]
            u.re[i * d + k] = c * xr - s * (er * yr - ei * yi)
            u.im[i * d + k] = c * xi - s * (er * yi + ei * yr)
            u.re[j * d + k] = s * (er * xr + ei * xi) + c * yr
            u.im[j * d + k] = s * (er * xi - ei * xr) + c * yi
    for k in range(d):
        var ph = rng.unit() * PI2
        var c = cos(ph)
        var s = sin(ph)
        for m in range(d):
            var r = u.re[k * d + m]
            var i2 = u.im[k * d + m]
            u.re[k * d + m] = c * r - s * i2
            u.im[k * d + m] = c * i2 + s * r
    return u^

def can_matrix(a: Float64, b: Float64, c: Float64) -> CMatrix:
    var m = CMatrix(4)
    var lp = a - b + c
    var lm = -a + b + c
    var sp = a + b - c
    var sm = -a - b - c
    var dr = 0.5 * (cos(lp) + cos(lm))
    var di = 0.5 * (sin(lp) + sin(lm))
    var orr = 0.5 * (cos(lp) - cos(lm))
    var oi = 0.5 * (sin(lp) - sin(lm))
    m.set(0, 0, dr, di)
    m.set(3, 3, dr, di)
    m.set(0, 3, orr, oi)
    m.set(3, 0, orr, oi)
    dr = 0.5 * (cos(sp) + cos(sm))
    di = 0.5 * (sin(sp) + sin(sm))
    orr = 0.5 * (cos(sp) - cos(sm))
    oi = 0.5 * (sin(sp) - sin(sm))
    m.set(1, 1, dr, di)
    m.set(2, 2, dr, di)
    m.set(1, 2, orr, oi)
    m.set(2, 1, orr, oi)
    return m^

def perm4(p0: Int, p1: Int, p2: Int, p3: Int) -> CMatrix:
    var m = CMatrix(4)
    m.set(p0, 0, 1.0, 0.0)
    m.set(p1, 1, 1.0, 0.0)
    m.set(p2, 2, 1.0, 0.0)
    m.set(p3, 3, 1.0, 0.0)
    return m^

def special(name: String) raises -> CMatrix:
    if name == "id":
        return CMatrix.identity(4)
    if name == "local":
        return kron2(Gate1Q.ry(0.3).matmul(Gate1Q.rz(1.1)), Gate1Q.rx(0.7))
    if name == "cx":
        return perm4(0, 1, 3, 2)
    if name == "cz":
        var m = CMatrix.identity(4)
        m.set(3, 3, -1.0, 0.0)
        return m^
    if name == "swap":
        return perm4(0, 2, 1, 3)
    if name == "iswap":
        var m = CMatrix(4)
        m.set(0, 0, 1.0, 0.0)
        m.set(1, 2, 0.0, 1.0)
        m.set(2, 1, 0.0, 1.0)
        m.set(3, 3, 1.0, 0.0)
        return m^
    if name == "cnotlike":
        return can_matrix(0.25 * PI, 0.0, 0.0)
    if name == "two":
        return can_matrix(0.3, 0.0, 0.2)
    if name == "bgate":
        return can_matrix(0.25 * PI, 0.125 * PI, 0.0)
    if name == "sqrtswap":
        return can_matrix(0.125 * PI, 0.125 * PI, 0.125 * PI)
    if name == "generic":
        return can_matrix(0.4, 0.3, 0.1)
    if name == "near":
        return can_matrix(0.4, 0.3, 1e-9)
    raise Error("special: khong biet " + name)

def dressed(m: CMatrix, seed: Int) -> CMatrix:
    var l = kron2(random_unitary(1, seed), random_unitary(1, seed + 1))
    var r = kron2(random_unitary(1, seed + 2), random_unitary(1, seed + 3))
    return l.matmul(m).matmul(r)

def run_case(mut kak: KAKDecomposer, label: String, u: CMatrix) raises:
    try:
        var g = kak.decompose(u, 0, 1, "ZYZ")
        var err = phase_error(u, unitary_of(g, 2))
        var t0 = monotonic()
        for _ in range(REPS):
            var w = kak.decompose(u, 0, 1, "ZYZ")
            _ = len(w)
        var ns = Int(monotonic() - t0) // REPS
        var cx = 0
        for i in range(len(g)):
            if g[i].name == "CX":
                cx += 1
        print("RESULT", label, "cx=" + String(cx), "gates=" + String(len(g)),
              "err=" + String(err), "ns=" + String(ns))
        for i in range(len(g)):
            var line = "GATE " + label + " " + g[i].name
            for k in range(len(g[i].qubit)):
                line += " " + String(g[i].qubit[k])
            for k in range(len(g[i].theta)):
                line += " p=" + String(g[i].theta[k])
            print(line)
    except e:
        print("# ERROR", label, ":", e)

def main() raises:
    print("# Mojo KAK benchmark")
    var kak = KAKDecomposer()
    var names = ["id", "local", "cx", "cz", "swap", "iswap", "cnotlike",
                 "two", "bgate", "sqrtswap", "generic", "near"]
    for ci in range(len(names)):
        var u = special(names[ci])
        run_case(kak, names[ci], u)
        run_case(kak, names[ci] + "-d", dressed(u, 500 + 10 * ci))
    for k in range(N_RAND):
        run_case(kak, "rand" + String(k), random_unitary(2, 11000 + k))
    print("# DONE")