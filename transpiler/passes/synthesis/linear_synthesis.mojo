from gates import GateOp
from qmath import (
    BitMatrix, 
    bm_from_rows, bm_from_flat, bm_is_invertible, bm_inverse,
    ops_apply, ops_depth, ops_reverse, ops_swap, ops_reverse_swap, ops_to_gates, gates_to_ops, ops_relabel)
from transpiler import gauss_ops, pmh_ops, lnn_ops, lnn_ops_order, kms_ops, kms_ops_order
from transpiler import BasisTranslator

comptime V_DIRECT   = 0
comptime V_TRANS    = 1
comptime V_INV      = 2
comptime V_INV_T    = 3
comptime OPT_MAX_N  = 4

def _pack(a: BitMatrix) -> Int:
    var n = a.n
    var k = 0
    for r in range(n):
        for c in range(n):
            if a.get(r, c) == 1:
                k |= 1 << (r * n + c)
    return k

def optimal_ops_small(a: BitMatrix) raises -> List[Int]:
    var n = a.n
    if n > OPT_MAX_N:
        raise Error("optimal_ops_small: n <= 4")
    if n <= 1:
        return List[Int]()
    var size = 1 << (n * n)
    var rmask = (1 << n) - 1
    var par_state = List[Int]()
    var par_gate = List[Int]()
    for _ in range(size):
        par_state.append(-1)
        par_gate.append(-1)
    var start = 0
    for i in range(n):
        start |= 1 << (i * n + i)
    var target = _pack(a)
    par_state[start] = start
    var queue = List[Int]()
    queue.append(start)
    var head = 0
    var found = start == target
    while head < len(queue) and not found:
        var s = queue[head]
        head += 1
        for c in range(n):
            var rc = (s >> (c * n)) & rmask
            for t in range(n):
                if t == c:
                    continue
                var ns = s ^ (rc << (t * n))
                if par_state[ns] < 0:
                    par_state[ns] = s
                    par_gate[ns] = c * n + t
                    queue.append(ns)
                    if ns == target:
                        found = True
                        break
            if found:
                break
    if not found:
        raise Error("optimal_ops_small: singular matrix")
    var rev = List[Int]()
    var k = target
    while k != start:
        var g = par_gate[k]
        rev.append(g % n)
        rev.append(g // n)
        k = par_state[k]
    var ops = List[Int]()
    for i in range(len(rev) - 1, -1, -1):
        ops.append(rev[i])
    return ops^

def cx_cancel(ops_in: List[Int], window: Int = 256) -> List[Int]:
    var ops = ops_in.copy()
    var changed = True
    var rounds = 0
    while changed and rounds < 20:
        changed = False
        rounds += 1
        var m = len(ops) // 2
        var alive = List[Bool]()
        for _ in range(m):
            alive.append(True)
        for i in range(m):
            if not alive[i]:
                continue
            var a = ops[2 * i]
            var b = ops[2 * i + 1]
            var steps = 0
            var j = i + 1
            while j < m and steps < window:
                if alive[j]:
                    var c = ops[2 * j]
                    var d = ops[2 * j + 1]
                    if c == a and d == b:
                        alive[i] = False
                        alive[j] = False
                        changed = True
                        break
                    if d == a or c == b:
                        break
                    steps += 1
                j += 1
        if changed:
            var nw = List[Int]()
            for i in range(m):
                if alive[i]:
                    nw.append(ops[2 * i])
                    nw.append(ops[2 * i + 1])
            ops = nw^
    return ops^

def _variant_matrix(a: BitMatrix, kind: Int) raises -> BitMatrix:
    if kind == V_DIRECT:
        return a.copy()
    if kind == V_TRANS:
        return a.transposed()
    if kind == V_INV:
        return bm_inverse(a)
    return bm_inverse(a).transposed()

def _variant_back(ops: List[Int], kind: Int) -> List[Int]:
    if kind == V_DIRECT:
        return ops.copy()
    if kind == V_TRANS:
        return ops_reverse_swap(ops)
    if kind == V_INV:
        return ops_reverse(ops)
    return ops_swap(ops)

def _base(a: BitMatrix, base: String, section: Int, order: List[Int]) raises -> List[Int]:
    if base == "lnn":
        return lnn_ops_order(a, order) if len(order) > 0 else lnn_ops(a)
    if base == "kms":
        return kms_ops_order(a, order) if len(order) > 0 else kms_ops(a)
    var v = a.permuted(order) if len(order) > 0 else a.copy()
    var ops: List[Int]
    if base == "gauss":
        ops = gauss_ops(v)
    elif base == "pmh":
        ops = pmh_ops(v, section)
    else:
        raise Error("Invalid base: " + base)
    if len(order) > 0:
        return ops_relabel(ops, order)
    return ops^

def _reversed_order(n: Int, order: List[Int]) -> List[Int]:
    var o = List[Int]()
    for k in range(n - 1, -1, -1):
        o.append(order[k] if len(order) > 0 else k)
    return o^

def _better(ops: List[Int], best: List[Int], have: Bool, n: Int, by_depth: Bool) -> Bool:
    if not have:
        return True
    if by_depth:
        var d1 = ops_depth(ops, n)
        var d2 = ops_depth(best, n)
        if d1 != d2:
            return d1 < d2
    return len(ops) < len(best)

def _search(
    a: BitMatrix, 
    base: String, 
    sections: List[Int], 
    orders: List[List[Int]],
    optimize: Bool,
    by_depth: Bool = False
) raises -> List[Int]:
    var best = List[Int]()
    var have = False
    for kind in range(4):
        var v = _variant_matrix(a, kind)
        for oi in range(len(orders)):
            for si in range(len(sections)):
                var ops = _variant_back(_base(v, base, sections[si], orders[oi]), kind)
                if optimize:
                    ops = cx_cancel(ops)
                if _better(ops, best, have, a.n, by_depth):
                    best = ops^
                    have = True
    return best^

def _pmh_sections(n: Int) -> List[Int]:
    var s = List[Int]()
    var top = 8 if n > 8 else n
    if top < 1: top = 1
    for m in range(1, top + 1):
        s.append(m)
    return s^

def _line_orders(n: Int, line_order: List[Int]) -> List[List[Int]]:
    var o = List[List[Int]]()
    o.append(line_order.copy())
    o.append(_reversed_order(n, line_order))
    return o^

def _relabel_orders(n: Int) -> List[List[Int]]:
    var o = List[List[Int]]()
    o.append(List[Int]())
    o.append(_reversed_order(n, List[Int]()))
    var k = 6 if n <= 12 else (2 if n <= 32 else 0)
    var s = 12345 + n
    for _ in range(k):
        var p = List[Int]()
        for i in range(n):
            p.append(i)
        for i in range(n - 1, 0, -1):
            s = (s * 1664525 + 1013904223) & 0x7FFFFFFF
            var j = (s >> 8) % (i + 1)
            var tmp = p[i]
            p[i] = p[j]
            p[j] = tmp
        o.append(p^)
    return o^

def linear_ops(
    a: BitMatrix,
    method: String = "auto",
    section: Int = 0,
    optimize: Bool = True,
    line_order: List[Int] = List[Int]()
) raises -> List[Int]:
    var n = a.n
    if n == 0:
        return List[Int]()
    if not bm_is_invertible(a):
        raise Error("linear_ops: singular matrix")
    var one = List[Int]()
    one.append(0)
    var ops: List[Int]
    if method == "gauss" or method == "default":
        ops = gauss_ops(a)
    elif method == "pmh":
        ops = pmh_ops(a, section)
    elif method == "lnn":
        ops = _base(a, "lnn", 0, line_order)
    elif method == "kms":
        ops = _base(a, "kms", 0, line_order)
    elif method == "pmh_best":
        return _search(a, "pmh", _pmh_sections(n), _relabel_orders(n), optimize)
    elif method == "lnn_best":
        return _search(a, "lnn", one, _line_orders(n, line_order), optimize)
    elif method == "kms_best":
        var orders = _line_orders(n, line_order)
        var k = _search(a, "kms", one, orders, optimize, True)
        var l = _search(a, "lnn", one, orders, optimize, True)
        if _better(l, k, True, n, True):
            return l^
        return k^
    elif method == "auto":
        if n <= OPT_MAX_N:
            return optimal_ops_small(a)
        var orders = _relabel_orders(n)
        var p = _search(a, "pmh", _pmh_sections(n), orders, optimize)
        var g = _search(a, "gauss", one, orders, optimize)
        if len(g) < len(p):
            return g^
        return p^
    else:
        raise Error("Invalid linear method: " + method)
    if optimize:
        ops = cx_cancel(ops)
    return ops^

def linear_synthesize(
    a: BitMatrix, 
    method: String = "auto", 
    section: Int = 0,
    optimize: Bool = True,
    line_order: List[Int] = List[Int]()
) raises -> List[GateOp]:
    return ops_to_gates(linear_ops(a, method, section, optimize, line_order))

def linear_synthesize_rows(
    rows: List[Int], 
    n: Int, 
    method: String = "auto",
    section: Int = 0,
    optimize: Bool = True
) raises -> List[GateOp]:
    return linear_synthesize(bm_from_rows(rows, n), method, section, optimize)

def linear_synthesize_flat(
    flat: List[Float64], 
    n: Int, 
    method: String = "auto",
    section: Int = 0, 
    optimize: Bool = True
) raises -> List[GateOp]:
    return linear_synthesize(bm_from_flat(flat, n), method, section, optimize)

def linear_synthesize_on(
    a: BitMatrix, 
    qubits: List[Int], 
    bt: BasisTranslator,
    method: String = "auto", 
    section: Int = 0,
    optimize: Bool = True
) raises -> List[GateOp]:
    var g = linear_synthesize(a, method, section, optimize)
    var out = List[GateOp]()
    for i in range(len(g)):
        var x = g[i].copy()
        x.qubit[0] = qubits[x.qubit[0]]
        x.qubit[1] = qubits[x.qubit[1]]
        out.append(x^)
    return bt.translate(out)

def linear_verify(gates: List[GateOp], a: BitMatrix) raises -> Bool:
    return ops_apply(gates_to_ops(gates), a.n).equals(a)