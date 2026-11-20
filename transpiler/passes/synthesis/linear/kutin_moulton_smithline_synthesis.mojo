from qmath import BitMatrix, bm_identity, bm_is_invertible, ops_reverse, ops_relabel

def _upl(a_in: BitMatrix, mut m_out: BitMatrix, mut labels: List[Int]) raises:
    var n = a_in.n
    var a = a_in.copy()
    var ut = bm_identity(n)
    for i in range(n - 1, -1, -1):
        var pivot = -1
        for r in range(n - 1, -1, -1):
            if a.get(r, i) == 1:
                pivot = r
                break
        if pivot < 0:
            raise Error("KMS: singular matrix")
        for j in range(n):
            if j != pivot and a.get(j, i) == 1:
                a.xor_row(j, pivot)
                ut.xor_row(pivot, j)
        for j in range(i - 1, -1, -1):
            if a.get(pivot, j) == 1:
                a.flip(pivot, j)
    labels.clear()
    for r in range(n):
        var c = 0
        while a.get(r, c) == 0:
            c += 1
        labels.append(n - 1 - c)
    m_out = BitMatrix(n)
    for r in range(n):
        var k = labels[r]
        for x in range(n):
            if ut.get(r, x) == 1:
                m_out.set_one(x, k)

def _op(mut a: BitMatrix, mut m: BitMatrix, track_m: Bool, mut ops: List[Int], c: Int, t: Int):
    a.xor_row(t, c)
    if track_m:
        m.xor_row(t, c)
    ops.append(c)
    ops.append(t)

def _kms_sort(mut a: BitMatrix, mut m: BitMatrix, mut lab: List[Int], step: Int, mut ops: List[Int]):
    var n = a.n
    var parity = 0
    var idle = 0
    var rounds = 0
    var track = step == 1
    while idle < 2 and rounds < 2 * n + 4:
        var changed = False
        var i = parity
        while i + 1 < n:
            var k = lab[i]
            var k2 = lab[i + 1]
            if k > k2:
                changed = True
                var x = m.get(i, k2) if track else a.get(i, k2)
                if step == 1:
                    if x == 1:
                        _op(a, m, track, ops, i, i + 1)
                    else:
                        _op(a, m, track, ops, i + 1, i)
                        _op(a, m, track, ops, i, i + 1)
                else:
                    if x == 1:
                        _op(a, m, track, ops, i, i + 1)
                        _op(a, m, track, ops, i + 1, i)
                    else:
                        _op(a, m, track, ops, i, i + 1)
                        _op(a, m, track, ops, i + 1, i)
                        _op(a, m, track, ops, i, i + 1)
                lab[i] = k2
                lab[i + 1] = k
            i += 2
        if changed:
            idle = 0
        else:
            idle += 1
        parity ^= 1
        rounds += 1

def _is_north_west(a: BitMatrix) -> Bool:
    var n = a.n
    for i in range(n):
        for j in range(n - i, n):
            if a.get(i, j) == 1:
                return False
    return True

def kms_ops(a_in: BitMatrix) raises -> List[Int]:
    var n = a_in.n
    if n <= 1:
        return List[Int]()
    if not bm_is_invertible(a_in):
        raise Error("KMS: singular matrix")
    var m = BitMatrix(n)
    var lab = List[Int]()
    _upl(a_in, m, lab)
    var a = a_in.copy()
    var row_ops = List[Int]()
    _kms_sort(a, m, lab, 1, row_ops)
    if not _is_north_west(a):
        raise Error("KMS: not a north-west matrix")
    var lab2 = List[Int]()
    for i in range(n):
        lab2.append(n - 1 - i)
    _kms_sort(a, m, lab2, 2, row_ops)
    if not a.equals(bm_identity(n)):
        raise Error("KMS: not a Identity matrix")
    return ops_reverse(row_ops)

def kms_ops_order(a: BitMatrix, order: List[Int]) raises -> List[Int]:
    var n = a.n
    if len(order) != n:
        raise Error("kms_ops_order: len(order) != n")
    return ops_relabel(kms_ops(a.permuted(order)), order)