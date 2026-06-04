from qmath import Matrix2x2, GateMatrix, PI
from gates import GateOp
from std.math import cos, sin, atan2, sqrt, abs

def normalize_angle(angle: Float64) -> Float64:
    var r = angle
    while r > PI: r -= 2.0 * PI
    while r < -PI: r += 2.0 * PI
    return r

struct OneQubitEulerDecomposer:
    def __init__(out self):
        pass

    def run(self, u: Matrix2x2, w: Int) -> List[GateOp]:
        var tol: Float64 = 1e-10
        var a = u.get(0, 0)
        var b = u.get(0, 1)
        var c = u.get(1, 0)
        var d = u.get(1, 1)
        var det_re = (a.re * d.re - a.im * d.im) - (b.re * c.re - b.im * c.im)
        var det_im = (a.re * d.im + a.im * d.re) - (b.re * c.im + b.im * c.re)
        var delta: Float64 = atan2(det_im, det_re) / 2.0
        var cos_delta = cos(delta)
        var sin_delta = sin(delta)
        var a2_re = a.re * cos_delta - a.im * sin_delta
        var a2_im = -a.re * sin_delta + a.im * cos_delta
        var b2_re = b.re * cos_delta - b.im * sin_delta
        var b2_im = -b.re * sin_delta + b.im * cos_delta
        var c2_re = c.re * cos_delta - c.im * sin_delta
        var c2_im = -c.re * sin_delta + c.im * cos_delta
        var d2_re = d.re * cos_delta - d.im * sin_delta
        var d2_im = -d.re * sin_delta + d.im * cos_delta
        var a2_norm = sqrt(a2_re * a2_re + a2_im * a2_im)
        var c2_norm = sqrt(c2_re * c2_re + c2_im * c2_im)
        var beta: Float64 = 2.0 * atan2(c2_norm, a2_norm)
        var alpha: Float64 = 0.0
        var gamma: Float64 = 0.0
        if abs(sin(beta / 2.0)) > tol and abs(cos(beta / 2.0)) > tol:
            var arg_a2 = atan2(a2_im, a2_re)
            var arg_b2 = atan2(b2_im, b2_re)
            var arg_c2 = atan2(c2_im, c2_re)
            var arg_d2 = atan2(d2_im, d2_re)
            alpha = normalize_angle(arg_c2 - arg_a2)
            gamma = normalize_angle(arg_d2 - arg_c2)
        elif abs(sin(beta / 2.0)) < tol:
            var arg_a2 = atan2(a2_im, a2_re)
            alpha = normalize_angle(-2.0 * arg_a2)
            gamma = 0.0
            beta  = 0.0
        else:
            var arg_c2 = atan2(c2_im, c2_re)
            alpha = normalize_angle(2.0 * arg_c2)
            gamma = 0.0
        var result = List[GateOp]()
        var ql = List[Int]()
        ql.append(w)
        if abs(gamma) > tol:
            var p = List[Float64]()
            p.append(gamma)
            result.append(GateOp("RZ", ql, p))
        if abs(beta) > tol:
            var p = List[Float64]()
            p.append(beta)
            result.append(GateOp("RY", ql, p))
        if abs(alpha) > tol:
            var p = List[Float64]()
            p.append(alpha)
            result.append(GateOp("RZ", ql, p))
        if len(result) == 0:
            result.append(GateOp("I", ql))
        return result^

    def verify(self, u: Matrix2x2, gates: List[GateOp]) -> Float64:
        var rec = Matrix2x2()
        for i in range(len(gates)):
            var m = GateMatrix.get_1q(gates[i].name, gates[i].theta)
            rec = m.mul(rec)
        var product = u.dagger().mul(rec)
        var tr = product.trace()
        return (tr.re * tr.re + tr.im * tr.im) / 4.0