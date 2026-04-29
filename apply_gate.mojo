from qmath import log2_int, Complex

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