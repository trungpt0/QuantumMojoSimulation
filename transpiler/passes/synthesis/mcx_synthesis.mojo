from gates import GateOp
from qmath import PI
from gateop_shortcut import _X, _H, _P, _CX, _CCX, _RCCX
from transpiler import basis_translate

def _extend(mut g: List[GateOp], sub: List[GateOp]):
    for i in range(len(sub)):
        g.append(sub[i].copy())

def _cphase(a: Int, b: Int, lam: Float64) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_P(a, lam / 2))
    g.append(_CX(a, b))
    g.append(_P(b, -lam / 2))
    g.append(_CX(a, b))
    g.append(_P(b, lam / 2))
    return g^

def _mcphase_noancilla(controls: List[Int], target_q: Int, lam: Float64) -> List[GateOp]:
    var g = List[GateOp]()
    var k = len(controls)
    if k == 1:
        _extend(g, _cphase(controls[0], target_q, lam))
        return g^
    var s = controls[k - 1]
    var rest = List[Int]()
    for i in range(k - 1):
        rest.append(controls[i])
    var flip = mcx_noancilla(rest, s)
    _extend(g, _cphase(s, target_q, lam / 2))
    _extend(g, flip)
    _extend(g, _cphase(s, target_q, -lam / 2))
    _extend(g, flip)
    _extend(g, _mcphase_noancilla(rest, target_q, lam / 2))
    return g^

def mcx_noancilla(controls: List[Int], target_q: Int) -> List[GateOp]:
    var g = List[GateOp]()
    var n = len(controls)
    if n == 0:
        g.append(_X(target_q))
    elif n == 1:
        g.append(_CX(controls[0], target_q))
    elif n == 2:
        g.append(_CCX(controls[0], controls[1], target_q))
    else:
        g.append(_H(target_q))
        _extend(g, _mcphase_noancilla(controls, target_q, PI))
        g.append(_H(target_q))
    return g^

def mcx_vchain(controls: List[Int], target_q: Int, ancilla: List[Int]) -> List[GateOp]:
    var n = len(controls)
    if n <= 2:
        return mcx_noancilla(controls, target_q)
    var g = List[GateOp]()
    g.append(_RCCX(controls[0], controls[1], ancilla[0]))
    for i in range(1, n - 2):
        g.append(_RCCX(controls[i + 1], ancilla[i - 1], ancilla[i]))
    g.append(_CCX(controls[n - 1], ancilla[n - 3], target_q))
    for i in range(n - 3, 0, -1):
        g.append(_RCCX(controls[i + 1], ancilla[i - 1], ancilla[i]))
    g.append(_RCCX(controls[0], controls[1], ancilla[0]))
    return g^

struct _Ladder(Movable):
    var ops: List[Int]
    var last: Int

    def __init__(out self, var ops: List[Int], last: Int):
        self.ops = ops^
        self.last = last

def _kg24_greedy(n: Int) -> _Ladder:
    var marked = List[Bool]()
    marked.append(True)
    for _ in range(n):
        marked.append(False)
    var ops = List[Int]()
    while True:
        var found = False
        var t = n
        while t >= 0:
            if marked[t]:
                var x = -1
                var y = -1
                for j in range(t + 1, n + 1):
                    if not marked[j]:
                        if x < 0:
                            x = j
                        else:
                            y = j
                            break
                if y >= 0:
                    ops.append(t)
                    ops.append(x)
                    ops.append(y)
                    marked[t] = False
                    marked[x] = True
                    marked[y] = True
                    found = True
                    break
            t -= 1
        if not found:
            break
    var last = -1
    for j in range(1, n + 1):
        if not marked[j]:
            last = j
    return _Ladder(ops^, last)

def _kq(idx: Int, controls: List[Int], ancilla: Int) -> Int:
    return ancilla if idx == 0 else controls[idx - 1]

def mcx_recursion(controls: List[Int], target_q: Int, ancilla: Int) -> List[GateOp]:
    var n = len(controls)
    if n <= 2:
        return mcx_noancilla(controls, target_q)
    var lad = _kg24_greedy(n)
    var n_ops = len(lad.ops) // 3
    var u = controls[lad.last - 1]
    var first = _RCCX(_kq(lad.ops[1], controls, ancilla), _kq(lad.ops[2], controls, ancilla), ancilla)
    var L = List[GateOp]()
    for k in range(1, n_ops):
        var tq = _kq(lad.ops[3 * k], controls, ancilla)
        var xq = _kq(lad.ops[3 * k + 1], controls, ancilla)
        var yq = _kq(lad.ops[3 * k + 2], controls, ancilla)
        L.append(_RCCX(xq, yq, tq))
        L.append(_X(tq))
    var Linv = List[GateOp]()
    for k in range(n_ops - 1, 0, -1):
        var tq = _kq(lad.ops[3 * k], controls, ancilla)
        var xq = _kq(lad.ops[3 * k + 1], controls, ancilla)
        var yq = _kq(lad.ops[3 * k + 2], controls, ancilla)
        Linv.append(_X(tq))
        Linv.append(_RCCX(xq, yq, tq))
    var g = List[GateOp]()
    for _ in range(2):
        g.append(first.copy())
        _extend(g, L)
        g.append(_CCX(ancilla, u, target_q))
        _extend(g, Linv)
    return g^

def mcx_gray_code(controls: List[Int], target_q: Int) -> List[GateOp]:
    var n = len(controls)
    if n <= 2:
        return mcx_noancilla(controls, target_q)
    var g = List[GateOp]()
    var theta = PI / Float64(1 << (n - 1))
    g.append(_H(target_q))
    var prev = 0
    var p_prev = 0
    for k in range(1, 1 << n):
        var code = k ^ (k >> 1)
        var diff = code ^ prev
        var b = 0
        while (diff >> b) > 1:
            b += 1
        var p = 0
        while (code >> p) > 1:
            p += 1
        if k > 1:
            if b != p:
                g.append(_CX(controls[b], controls[p]))
            else:
                g.append(_CX(controls[p_prev], controls[p]))
        var pc = 0
        var tmp = code
        while tmp > 0:
            pc += tmp & 1
            tmp >>= 1
        _extend(g, _cphase(controls[p], target_q, theta if pc % 2 == 1 else -theta))
        prev = code
        p_prev = p
    g.append(_H(target_q))
    return g^

def mcx_synthesize(
    controls: List[Int],
    target_q: Int,
    target: Target,
    method: String = "noancilla",
    ancilla: List[Int] = List[Int]()
) raises -> List[GateOp]:
    var n = len(controls)
    var g: List[GateOp]
    if method == "noancilla":
        g = mcx_noancilla(controls, target_q)
    elif method == "gray_code":
        g = mcx_gray_code(controls, target_q)
    elif method == "vchain":
        if n >= 3 and len(ancilla) < n - 2:
            raise Error("vchain need " + String(n - 2) + " ancilla")
        g = mcx_vchain(controls, target_q, ancilla)
    elif method == "recursion":
        if n >= 3 and len(ancilla) < 1:
            raise Error("recursion need 1 ancilla")
        var anc = ancilla[0] if len(ancilla) > 0 else -1
        g = mcx_recursion(controls, target_q, anc)
    else:
        raise Error("Invalid method: " + method)
    return basis_translate(g, target)