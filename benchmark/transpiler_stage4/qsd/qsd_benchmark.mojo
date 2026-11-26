from gates import GateOp
from qmath import CMatrix, phase_error
from transpiler import QSDDecomposer
from std.time import monotonic
from std.math import cos, sin

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
            raise Error("unitary_of: no support " + name)
    return u^

comptime PI2 = 6.283185307179586
comptime MAX_DUMP_N = 4

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

def depth_of(g: List[GateOp], n: Int) -> Int:
    var qd = List[Int]()
    for _ in range(n):
        qd.append(0)
    var d = 0
    for i in range(len(g)):
        var m = 0
        for k in range(len(g[i].qubit)):
            if qd[g[i].qubit[k]] > m:
                m = qd[g[i].qubit[k]]
        for k in range(len(g[i].qubit)):
            qd[g[i].qubit[k]] = m + 1
        if m + 1 > d:
            d = m + 1
    return d

def median(mut ts: List[Int]) -> Int:
    for i in range(1, len(ts)):
        var key = ts[i]
        var j = i - 1
        while j >= 0 and ts[j] > key:
            ts[j + 1] = ts[j]
            j -= 1
        ts[j + 1] = key
    return ts[len(ts) // 2]

def samples_for(n: Int) -> Int:
    if n <= 4:
        return 5
    if n == 5:
        return 3
    return 2

def reps_for(n: Int) -> Int:
    if n <= 3:
        return 10
    if n == 4:
        return 3
    return 1

def run_case(label: String, n: Int, u: CMatrix, use_kak: Bool) raises:
    var qubits = List[Int]()
    for i in range(n):
        qubits.append(i)
    try:
        var dec = QSDDecomposer(use_kak)
        var g = dec.gates(u, qubits)
        var ts = List[Int]()
        for _ in range(reps_for(n)):
            var t0 = monotonic()
            var w = dec.gates(u, qubits)
            ts.append(Int(monotonic() - t0))
            _ = len(w)
        var err = phase_error(u, unitary_of(g, n))
        var cx = 0
        for i in range(len(g)):
            if g[i].name == "CX":
                cx += 1
        print("RESULT", label, "n=" + String(n), "cx=" + String(cx),
              "gates=" + String(len(g)), "depth=" + String(depth_of(g, n)),
              "err=" + String(err), "ns=" + String(median(ts)))
        if n <= MAX_DUMP_N:
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
    print("# Mojo QSD benchmark")
    for n in [1, 2, 3, 4, 5, 6]:
        for s in range(samples_for(n)):
            var u = random_unitary(n, 7000 + 100 * n + s)
            var tag = "qsd_" + String(n) + "_" + String(s)
            run_case(tag + "_kak", n, u, True)
            run_case(tag + "_plain", n, u, False)
    print("# DONE")