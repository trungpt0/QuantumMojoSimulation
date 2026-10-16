from qmath import log2_int, Complex, inv
from std.math import cos, sin

def create_zero_state(n: Int) -> List[Complex]:
    var N = 1 << n
    var psi = List[Complex]()
    for i in range(N):
        if i == 0:
            psi.append(Complex(1.0, 0.0))
        else:
            psi.append(Complex(0.0, 0.0))
    return psi^

def apply_single_qubit_gate(
    psi: List[Complex], 
    w: Int, 
    a: Complex, 
    b: Complex, 
    c: Complex, 
    d: Complex
    ) -> List[Complex]:

    var N = len(psi)
    var n = log2_int(N)
    var cut = 1 << (n - w - 1)
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for j in range(N):
        var bit = (j >> (n - w - 1)) & 1
        if bit == 0:
            new_psi[j] = new_psi[j].add(a.mul(psi[j]))
            new_psi[j + cut] = new_psi[j + cut].add(c.mul(psi[j]))
        else:
            new_psi[j] = new_psi[j].add(d.mul(psi[j]))
            new_psi[j - cut] = new_psi[j - cut].add(b.mul(psi[j]))
    return new_psi^

def apply_cx_gate(
    psi: List[Complex],
    w0: Int,
    w1: Int
) -> List[Complex]:
    var N = len(psi)
    var n = log2_int(N)
    var cut = 1 << (n - w1 - 1)
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for j in range(N):
        var control_bit = (j >> (n - w0 - 1)) & 1
        var target_bit = (j >> (n - w1 - 1)) & 1
        if control_bit == 1:
            if target_bit == 1:
                new_psi[j - cut] = new_psi[j - cut].add(psi[j])
            else:
                new_psi[j + cut] = new_psi[j + cut].add(psi[j])
        else:
            new_psi[j] = psi[j].copy()
    return new_psi^

def apply_cy_gate(
    psi: List[Complex],
    w0: Int,
    w1: Int
) -> List[Complex]:
    var N = len(psi)
    var n = log2_int(N)
    var pos0 = n - w0 - 1
    var pos1 = n - w1 - 1
    var cut = 1 << pos1
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for i in range(N):
        var c = (i >> pos0) & 1
        var t = (i >> pos1) & 1
        if c == 1:
            if t == 0:
                var j = i + cut
                new_psi[j] = new_psi[j].add(psi[i].mul(Complex(0.0, 1.0)))
            else:
                var j = i - cut
                new_psi[j] = new_psi[j].add(psi[i].mul(Complex(0.0, -1.0)))
        else:
            new_psi[i] = psi[i].copy()
    return new_psi^

def apply_cz_gate(
    psi: List[Complex],
    w0: Int,
    w1: Int
) -> List[Complex]:
    var N = len(psi)
    var n = log2_int(N)
    var pos0 = n - w0 - 1
    var pos1 = n - w1 - 1
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for i in range(N):
        var c = (i >> pos0) & 1
        var t = (i >> pos1) & 1
        if c == 1 and t == 1:
            new_psi[i] = psi[i].mul(Complex(-1.0, 0.0))
        else:
            new_psi[i] = psi[i].copy()
    return new_psi^

def apply_swap_gate(
    psi: List[Complex],
    w0: Int,
    w1: Int
) -> List[Complex]:
    if w0 == w1:
        return psi.copy()
    var N = len(psi)
    var n = log2_int(N)
    var pos1 = n - w0 - 1
    var pos2 = n - w1 - 1
    var mask1 = 1 << pos1
    var mask2 = 1 << pos2
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for i in range(N):
        var bit1 = (i >> pos1) & 1
        var bit2 = (i >> pos2) & 1
        if bit1 != bit2:
            var j = i ^ mask1 ^ mask2
            if i < j:
                new_psi[i] = psi[j].copy()
                new_psi[j] = psi[i].copy()
        else:
            new_psi[i] = psi[i].copy()
    return new_psi^

def apply_ecr_gate(
    psi: List[Complex],
    w0: Int,
    w1: Int
) -> List[Complex]:
    var N = len(psi)
    var n = log2_int(N)
    var pos0 = n - w0 - 1
    var pos1 = n - w1 - 1
    var mask0 = 1 << pos0
    var mask1 = 1 << pos1
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for i in range(N):
        var bit0 = (i >> pos0) & 1
        var bit1 = (i >> pos1) & 1
        if bit0 == 0 and bit1 == 0:
            var j00 = i
            var j01 = i | mask1
            var j10 = i | mask0
            var j11 = i | mask0 | mask1
            new_psi[j00] = psi[j10].add(psi[j11].mul(Complex(0.0, 1.0))).mul(Complex(inv(), 0.0))
            new_psi[j01] = psi[j10].mul(Complex(0.0, 1.0)).add(psi[j11]).mul(Complex(inv(), 0.0))
            new_psi[j10] = psi[j00].add(psi[j01].mul(Complex(0.0, -1.0))).mul(Complex(inv(), 0.0))
            new_psi[j11] = psi[j00].mul(Complex(0.0, -1.0)).add(psi[j01]).mul(Complex(inv(), 0.0))
    return new_psi^

def apply_rbs_gate(
    psi: List[Complex], 
    w0: Int, 
    w1: Int, 
    theta: Float64
) -> List[Complex]:
    """
    RBS(θ) =
    | 1   0     0   0 |
    | 0 cosθ  -sinθ  0 |
    | 0 sinθ cosθ  0 |
    | 0   0     0   1 |
    """
    var N = len(psi)
    var n = log2_int(N)
    var pos0 = n - w0 - 1
    var pos1 = n - w1 - 1
    var mask0 = 1 << pos0
    var mask1 = 1 << pos1
    var c = cos(theta)
    var s = sin(theta)
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for i in range(N):
        var bit0 = (i & mask0) != 0
        var bit1 = (i & mask1) != 0
        if bit0 == bit1:
            new_psi[i] = psi[i].copy()
        elif bit0 and not bit1:
            new_psi[i] = psi[i].mul(Complex(c, 0.0))
            var partner = i ^ mask0 ^ mask1
            new_psi[partner] = new_psi[partner].add(psi[i].mul(Complex(-s, 0.0)))
        else:
            new_psi[i] = psi[i].mul(Complex(c, 0.0))
            var partner = i ^ mask0 ^ mask1
            new_psi[partner] = new_psi[partner].add(psi[i].mul(Complex(s, 0.0)))
    return new_psi^

def apply_cp_gate(
    psi: List[Complex], 
    w0: Int, 
    w1: Int, 
    theta: Float64
) -> List[Complex]:
    if w0 == w1:
        return psi.copy()    
    var N = len(psi)
    var n = log2_int(N)
    var pos0 = n - w0 - 1
    var pos1 = n - w1 - 1
    var c = cos(theta)
    var s = sin(theta)
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for i in range(N):
        var bit0 = (1 >> pos0) & 1
        var bit1 = (1 >> pos1) & 1
        if bit0 == 1 and bit1 == 1:
            new_psi[i] = psi[i].mul(Complex(c, s))
        else:
            new_psi[i] = psi[i].copy()
    return new_psi^

def apply_crx_gate(
    psi: List[Complex],
    w0: Int,
    w1: Int,
    theta: Float64
) -> List[Complex]:
    if w0 == w1:
        return psi.copy()
    var N = len(psi)
    var n = log2_int(N)
    var pos0 = n - w0 - 1
    var pos1 = n - w1 - 1
    var c = cos(theta / 2.0)
    var s = sin(theta / 2.0)
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for i in range(N):
        var cbit = (i >> pos0) & 1
        var tbit = (i >> pos1) & 1
        if cbit == 0:
            new_psi[i] = psi[i].copy()
        elif tbit == 0:
            var j = i | (1 << pos1)
            new_psi[i] = psi[i].mul(Complex(c, 0.0)).add(psi[j].mul(Complex(0.0, -s)))
        else:
            var j = i & ~(1 << pos1)
            new_psi[i] = psi[j].mul(Complex(0.0, -s)).add(psi[i].mul(Complex(c, 0.0)))
    return new_psi^

def apply_cry_gate(
    psi: List[Complex],
    w0: Int,
    w1: Int,
    theta: Float64
) -> List[Complex]:
    if w0 == w1:
        return psi.copy()
    var N = len(psi)
    var n = log2_int(N)
    var pos0 = n - w0 - 1
    var pos1 = n - w1 - 1
    var c = cos(theta / 2.0)
    var s = sin(theta / 2.0)
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for i in range(N):
        var cbit = (i >> pos0) & 1
        var tbit = (i >> pos1) & 1
        if cbit == 0:
            new_psi[i] = psi[i].copy()
        elif tbit == 0:
            var j = i | (1 << pos1)
            new_psi[i] = psi[i].mul(Complex(c, 0.0)).add(psi[j].mul(Complex(-s, 0.0)))
        else:
            var j = i & ~(1 << pos1)
            new_psi[i] = psi[j].mul(Complex(s, 0.0)).add(psi[i].mul(Complex(c, 0.0)))
    return new_psi^

def apply_crz_gate(
    psi: List[Complex],
    w0: Int,
    w1: Int,
    theta: Float64
) -> List[Complex]:
    if w0 == w1:
        return psi.copy()
    var N = len(psi)
    var n = log2_int(N)
    var pos0 = n - w0 - 1
    var pos1 = n - w1 - 1
    var c = cos(theta / 2.0)
    var s = sin(theta / 2.0)
    var new_psi = List[Complex]()
    for i in range(N):
        var cbit = (i >> pos0) & 1
        var tbit = (i >> pos1) & 1
        if cbit == 1 and tbit == 0:
            new_psi.append(psi[i].mul(Complex(c, -s)))
        elif cbit == 1 and tbit == 1:
            new_psi.append(psi[i].mul(Complex(c, s)))
        else:
            new_psi.append(psi[i].copy())
    return new_psi^

def apply_ccx_gate(
    psi: List[Complex],
    w0: Int,
    w1: Int,
    w2: Int
) -> List[Complex]:
    if w0 == w1 or w1 == w2 or w0 == w2:
        return psi.copy()
    var N = len(psi)
    var n = log2_int(N)
    var pos0 = n - w0 - 1
    var pos1 = n - w1 - 1
    var pos2 = n - w2 - 1
    var _ = 1 << pos0
    var _ = 1 << pos1
    var mask2 = 1 << pos2
    var new_psi = List[Complex]()
    for _ in range(N):
        new_psi.append(Complex(0.0, 0.0))
    for i in range(N):
        var bit0 = (i >> pos0) & 1
        var bit1 = (i >> pos1) & 1
        if bit0 == 1 and bit1 == 1:
            var i = i ^ mask2
            new_psi[i] = psi[i].copy()
        else:
            new_psi[i] = psi[i].copy()
    return new_psi^