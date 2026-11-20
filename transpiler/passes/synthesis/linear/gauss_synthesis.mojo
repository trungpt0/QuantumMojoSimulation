from qmath import BitMatrix, ops_two_phase

def _gauss_lower(mut a: BitMatrix, mut ops: List[Int]) raises:
    var n = a.n
    for c in range(n):
        if a.get(c, c) == 0:
            var p = -1
            for r in range(c + 1, n):
                if a.get(r, c) == 1:
                    p = r
                    break
            if p < 0:
                raise Error("Gauss: singular matrix")
            a.xor_row(c, p)
            ops.append(p)
            ops.append(c)
        for r in range(c + 1, n):
            if a.get(r, c) == 1:
                a.xor_row(r, c)
                ops.append(c)
                ops.append(r)

def gauss_ops(a_in: BitMatrix) raises -> List[Int]:
    var a = a_in.copy()
    var ops1 = List[Int]()
    _gauss_lower(a, ops1)
    var at = a.transposed()
    var ops2 = List[Int]()
    _gauss_lower(at, ops2)
    return ops_two_phase(ops1, ops2)