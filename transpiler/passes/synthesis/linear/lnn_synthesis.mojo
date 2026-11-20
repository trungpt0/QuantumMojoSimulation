from qmath import BitMatrix, ops_two_phase, ops_relabel

def _lnn_lower(mut a: BitMatrix, mut ops: List[Int]) raises:
    var n = a.n
    for c in range(n):
        var maxrow = -1
        for r in range(n - 1, c - 1, -1):
            if a.get(r, c) == 1:
                maxrow = r
                break
        if maxrow < 0:
            raise Error("LNN: singular matrix")
        if a.get(c, c) == 0:
            var r = c + 1
            while a.get(r, c) == 0:
                r += 1
            for i in range(r - 1, c - 1, -1):
                if a.get(i, c) == 0:
                    a.xor_row(i, i + 1)
                    ops.append(i + 1)
                    ops.append(i)
        for i in range(c + 1, maxrow + 1):
            if a.get(i, c) == 0:
                a.xor_row(i, i - 1)
                ops.append(i - 1)
                ops.append(i)
        for i in range(maxrow, c, -1):
            a.xor_row(i, i - 1)
            ops.append(i - 1)
            ops.append(i)

def lnn_ops(a_in: BitMatrix) raises -> List[Int]:
    var a = a_in.copy()
    var ops1 = List[Int]()
    _lnn_lower(a, ops1)
    var at = a.transposed()
    var ops2 = List[Int]()
    _lnn_lower(at, ops2)
    return ops_two_phase(ops1, ops2)

def lnn_ops_order(a: BitMatrix, order: List[Int]) raises -> List[Int]:
    var n = a.n
    if len(order) != n:
        raise Error("lnn_ops_order: len(order) != n")
    var seen = List[Bool]()
    for _ in range(n):
        seen.append(False)
    for i in range(n):
        if order[i] < 0 or order[i] >= n or seen[order[i]]:
            raise Error("lnn_ops_order: order is not permute")
        seen[order[i]] = True
    return ops_relabel(lnn_ops(a.permuted(order)), order)