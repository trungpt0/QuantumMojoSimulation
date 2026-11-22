from gates import GateOp
from qmath import CMatrix, phase_error
from transpiler import OneQubitDecomposer, Gate1Q
from std.time import monotonic
from std.math import cos, sin

comptime PI = 3.141592653589793
comptime PI2 = 6.283185307179586
comptime N_RAND = 200
comptime REPS = 200

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

def random_u2(seed: Int) -> CMatrix:
    var d = 2
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

def diag2(r0: Float64, i0: Float64, r1: Float64, i1: Float64) -> CMatrix:
    var m = CMatrix(2)
    m.set(0, 0, r0, i0)
    m.set(1, 1, r1, i1)
    return m^

def special(name: String) raises -> CMatrix:
    if name == "id":
        return CMatrix.identity(2)
    if name == "phase":
        return CMatrix.identity(2).scaled(cos(0.3), sin(0.3))
    if name == "x":
        var m = CMatrix(2)
        m.set(0, 1, 1.0, 0.0)
        m.set(1, 0, 1.0, 0.0)
        return m^
    if name == "y":
        var m = CMatrix(2)
        m.set(0, 1, 0.0, -1.0)
        m.set(1, 0, 0.0, 1.0)
        return m^
    if name == "z":
        return diag2(1.0, 0.0, -1.0, 0.0)
    if name == "h":
        return Gate1Q.h()
    if name == "s":
        return diag2(1.0, 0.0, 0.0, 1.0)
    if name == "t":
        return diag2(1.0, 0.0, cos(0.25 * PI), sin(0.25 * PI))
    if name == "sx":
        return Gate1Q.sx()
    if name == "rztiny":
        return Gate1Q.rz(1e-14)
    if name == "rytiny":
        return Gate1Q.ry(1e-9)
    if name == "rypieps":
        return Gate1Q.ry(PI - 1e-12)
    if name == "rypi":
        return Gate1Q.ry(PI)
    if name == "rxhalf":
        return Gate1Q.rx(0.5 * PI)
    if name == "u3":
        return Gate1Q.u(1.1, -2.3, 0.7)
    raise Error("special: unknown " + name)

def count(g: List[GateOp], name: String) -> Int:
    var c = 0
    for i in range(len(g)):
        if g[i].name == name:
            c += 1
    return c

def run_case(case_: String, u: CMatrix, basis: String) raises:
    var label = case_ + "_" + basis
    try:
        var dec = OneQubitDecomposer(basis)
        var g = dec.gates(u, 0)
        var err = phase_error(u, OneQubitDecomposer.matrix(g, 0))
        var t0 = monotonic()
        for _ in range(REPS):
            var w = dec.gates(u, 0)
            _ = len(w)
        var ns = Int(monotonic() - t0) // REPS
        print("RESULT", label,
              "gates=" + String(len(g)),
              "rz=" + String(count(g, "RZ")),
              "ry=" + String(count(g, "RY")),
              "rx=" + String(count(g, "RX")),
              "sx=" + String(count(g, "SX")),
              "u=" + String(count(g, "U")),
              "err=" + String(err),
              "ns=" + String(ns))
        for i in range(len(g)):
            var line = "GATE " + label + " " + g[i].name + " " + String(g[i].qubit[0])
            for k in range(len(g[i].theta)):
                line += " p=" + String(g[i].theta[k])
            print(line)
    except e:
        print("# ERROR", label, ":", e)

def main() raises:
    print("# Mojo OneQubitDecomposer benchmark")
    var bases = ["ZYZ", "ZXZ", "ZSX", "U"]
    var specials = ["id", "phase", "x", "y", "z", "h", "s", "t", "sx", "rztiny", "rytiny", "rypieps", "rypi", "rxhalf", "u3"]
    for ci in range(len(specials)):
        var u = special(specials[ci])
        for bi in range(len(bases)):
            run_case(specials[ci], u, bases[bi])
    for k in range(N_RAND):
        var u = random_u2(9000 + k)
        for bi in range(len(bases)):
            run_case("rand" + String(k), u, bases[bi])
    print("# DONE")