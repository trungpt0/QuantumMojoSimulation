from qmath import Complex, random_int, abs2
from circuit import QuantumCircuit

def approx_equal(a: Float64, b: Float64, eps: Float64 = 1e-9) -> Bool:
    return (a - b) < eps and (b - a) < eps

def complex_equal(a: Complex, b: Complex, eps: Float64 = 1e-9) -> Bool:
    return approx_equal(a.re, b.re) and approx_equal(a.im, b.im)

def assert_equal(
    psi: List[Complex],
    psi_expected: List[Complex],
    gate_name: String
):
    var all_passed = True

    if len(psi) != len(psi_expected):
        print("FAIL:", gate_name, "(size mismatch)")
        print("Got size:", len(psi))
        print("Expected size:", len(psi_expected))
    
    for i in range(len(psi)):
        if not complex_equal(psi[i], psi_expected[i]):
            print("FAIL:", gate_name, "(element mismatch at index", i, "of psi)")
            print("Index:", i)
            print("Got:", psi[i].re, "+", psi[i].im, "i")
            print("Expected:", psi_expected[i].re, "+", psi_expected[i].im, "i")
            all_passed = False
            break
    
    if all_passed:
        print("PASS:", gate_name)

