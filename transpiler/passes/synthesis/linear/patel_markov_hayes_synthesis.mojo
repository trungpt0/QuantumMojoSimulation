from qmath import BitMatrix, ops_two_phase

comptime PMH_MAX_SECTION = 16

def pmh_auto_section(n: Int) -> Int:
    var lg = 0
    while (1 << (lg + 1)) <= n:
        lg += 1
    var m = (lg + 1) // 2
    if m < 1: m = 1
    if m > 8: m = 8
    return m

def _pmh_lower(mut a: BitMatrix, m: Int, mut ops: List[Int]) raises:
    var n = a.n
    var nsec = (n + m - 1) // m
    for sec in range(nsec):
        var lo = sec * m
        var hi = min(lo + m, n)
        var width = hi - lo
        var first = List[Int]()
        for _ in range(1 << width):
            first.append(-1)
        for r in range(lo, n):
            var pat = a.sub_row(r, lo, width)
            if pat == 0:
                continue
            if first[pat] < 0:
                first[pat] = r
            else:
                a.xor_row(r, first[pat])
                ops.append(first[pat])
                ops.append(r)
        for c in range(lo, hi):
            var diag_one = a.get(c, c) == 1
            for r in range(c + 1, n):
                if a.get(r, c) == 1:
                    if not diag_one:
                        a.xor_row(c, r)
                        ops.append(r)
                        ops.append(c)
                        diag_one = True
                    a.xor_row(r, c)
                    ops.append(c)
                    ops.append(r)
            if not diag_one:
                raise Error("PMH: singular matrix")

def pmh_ops(a_in: BitMatrix, section: Int = 0) raises -> List[Int]:
    var n = a_in.n
    if n == 0: return List[Int]()
    var m = section
    if m <= 0: m = pmh_auto_section(n) 
    if m > n: m = n
    if m > PMH_MAX_SECTION: m = PMH_MAX_SECTION
    var a = a_in.copy()
    var ops1 = List[Int]()
    _pmh_lower(a, m, ops1)
    var at = a.transposed()
    var ops2 = List[Int]()
    _pmh_lower(at, m, ops2)
    return ops_two_phase(ops1, ops2)