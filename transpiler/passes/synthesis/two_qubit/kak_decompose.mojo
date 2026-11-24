from std.math import sqrt, cos, sin, atan2
from gates import GateOp
from gateop_shortcut import _CX
from qmath import CMatrix, herm_eig, phase_error, cdet, kron2
from transpiler import EulerDecomposer, Gate1Q

comptime HALF_PI = 1.5707963267948966
comptime S_LOCAL = 0
comptime S_CX01 = 1
comptime S_CX10 = 2
comptime MATCH_TOL = 1e-6        # noi tu 1e-9: cho phep bo toa do ~1e-9 (VERIFY_TOL van chan sai)
comptime VERIFY_TOL = 1e-7
comptime VW_TOTAL = 1296
comptime VW_HINT0 = 924
comptime TWO_CX_TOL = 1e-6
comptime TRACE_TOL = 1e-6

struct Steps(Copyable, Movable):
    var kind: List[Int]
    var a: List[CMatrix]
    var b: List[CMatrix]

    def __init__(out self):
        self.kind = List[Int]()
        self.a = List[CMatrix]()
        self.b = List[CMatrix]()

    def local(mut self, a: CMatrix, b: CMatrix):
        self.kind.append(S_LOCAL)
        self.a.append(a.copy())
        self.b.append(b.copy())

    def cx(mut self, k: Int):
        self.kind.append(k)
        self.a.append(CMatrix.identity(2))
        self.b.append(CMatrix.identity(2))

    def extend(mut self, o: Steps):
        for i in range(len(o.kind)):
            self.kind.append(o.kind[i])
            self.a.append(o.a[i].copy())
            self.b.append(o.b[i].copy())

    def ncx(self) -> Int:
        var c = 0
        for i in range(len(self.kind)):
            if self.kind[i] != S_LOCAL:
                c += 1
        return c

    def matrix(self) -> CMatrix:
        var m = CMatrix.identity(4)
        for i in range(len(self.kind)):
            if self.kind[i] == S_LOCAL:
                m = kron2(self.a[i], self.b[i]).matmul(m)
            else:
                m = _cx_matrix(self.kind[i]).matmul(m)
        return m^

    def merged(self) -> Steps:
        var o = Steps()
        for i in range(len(self.kind)):
            var n = len(o.kind)
            if self.kind[i] == S_LOCAL and n > 0 and o.kind[n - 1] == S_LOCAL:
                o.a[n - 1] = self.a[i].matmul(o.a[n - 1])
                o.b[n - 1] = self.b[i].matmul(o.b[n - 1])
            else:
                o.kind.append(self.kind[i])
                o.a.append(self.a[i].copy())
                o.b.append(self.b[i].copy())
        return o^

def _cx_matrix(kind: Int) -> CMatrix:
    var m = CMatrix(4)
    for i in range(4):
        var j = i
        if kind == S_CX01 and i >= 2:
            j = 5 - i
        if kind == S_CX10 and (i == 1 or i == 3):
            j = 4 - i
        m.re[j * 4 + i] = 1.0
    return m^

def _magic() -> CMatrix:
    var r = 0.7071067811865476
    var q = CMatrix(4)
    q.re[0] = r
    q.im[3] = r
    q.im[5] = r
    q.re[6] = r
    q.im[9] = r
    q.re[10] = -r
    q.re[12] = r
    q.im[15] = -r
    return q^

def _to_su4(u: CMatrix) -> CMatrix:
    var d = cdet(u)
    var ang = -0.25 * atan2(d[1], d[0])
    var c = cos(ang)
    var s = sin(ang)
    var r = CMatrix(4)
    for k in range(16):
        r.re[k] = c * u.re[k] - s * u.im[k]
        r.im[k] = c * u.im[k] + s * u.re[k]
    return r^

struct Spec(Copyable, Movable):
    var ub: CMatrix
    var p: CMatrix
    var dre: List[Float64]
    var dim: List[Float64]

    def __init__(out self):
        self.ub = CMatrix(4)
        self.p = CMatrix(4)
        self.dre = List[Float64]()
        self.dim = List[Float64]()

def _negate_col(mut m: CMatrix, j: Int):
    for k in range(m.n):
        m.re[k * m.n + j] = -m.re[k * m.n + j]
        m.im[k * m.n + j] = -m.im[k * m.n + j]

# ub = Q^dag U Q (da tinh san):  M = ub^T ub = P D P^T
def _spec_ub(ub: CMatrix) raises -> Spec:
    var sp = Spec()
    sp.ub = ub.copy()
    var m = ub.transpose().matmul(ub)
    for t in [0.6180339887, 1.4142135623, 0.3183098861, 2.7182818284, 0.5772156649]:
        var s = CMatrix(4)
        for k in range(16):
            s.re[k] = m.re[k] + t * m.im[k]
        var p = CMatrix(4)
        _ = herm_eig(s, p)
        for k in range(16):
            p.im[k] = 0.0
        var d = p.transpose().matmul(m).matmul(p)
        var off = 0.0
        for i in range(4):
            for j in range(4):
                if i != j:
                    var e = abs(d.re[i * 4 + j]) + abs(d.im[i * 4 + j])
                    if e > off:
                        off = e
        if off < 1e-10:
            if cdet(p)[0] < 0.0:
                _negate_col(p, 0)
            sp.p = p^
            for i in range(4):
                sp.dre.append(d.re[i * 4 + i])
                sp.dim.append(d.im[i * 4 + i])
            return sp^
    raise Error("KAKDecomposer: not diagonalizable")

def _spec(us: CMatrix, q: CMatrix) raises -> Spec:
    return _spec_ub(q.adjoint().matmul(us).matmul(q))

def _match(su: Spec, st: Spec, mut perm: List[Int]) -> Int:
    for sgn in [1, -1]:
        perm.clear()
        var used = List[Bool]()
        for _ in range(4):
            used.append(False)
        var ok = True
        for k in range(4):
            var best = -1
            var bd = 1e300
            for j in range(4):
                if used[j]:
                    continue
                var dr = Float64(sgn) * st.dre[j] - su.dre[k]
                var di = Float64(sgn) * st.dim[j] - su.dim[k]
                var dd = sqrt(dr * dr + di * di)
                if dd < bd:
                    bd = dd
                    best = j
            if bd > MATCH_TOL:
                ok = False
                break
            used[best] = True
            perm.append(best)
        if ok:
            return sgn
    return 0

def _solve(su: Spec, st: Spec, sgn: Int, perm: List[Int], q: CMatrix,
           mut left: CMatrix, mut right: CMatrix) raises:
    var pt = CMatrix(4)
    for k in range(4):
        for r in range(4):
            pt.re[r * 4 + k] = st.p.re[r * 4 + perm[k]]
    if cdet(pt)[0] < 0.0:
        _negate_col(pt, 0)
    var fr = List[Float64]()
    var fi = List[Float64]()
    var prr = 1.0
    var pri = 0.0
    for k in range(4):
        var h = 0.5 * atan2(su.dim[k], su.dre[k])
        fr.append(cos(h))
        fi.append(sin(h))
        var nr = prr * fr[k] - pri * fi[k]
        pri = prr * fi[k] + pri * fr[k]
        prr = nr
    if prr < 0.0:
        fr[0] = -fr[0]
        fi[0] = -fi[0]
    var ku = su.ub.matmul(su.p)
    var tb = st.ub.copy()
    if sgn < 0:
        for k in range(16):
            var r = tb.re[k]
            tb.re[k] = -tb.im[k]
            tb.im[k] = r
    var kt = tb.matmul(pt)
    for k in range(4):
        for r in range(4):
            var xr = ku.re[r * 4 + k]
            var xi = ku.im[r * 4 + k]
            ku.re[r * 4 + k] = xr * fr[k] + xi * fi[k]
            ku.im[r * 4 + k] = xi * fr[k] - xr * fi[k]
            xr = kt.re[r * 4 + k]
            xi = kt.im[r * 4 + k]
            kt.re[r * 4 + k] = xr * fr[k] + xi * fi[k]
            kt.im[r * 4 + k] = xi * fr[k] - xr * fi[k]
    var qa = q.adjoint()
    left = q.matmul(ku.matmul(kt.transpose())).matmul(qa)
    right = q.matmul(pt.matmul(su.p.transpose())).matmul(qa)

def _factor_local(g: CMatrix, mut a: CMatrix, mut b: CMatrix) raises:
    var bi0 = 0
    var bj0 = 0
    var bestn = -1.0
    for i in range(2):
        for j in range(2):
            var s = 0.0
            for k in range(2):
                for l in range(2):
                    var idx = (2 * i + k) * 4 + (2 * j + l)
                    s += g.re[idx] * g.re[idx] + g.im[idx] * g.im[idx]
            if s > bestn:
                bestn = s
                bi0 = i
                bj0 = j
    var nrm = sqrt(0.5 * bestn)
    b = CMatrix(2)
    for k in range(2):
        for l in range(2):
            var idx = (2 * bi0 + k) * 4 + (2 * bj0 + l)
            b.re[k * 2 + l] = g.re[idx] / nrm
            b.im[k * 2 + l] = g.im[idx] / nrm
    a = CMatrix(2)
    for i in range(2):
        for j in range(2):
            var sr = 0.0
            var si = 0.0
            for k in range(2):
                for l in range(2):
                    var idx = (2 * i + k) * 4 + (2 * j + l)
                    var br = b.re[k * 2 + l]
                    var bim = b.im[k * 2 + l]
                    sr += br * g.re[idx] + bim * g.im[idx]
                    si += br * g.im[idx] - bim * g.re[idx]
            a.re[i * 2 + j] = 0.5 * sr
            a.im[i * 2 + j] = 0.5 * si
    var chk = kron2(a, b)
    var e = 0.0
    for k in range(16):
        var dr = abs(chk.re[k] - g.re[k])
        var di = abs(chk.im[k] - g.im[k])
        if dr > e:
            e = dr
        if di > e:
            e = di
    if e > 1e-6:
        raise Error("KAKDecomposer: can not decompose into A tensor with B")

def _t_identity() -> Steps:
    var s = Steps()
    s.local(CMatrix.identity(2), CMatrix.identity(2))
    return s^

def _t_cx() -> Steps:
    var s = Steps()
    s.cx(S_CX01)
    return s^

def _t_two(x: Float64, z: Float64) -> Steps:
    var s = Steps()
    s.cx(S_CX01)
    s.local(Gate1Q.rx(-2.0 * x), Gate1Q.rz(-2.0 * z))
    s.cx(S_CX01)
    return s^

def _t_vw(t1: Float64, t2: Float64, t3: Float64) -> Steps:
    var s = Steps()
    s.cx(S_CX10)
    s.local(Gate1Q.rz(t1), Gate1Q.ry(t2))
    s.cx(S_CX01)
    s.local(CMatrix.identity(2), Gate1Q.ry(t3))
    s.cx(S_CX10)
    return s^

def _t_vw_index(j: Int, a: Float64, b: Float64, c: Float64) -> Steps:
    var o = j % 27
    var s = (j // 27) % 8
    var p = j // 216
    var x1: Float64
    var x2: Float64
    var x3: Float64
    if p == 0:
        x1 = a
        x2 = b
        x3 = c
    elif p == 1:
        x1 = a
        x2 = c
        x3 = b
    elif p == 2:
        x1 = b
        x2 = a
        x3 = c
    elif p == 3:
        x1 = b
        x2 = c
        x3 = a
    elif p == 4:
        x1 = c
        x2 = a
        x3 = b
    else:
        x1 = c
        x2 = b
        x3 = a
    var s1 = -1.0 if (s & 1) != 0 else 1.0
    var s2 = -1.0 if (s & 2) != 0 else 1.0
    var s3 = -1.0 if (s & 4) != 0 else 1.0
    var o1 = Float64(o // 9 - 1)
    var o2 = Float64((o // 3) % 3 - 1)
    var o3 = Float64(o % 3 - 1)
    return _t_vw(s1 * 2.0 * x1 + o1 * HALF_PI,
                 s2 * 2.0 * x2 + o2 * HALF_PI,
                 s3 * 2.0 * x3 + o3 * HALF_PI)

def _t_four(a: Float64, b: Float64, c: Float64) -> Steps:
    var s = Steps()
    s.cx(S_CX01)
    s.local(Gate1Q.h(), CMatrix.identity(2))
    s.cx(S_CX01)
    s.local(CMatrix.identity(2), Gate1Q.rz(2.0 * b))
    s.cx(S_CX01)
    s.local(Gate1Q.rx(-2.0 * a).matmul(Gate1Q.h()), Gate1Q.rz(-2.0 * c))
    s.cx(S_CX01)
    return s^

def _emit(st: Steps, q0: Int, q1: Int, dec: EulerDecomposer) raises -> List[GateOp]:
    var g = List[GateOp]()
    for i in range(len(st.kind)):
        if st.kind[i] == S_LOCAL:
            var ga = dec.gates(st.a[i], q0)
            var gb = dec.gates(st.b[i], q1)
            for k in range(len(ga)):
                g.append(ga[k].copy())
            for k in range(len(gb)):
                g.append(gb[k].copy())
        elif st.kind[i] == S_CX01:
            g.append(_CX(q0, q1))
        else:
            g.append(_CX(q1, q0))
    return g^

def _traces_of(ub: CMatrix) -> Tuple[Float64, Float64, Float64, Float64]:
    var m = ub.transpose().matmul(ub)
    var t1r = 0.0
    var t1i = 0.0
    var t2r = 0.0
    var t2i = 0.0
    for i in range(4):
        t1r += m.re[i * 4 + i]
        t1i += m.im[i * 4 + i]
        for j in range(4):
            var ar = m.re[i * 4 + j]
            var ai = m.im[i * 4 + j]
            var br = m.re[j * 4 + i]
            var bi = m.im[j * 4 + i]
            t2r += ar * br - ai * bi
            t2i += ar * bi + ai * br
    return (t1r, t1i, t2r, t2i)

def _traces_spec(sp: Spec) -> Tuple[Float64, Float64, Float64, Float64]:
    var t1r = 0.0
    var t1i = 0.0
    var t2r = 0.0
    var t2i = 0.0
    for k in range(4):
        var r = sp.dre[k]
        var i = sp.dim[k]
        t1r += r
        t1i += i
        t2r += r * r - i * i
        t2i += 2.0 * r * i
    return (t1r, t1i, t2r, t2i)

def _traces_close(a: Tuple[Float64, Float64, Float64, Float64], b: Tuple[Float64, Float64, Float64, Float64]) -> Bool:
    if abs(a[2] - b[2]) > TRACE_TOL or abs(a[3] - b[3]) > TRACE_TOL:
        return False
    var plus = abs(a[0] - b[0]) <= TRACE_TOL and abs(a[1] - b[1]) <= TRACE_TOL
    var minus = abs(a[0] + b[0]) <= TRACE_TOL and abs(a[1] + b[1]) <= TRACE_TOL
    return plus or minus

struct KAKDecomposer(Copyable, Movable):
    var q: CMatrix
    var hint: Int
    var spec_id: Spec
    var spec_cx: Spec

    def __init__(out self) raises:
        var q = _magic()
        self.spec_id = _spec(_to_su4(_t_identity().matrix()), q)
        self.spec_cx = _spec(_to_su4(_t_cx().matrix()), q)
        self.q = q^
        self.hint = VW_HINT0

    def _try_spec(self, cand: Steps, st: Spec, u: CMatrix, su: Spec, mut out: Steps) -> Bool:
        try:
            var perm = List[Int]()
            var sgn = _match(su, st, perm)
            if sgn == 0:
                return False
            var left = CMatrix(4)
            var right = CMatrix(4)
            _solve(su, st, sgn, perm, self.q, left, right)
            var la = CMatrix(2)
            var lb = CMatrix(2)
            var ra = CMatrix(2)
            var rb = CMatrix(2)
            _factor_local(left, la, lb)
            _factor_local(right, ra, rb)
            var fin = Steps()
            fin.local(ra, rb)
            fin.extend(cand)
            fin.local(la, lb)
            var mg = fin.merged()
            if phase_error(u, mg.matrix()) < VERIFY_TOL:
                out = mg^
                return True
        except e:
            return False
        return False

    # loai nhanh bang vet; U_B chi tinh 1 lan
    def _try(self, cand: Steps, u: CMatrix, su: Spec, tu: Tuple[Float64, Float64, Float64, Float64], mut out: Steps) -> Bool:
        try:
            var us = _to_su4(cand.matrix())
            var ub = self.q.adjoint().matmul(us).matmul(self.q)
            if not _traces_close(_traces_of(ub), tu):
                return False
            var st = _spec_ub(ub)
            return self._try_spec(cand, st, u, su, out)
        except e:
            return False

    def decompose_steps(mut self, u: CMatrix) raises -> Steps:
        if u.n != 4:
            raise Error("KAKDecomposer: need a 4x4 matrix")
        var su = _spec(_to_su4(u), self.q)
        var tu = _traces_spec(su)
        var e0 = 0.5 * atan2(su.dim[0], su.dre[0])
        var e1 = 0.5 * atan2(su.dim[1], su.dre[1])
        var e2 = 0.5 * atan2(su.dim[2], su.dre[2])
        var a = 0.5 * (e0 + e2)
        var b = 0.5 * (e1 + e2)
        var c = 0.5 * (e0 + e1)
        var best = Steps()
        if self._try_spec(_t_identity(), self.spec_id, u, su, best):
            return best^
        if self._try_spec(_t_cx(), self.spec_cx, u, su, best):
            return best^
        var co = List[Float64]()
        co.append(a)
        co.append(b)
        co.append(c)
        for k in range(3):
            if abs(sin(2.0 * co[k])) < TWO_CX_TOL:
                var x = co[(k + 1) % 3]
                var z = co[(k + 2) % 3]
                if self._try(_t_two(x, z), u, su, tu, best):
                    return best^
                if self._try(_t_two(z, x), u, su, tu, best):
                    return best^
        for i in range(VW_TOTAL):
            var j = (self.hint + i) % VW_TOTAL
            if self._try(_t_vw_index(j, a, b, c), u, su, tu, best):
                self.hint = j
                return best^
        if self._try(_t_four(a, b, c), u, su, tu, best):
            return best^
        raise Error("KAKDecomposer: cannot decompose")

    def decompose(mut self, u: CMatrix, q0: Int, q1: Int, basis: String = "ZYZ") raises -> List[GateOp]:
        var dec = EulerDecomposer(basis)
        var st = self.decompose_steps(u)
        return _emit(st, q0, q1, dec)

    def cx_count(mut self, u: CMatrix) raises -> Int:
        return self.decompose_steps(u).ncx()

def kak_gates(u: CMatrix, q0: Int, q1: Int, basis: String = "ZYZ") raises -> List[GateOp]:
    var k = KAKDecomposer()
    return k.decompose(u, q0, q1, basis)