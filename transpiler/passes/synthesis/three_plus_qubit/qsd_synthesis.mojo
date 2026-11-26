from std.math import sqrt, cos, sin, atan2
from gates import GateOp
from gateop_shortcut import _RZ, _RY, _CX
from qmath import CMatrix, phase_error, herm_eig, unitary_eig
from transpiler import BasicTranslator, KAKDecomposer, EulerDecomposer

comptime ANG_EPS = 1e-12
comptime COL_EPS = 1e-7
comptime CANCEL_WINDOW = 512

def _col_norm2(m: CMatrix, j: Int) -> Float64:
    var n = m.n
    var s = 0.0
    for k in range(n):
        s += m.re[k * n + j] * m.re[k * n + j] + m.im[k * n + j] * m.im[k * n + j]
    return s

def _orth_against(mut m: CMatrix, j: Int, i: Int):
    var n = m.n
    var pr = 0.0
    var pi = 0.0
    for k in range(n):
        var ar = m.re[k * n + i]
        var ai = m.im[k * n + i]
        var br = m.re[k * n + j]
        var bi = m.im[k * n + j]
        pr += ar * br + ai * bi
        pi += ar * bi - ai * br
    for k in range(n):
        var ar = m.re[k * n + i]
        var ai = m.im[k * n + i]
        m.re[k * n + j] -= pr * ar - pi * ai
        m.im[k * n + j] -= pr * ai + pi * ar

def _scale_col(mut m: CMatrix, j: Int, f: Float64):
    var n = m.n
    for k in range(n):
        m.re[k * n + j] *= f
        m.im[k * n + j] *= f

def _complete_cols(mut m: CMatrix, valid: List[Bool], weight: List[Float64]) raises:
    var n = m.n
    var done = List[Int]()
    var taken = List[Bool]()
    for _ in range(n):
        taken.append(False)
    var missing = List[Int]()
    while True:
        var best = -1
        var bw = -1.0
        for j in range(n):
            if valid[j] and not taken[j] and weight[j] > bw:
                bw = weight[j]
                best = j
        if best < 0:
            break
        taken[best] = True
        for t in range(len(done)):
            _orth_against(m, best, done[t])
        var nr = sqrt(_col_norm2(m, best))
        if nr < 0.5:
            missing.append(best)
            continue
        _scale_col(m, best, 1.0 / nr)
        done.append(best)
    for j in range(n):
        if not valid[j]:
            missing.append(j)
    for idx in range(len(missing)):
        var j = missing[idx]
        var bestk = 0
        var bestn = -1.0
        for k in range(n):
            var s = 0.0
            for t in range(len(done)):
                var c = done[t]
                s += m.re[k * n + c] * m.re[k * n + c] + m.im[k * n + c] * m.im[k * n + c]
            if 1.0 - s > bestn:
                bestn = 1.0 - s
                bestk = k
        for k in range(n):
            m.re[k * n + j] = 1.0 if k == bestk else 0.0
            m.im[k * n + j] = 0.0
        for _ in range(2):
            for t in range(len(done)):
                _orth_against(m, j, done[t])
        var nr = sqrt(_col_norm2(m, j))
        if nr < 1e-6:
            raise Error("QSDDecomposer: cannot complete cols")
        _scale_col(m, j, 1.0 / nr)
        done.append(j)

def _csd(u: CMatrix, mut l0: CMatrix, mut l1: CMatrix, mut r0: CMatrix, mut r1: CMatrix, mut cs: List[Float64], mut sn: List[Float64]) raises:
    var m = u.n // 2
    var u00 = u.block(0, 0, m)
    var u01 = u.block(0, m, m)
    var u10 = u.block(m, 0, m)
    var u11 = u.block(m, m, m)
    var q = CMatrix(m)
    var lam = herm_eig(u00.adjoint().matmul(u00), q)
    r0 = q.adjoint()
    var a = u00.matmul(q)
    var b = u10.matmul(q)
    cs.clear()
    sn.clear()
    var va = List[Bool]()
    var vb = List[Bool]()
    for i in range(m):
        var x = lam[i]
        if x < 0.0:
            x = 0.0
        if x > 1.0:
            x = 1.0
        var c = sqrt(x)
        var s = sqrt(1.0 - x)
        cs.append(c)
        sn.append(s)
        va.append(c > COL_EPS)
        vb.append(s > COL_EPS)
    l0 = CMatrix(m)
    l1 = CMatrix(m)
    for i in range(m):
        for k in range(m):
            if va[i]:
                l0.re[k * m + i] = a.re[k * m + i] / cs[i]
                l0.im[k * m + i] = a.im[k * m + i] / cs[i]
            if vb[i]:
                l1.re[k * m + i] = b.re[k * m + i] / sn[i]
                l1.im[k * m + i] = b.im[k * m + i] / sn[i]
    _complete_cols(l0, va, cs)
    _complete_cols(l1, vb, sn)
    var t1 = l1.adjoint().matmul(u11)
    var t0 = l0.adjoint().matmul(u01)
    r1 = CMatrix(m)
    for i in range(m):
        for j in range(m):
            if cs[i] >= sn[i]:
                r1.re[i * m + j] = t1.re[i * m + j] / cs[i]
                r1.im[i * m + j] = t1.im[i * m + j] / cs[i]
            else:
                r1.re[i * m + j] = -t0.re[i * m + j] / sn[i]
                r1.im[i * m + j] = -t0.im[i * m + j] / sn[i]
    
def _tail(xs: List[Int]) -> List[Int]:
    var r = List[Int]()
    for i in range(1, len(xs)):
        r.append(xs[i])
    return r^

def _rot(kind: String, q: Int, a: Float64) -> GateOp:
    if kind == "RZ":
        return _RZ(q, a)
    return _RY(q, a)

def _ucr(kind: String, ctrls: List[Int], t: Int, angles: List[Float64], mut out: List[GateOp]):
    var k = len(ctrls)
    if k == 0:
        if abs(angles[0]) > ANG_EPS:
            out.append(_rot(kind, t, angles[0]))
        return
    var half = len(angles) // 2
    var a = List[Float64]()
    var b = List[Float64]()
    for j in range(half):
        a.append(0.5 * (angles[j] + angles[half + j]))
        b.append(0.5 * (angles[j] - angles[half + j]))
    var rest = _tail(ctrls)
    _ucr(kind, rest, t, a, out)
    out.append(_CX(ctrls[0], t))
    var tmp = List[GateOp]()
    _ucr(kind, rest, t, b, tmp)
    for i in range(len(tmp) - 1, -1, -1):
        out.append(tmp[i].copy())
    out.append(_CX(ctrls[0], t))

def _cancel_cx(gates_in: List[GateOp]) -> List[GateOp]:
    var g = gates_in.copy()
    var changed = True
    while changed:
        changed = False
        var alive = List[Bool]()
        for _ in range(len(g)):
            alive.append(True)
        for i in range(len(g)):
            if not alive[i] or g[i].name != "CX":
                continue
            var c = g[i].qubit[0]
            var t = g[i].qubit[1]
            var j = i + 1
            var steps = 0
            while j < len(g) and steps < CANCEL_WINDOW:
                if not alive[j]:
                    j += 1
                    continue
                steps += 1
                var nm = g[j].name
                if nm == "CX":
                    var c2 = g[j].qubit[0]
                    var t2 = g[j].qubit[1]
                    if c2 == c and t2 == t:
                        alive[i] = False
                        alive[j] = False
                        changed = True
                        break
                    if t2 == t and c2 != t:
                        j += 1
                        continue
                    if c2 == c and t2 != c:
                        j += 1
                        continue
                if nm == "RZ" and g[j].qubit[0] == c:
                    j += 1
                    continue
                var touches = False
                for qi in range(len(g[j].qubit)):
                    if g[j].qubit[qi] == c or g[j].qubit[qi] == t:
                        touches = True
                if touches:
                    break
                j += 1
        if changed:
            var nw = List[GateOp]()
            for i in range(len(g)):
                if alive[i]:
                    nw.append(g[i].copy())
            g = nw^
    return g^

struct QSDDecomposer(Copyable, Movable):
    var kak: KAKDecomposer
    var euler: EulerDecomposer
    var use_kak: Bool

    def __init__(out self, use_kak: Bool = True) raises:
        self.kak = KAKDecomposer()
        self.euler = EulerDecomposer("ZYZ")
        self.use_kak = use_kak

    def _extend(self, mut out: List[GateOp], g: List[GateOp]):
        for i in range(len(g)):
            out.append(g[i].copy())

    def _demux(mut self, a0: CMatrix, a1: CMatrix, qubits: List[Int], mut out: List[GateOp]) raises:
        var rest = _tail(qubits)
        var m = a0.n
        var x = a0.matmul(a1.adjoint())
        if x.dist_identity() < 1e-12:
            self._qsd(a1, rest, out)
            return
        var v = CMatrix(m)
        var ang = List[Float64]()
        unitary_eig(x, v, ang)
        var w = v.adjoint().matmul(a1)
        for j in range(m):
            var c = cos(0.5 * ang[j])
            var s = sin(0.5 * ang[j])
            for k in range(m):
                var r = w.re[j * m + k]
                var i = w.im[j * m + k]
                w.re[j * m + k] = c * r - s * i
                w.im[j * m + k] = c * i + s * r
        self._qsd(w, rest, out)
        var rz = List[Float64]()
        for j in range(m):
            rz.append(-ang[j])
        _ucr("RZ", rest, qubits[0], rz, out)
        self._qsd(v, rest, out)

    def _qsd(mut self, u: CMatrix, qubits: List[Int], mut out: List[GateOp]) raises:
        var n = len(qubits)
        if (1 << n) != u.n:
            raise Error("QSDDecomposer: the size of matrix do not match with the number of qubit")
        if n == 1:
            self._extend(out, self.euler.gates(u, qubits[0]))
            return
        if n == 2 and self.use_kak:
            self._extend(out, self.kak.decompose(u, qubits[0], qubits[1], "ZYZ"))
            return
        var l0 = CMatrix(1)
        var l1 = CMatrix(1)
        var r0 = CMatrix(1)
        var r1 = CMatrix(1)
        var cs = List[Float64]()
        var sn = List[Float64]()
        _csd(u, l0, l1, r0, r1, cs, sn)
        self._demux(r0, r1, qubits, out)
        var ry = List[Float64]()
        for j in range(len(cs)):
            ry.append(2.0 * atan2(sn[j], cs[j]))
        _ucr("RY", _tail(qubits), qubits[0], ry, out)
        self._demux(l0, l1, qubits, out)

    def gates(mut self, u: CMatrix, qubits: List[Int]) raises -> List[GateOp]:
        if (1 << len(qubits)) != u.n:
            raise Error("QSDDecomposer: the size of matrix do not match with the number of qubit")
        if not u.is_unitary(1e-8):
            raise Error("QSDDecomposer: matrix is not a unitary")
        var out = List[GateOp]()
        self._qsd(u, qubits, out)
        return _cancel_cx(out)

    def synthesize(mut self, u: CMatrix, qubits: List[Int], bt: BasicTranslator) raises -> List[GateOp]:
        return bt.translate(self.gates(u, qubits))

def qsd_gates(u: CMatrix, qubits: List[Int], use_kak: Bool = True) raises -> List[GateOp]:
    var d = QSDDecomposer(use_kak)
    return d.gates(u, qubits)

def qsd_synthesize(u: CMatrix, qubits: List[Int], bt: BasisTranslator) raises -> List[GateOp]:
    return bt.translate(qsd_gates(u, qubits))

def qsd_synthesize_flat(flat: List[Float64], qubits: List[Int], bt: BasisTranslator) raises -> List[GateOp]:
    return qsd_synthesize(CMatrix.from_flat(flat, 1 << len(qubits)), qubits, bt)