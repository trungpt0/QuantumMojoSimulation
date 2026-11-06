from gates import GateOp
from qmath import PI
from gateop_shortcut import _X, _H, _S, _Sdg, _T, _Tdg, _P, _RX, _RY, _RZ, _CX, _CY, _CZ, _CP, _CRX, _CRY, _CRZ, _CCX, _RCCX
from transpiler import Target, mcx_recursion, _apply_basis_translator
from qutils import int_to_listint

comptime EPS = 1e-12

struct GateSpec(Copyable, Movable):
    var kind: String
    var theta: Float64
    var phi: Float64
    var lam: Float64
    var gamma: Float64

    def __init__(
        out self, 
        kind: String, 
        theta: Float64 = 0.0, 
        phi: Float64 = 0.0,
        lam: Float64 = 0.0,
        gamma: Float64 = 0.0
    ):
        self.kind = kind
        self.theta = theta
        self.phi = phi
        self.lam = lam
        self.gamma = gamma

def _extend(mut g: List[GateOp], sub: List[GateOp]):
    for i in range(len(sub)):
        g.append(sub[i].copy())

def _need(params: List[Float64], k: Int, name: String) raises:
    if len(params) < k:
        raise Error(name + " need " + String(k) + "params")

def gate_spec(name: String, params: List[Float64]) raises -> GateSpec:
    if name == "X":
        return GateSpec("X")
    if name == "Y":
        return GateSpec("Y")
    if name == "Z":
        return GateSpec("Z")
    if name == "S":
        return GateSpec("P", lam=PI/2)
    if name == "SDG":
        return GateSpec("P", lam=-PI/2)
    if name == "T":
        return GateSpec("P", lam=PI/4)
    if name == "TDG":
        return GateSpec("P", lam=-PI/4)
    if name == "P":
        _need(params, 1, name)
        return GateSpec("P", lam=params[0])
    if name == "RZ":
        _need(params, 1, name)
        return GateSpec("RZ", theta=params[0])
    if name == "RY":
        _need(params, 1, name)
        return GateSpec("RY", theta=params[0])
    if name == "RX":
        _need(params, 1, name)
        return GateSpec("RX", theta=params[0])
    if name == "H":
        return GateSpec("U", theta=PI/2, phi=0.0, lam=PI)
    if name == "SX":
        return GateSpec("U", theta=PI/2, phi=-PI/2, lam=PI/2, gamma=PI/4)
    if name == "U":
        _need(params, 3, name)
        return GateSpec("U", theta=params[0], phi=params[1], lam=params[2])
    raise Error("Not support gate: " + name)

def _c1(c: Int, t: Int, spec: GateSpec) -> List[GateOp]:
    var g = List[GateOp]()
    if spec.kind == "X":
        g.append(_CX(c, t))
    elif spec.kind == "Y":
        g.append(_CY(c, t))
    elif spec.kind == "Z":
        g.append(_CZ(c, t))
    elif spec.kind == "P":
        g.append(_CP(c, t, spec.lam))
    elif spec.kind == "RZ":
        g.append(_CRZ(c, t, spec.theta))
    elif spec.kind == "RY":
        g.append(_CRY(c, t, spec.theta))
    elif spec.kind == "RX":
        g.append(_CRX(c, t, spec.theta))
    else:
        var a = spec.gamma + (spec.phi + spec.lam) / 2
        g.append(_RZ(t, (spec.lam - spec.phi) / 2))
        g.append(_CX(c, t))
        g.append(_RZ(t, -(spec.phi + spec.lam) / 2))
        g.append(_RY(t, -spec.theta / 2))
        g.append(_CX(c, t))
        g.append(_RY(t, spec.theta / 2))
        g.append(_RZ(t, spec.phi))
        g.append(_P(c, a))
    return g^

def _drop_last(xs: List[Int]) -> List[Int]:
    var r = List[Int]()
    for i in range(len(xs) - 1):
        r.append(xs[i])
    return r^

def _c2p(name: String, c: Int, t: Int, angle: Float64) -> GateOp:
    var g = _CX(c, t)
    g.name = name
    g.theta.append(angle)
    return g^

def _c3x(c0: Int, c1: Int, c2: Int, t: Int) -> List[GateOp]:
    var a = PI / 8
    var g = List[GateOp]()
    g.append(_H(t))
    g.append(_P(c0, a))
    g.append(_P(c1, a))
    g.append(_P(c2, a))
    g.append(_P(t, a))
    g.append(_CX(c0, c1))
    g.append(_P(c1, -a))
    g.append(_CX(c0, c1))
    g.append(_CX(c1, c2))
    g.append(_P(c2, -a))
    g.append(_CX(c0, c2))
    g.append(_P(c2, a))
    g.append(_CX(c1, c2))
    g.append(_P(c2, -a))
    g.append(_CX(c0, c2))
    g.append(_CX(c2, t))
    g.append(_P(t, -a))
    g.append(_CX(c1, t))
    g.append(_P(t, a))
    g.append(_CX(c2, t))
    g.append(_P(t, -a))
    g.append(_CX(c0, t))
    g.append(_P(t, a))
    g.append(_CX(c2, t))
    g.append(_P(t, -a))
    g.append(_CX(c1, t))
    g.append(_P(t, a))
    g.append(_CX(c2, t))
    g.append(_P(t, -a))
    g.append(_CX(c0, t))
    g.append(_H(t))
    return g^


def _gad_act(mut g: List[GateOp], q0: Int, q1: Int, q2: Int):
    g.append(_H(q2))
    g.append(_T(q2))
    g.append(_CX(q0, q2))
    g.append(_Tdg(q2))
    g.append(_CX(q1, q2))


def _gad_rst(mut g: List[GateOp], q0: Int, q1: Int, q2: Int):
    g.append(_CX(q1, q2))
    g.append(_T(q2))
    g.append(_CX(q0, q2))
    g.append(_Tdg(q2))
    g.append(_H(q2))


def _mcx_i15(controls: List[Int], t: Int, anc: List[Int]) -> List[GateOp]:
    """
    Iten 2016 (synth_mcx_n_dirty_i15): k >= 4 cần k-2 ancilla bẩn, 8k-6 CX.
    k = 3 dùng C3X (14 CX), k <= 2 dùng X, CX, CCX.
    """
    var g = List[GateOp]()
    var n = len(controls)
    if n == 0:
        g.append(_X(t))
        return g^
    if n == 1:
        g.append(_CX(controls[0], t))
        return g^
    if n == 2:
        g.append(_CCX(controls[0], controls[1], t))
        return g^
    if n == 3:
        return _c3x(controls[0], controls[1], controls[2], t)
    for _ in range(2):
        g.append(_CCX(controls[n - 1], anc[n - 3], t))
        for i in range(n - 4, -1, -1):
            _gad_act(g, controls[i + 2], anc[i], anc[i + 1])
        g.append(_RCCX(controls[0], controls[1], anc[0]))
        for i in range(n - 3):
            _gad_rst(g, controls[i + 2], anc[i], anc[i + 1])
    return g^

def _mcx_dirty(controls: List[Int], t: Int, dirty: Int) -> List[GateOp]:
    var g = List[GateOp]()
    var n = len(controls)
    if n == 0:
        g.append(_X(t))
    elif n == 1:
        g.append(_CX(controls[0], t))
    elif n == 2:
        g.append(_CCX(controls[0], controls[1], t))
    elif n == 3:
        return _c3x(controls[0], controls[1], controls[2], t)
    else:
        return mcx_recursion(controls, t, dirty)
    return g^

def _mcx_noaux(controls: List[Int], t: Int) -> List[GateOp]:
    var n = len(controls)
    if n <= 2:
        return _mcx_dirty(controls, t, -1)
    var g = List[GateOp]()
    g.append(_H(t))
    _extend(g, _mcphase_noaux(controls, t, PI))
    g.append(_H(t))
    return g^

def _rot1(cname: String, q: Int, angle: Float64) -> GateOp:
    if cname == "CRZ":
        return _RZ(q, angle)
    return _RY(q, angle)

def _mcrot_noaux(controls: List[Int], t: Int, theta: Float64, cname: String) -> List[GateOp]:
    """
    R(th/4) MCX_A R(-th/4) MCX_B R(th/4) MCX_A R(-th/4) MCX_B, R là RZ hoặc RY.
    Mỗi MCX dùng i15, mượn các điều khiển của nửa kia làm ancilla bẩn. 16m-24 CX.
    """
    var g = List[GateOp]()
    var n = len(controls)
    if n == 1:
        g.append(_c2p(cname, controls[0], t, theta))
        return g^
    var h = (n + 1) // 2
    var A = List[Int]()
    var B = List[Int]()
    for i in range(h):
        A.append(controls[i])
    for i in range(h, n):
        B.append(controls[i])
    var ma = _mcx_i15(A, t, B)
    var mb = _mcx_i15(B, t, A)
    for _ in range(2):
        g.append(_rot1(cname, t, theta / 4))
        _extend(g, ma)
        g.append(_rot1(cname, t, -theta / 4))
        _extend(g, mb)
    return g^

def _mcphase_noaux(controls: List[Int], t: Int, lam: Float64) -> List[GateOp]:
    var g = List[GateOp]()
    var n = len(controls)
    if n == 0:
        g.append(_P(t, lam))
        return g^
    var ctrls = controls.copy()
    var nt = t
    for k in range(n):
        _extend(g, _mcrot_noaux(ctrls, nt, lam / Float64(1 << k), "CRZ"))
        nt = ctrls[len(ctrls) - 1]
        ctrls = _drop_last(ctrls)
    g.append(_P(nt, lam / Float64(1 << n)))
    return g^

def _mc_noaux(controls: List[Int], t: Int, spec: GateSpec) -> List[GateOp]:
    var n = len(controls)
    if n == 1:
        return _c1(controls[0], t, spec)
    var g = List[GateOp]()
    if spec.kind == "X":
        return _mcx_noaux(controls, t)
    elif spec.kind == "Y":
        g.append(_Sdg(t))
        _extend(g, _mcx_noaux(controls, t))
        g.append(_S(t))
    elif spec.kind == "Z":
        return _mcphase_noaux(controls, t, PI)
    elif spec.kind == "P":
        return _mcphase_noaux(controls, t, spec.lam)
    elif spec.kind == "RZ":
        return _mcrot_noaux(controls, t, spec.theta, "CRZ")
    elif spec.kind == "RY":
        return _mcrot_noaux(controls, t, spec.theta, "CRY")
    elif spec.kind == "RX":
        g.append(_H(t))
        _extend(g, _mcrot_noaux(controls, t, spec.theta, "CRZ"))
        g.append(_H(t))
    else:
        var a = spec.gamma + (spec.phi + spec.lam) / 2
        if abs(a) > EPS:
            _extend(g, _mcphase_noaux(_drop_last(controls), controls[n - 1], a))
        if abs(spec.lam) > EPS:
            _extend(g, _mcrot_noaux(controls, t, spec.lam, "CRZ"))
        if abs(spec.theta) > EPS:
            _extend(g, _mcrot_noaux(controls, t, spec.theta, "CRY"))
        if abs(spec.phi) > EPS:
            _extend(g, _mcrot_noaux(controls, t, spec.phi, "CRZ"))
    return g^

def _mc_vchain(controls: List[Int], targets: List[Int], spec: GateSpec,
               ancilla: List[Int], use_ccx: Bool) -> List[GateOp]:
    var g = List[GateOp]()
    var n = len(controls)
    if n == 1:
        for j in range(len(targets)):
            _extend(g, _c1(controls[0], targets[j], spec))
        return g^
    var up = List[GateOp]()
    if use_ccx:
        up.append(_CCX(controls[0], controls[1], ancilla[0]))
        for i in range(2, n):
            up.append(_CCX(controls[i], ancilla[i - 2], ancilla[i - 1]))
    else:
        up.append(_RCCX(controls[0], controls[1], ancilla[0]))
        for i in range(2, n):
            up.append(_RCCX(controls[i], ancilla[i - 2], ancilla[i - 1]))
    var last = ancilla[n - 2]
    _extend(g, up)
    for j in range(len(targets)):
        _extend(g, _c1(last, targets[j], spec))
    for i in range(len(up) - 1, -1, -1):
        g.append(up[i].copy())
    return g^

def mcmt_synthesize(
    controls: List[Int], 
    targets: List[Int], 
    target: Target, 
    gate: String, 
    params: List[Float64], 
    method: String = "noancilla", 
    ancilla: List[Int] = List[Int]()
) raises -> List[GateOp]:
    var spec = gate_spec(gate, params)
    var n = len(controls)
    if n == 0:
        raise Error("Requires at least 1 control qubit")
    if len(targets) == 0:
        raise Error("Requires at least 1 target qubit")
    var g = List[GateOp]()
    if method == "noancilla":
        if spec.kind == "X" and len(targets) >= 2 and n >= 3:
            for j in range(1, len(targets)):
                g.append(_CX(targets[0], targets[j]))
            _extend(g, _mcx_dirty(controls, targets[0], targets[1]))
            for j in range(1, len(targets)):
                g.append(_CX(targets[0], targets[j]))
        else:
            for j in range(len(targets)):
                _extend(g, _mc_noaux(controls, targets[j], spec))
    elif method == "vchain":
        if n >= 2 and len(ancilla) < n - 1:
            raise Error("vchain can " + String(n - 1) + " ancilla")
        g = _mc_vchain(controls, targets, spec, ancilla, target.has_ccx())
    else:
        raise Error("Invalid method: " + method)
    return _apply_basis_translator(g, target)

def mcphase_synthesize(
    controls: List[Int],
    target_q: Int,
    target: Target,
    lam: Float64,
    method: String = "noancilla",
    ancilla: List[Int] = List[Int]()
) raises -> List[GateOp]:
    var p = List[Float64]()
    p.append(lam)
    return mcmt_synthesize(controls, int_to_listint(target_q), target, "P", p, method, ancilla)

def mcrz_synthesize(
    controls: List[Int],
    target_q: Int,
    target: Target,
    theta: Float64,
    method: String = "noancilla",
    ancilla: List[Int] = List[Int]()
) raises -> List[GateOp]:
    var p = List[Float64]()
    p.append(theta)
    return mcmt_synthesize(controls, int_to_listint(target_q), target, "RZ", p, method, ancilla)

def mcry_synthesize(
    controls: List[Int],
    target_q: Int,
    target: Target,
    theta: Float64,
    method: String = "noancilla",
    ancilla: List[Int] = List[Int]()
) raises -> List[GateOp]:
    var p = List[Float64]()
    p.append(theta)
    return mcmt_synthesize(controls, int_to_listint(target_q), target, "RY", p, method, ancilla)

def mcrx_synthesize(
    controls: List[Int],
    target_q: Int,
    target: Target,
    theta: Float64,
    method: String = "noancilla",
    ancilla: List[Int] = List[Int]()
) raises -> List[GateOp]:
    var p = List[Float64]()
    p.append(theta)
    return mcmt_synthesize(controls, int_to_listint(target_q), target, "RX", p, method, ancilla)

def mcu_synthesize(
    controls: List[Int],
    target_q: Int,
    target: Target,
    theta: Float64,
    phi: Float64,
    lam: Float64,
    method: String = "noancilla",
    ancilla: List[Int] = List[Int]()
) raises -> List[GateOp]:
    var p = List[Float64]()
    p.append(theta)
    p.append(phi)
    p.append(lam)
    return mcmt_synthesize(controls, int_to_listint(target_q), target, "U", p, method, ancilla)
