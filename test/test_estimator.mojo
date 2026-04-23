from circuit import QuantumCircuit
from estimator import Estimator, SparsePauliOp
from qutils import evaluate_estimator

def test_single_z() raises:
    var qc = QuantumCircuit(1)
    var estimator = Estimator().run(qc, SparsePauliOp("Z", 1.0))
    evaluate_estimator("Observable Z |0⟩", estimator.expectation[0], 1.0)

def test_single_z_excited() raises:
    var qc = QuantumCircuit(1)
    qc.X(0)
    var estimator = Estimator().run(qc, SparsePauliOp("Z", 1.0))
    evaluate_estimator("Observable Z |1⟩", estimator.expectation[0], -1.0)

def test_single_x() raises:
    var qc = QuantumCircuit(1)
    qc.H(0)
    var estimator = Estimator().run(qc, SparsePauliOp("X", 1.0))
    evaluate_estimator("Observable X |+⟩", estimator.expectation[0], 1.0)

def test_single_x_excited() raises:
    var qc = QuantumCircuit(1)
    qc.X(0)
    qc.H(0)
    var estimator = Estimator().run(qc, SparsePauliOp("X", 1.0))
    evaluate_estimator("Observable X |-⟩", estimator.expectation[0], -1.0)

def test_single_y() raises:
    var qc = QuantumCircuit(1)
    qc.H(0)
    qc.S(0)
    var estimator = Estimator().run(qc, SparsePauliOp("Y", 1.0))
    evaluate_estimator("Observable Y |+i⟩", estimator.expectation[0], 1.0)

def test_single_y_excited() raises:
    var qc = QuantumCircuit(1)
    qc.H(0)
    qc.Sdg(0)
    var estimator = Estimator().run(qc, SparsePauliOp("Y", 1.0))
    evaluate_estimator("Observable Y |-i⟩", estimator.expectation[0], -1.0)

def test_single_i() raises:
    var qc = QuantumCircuit(1)
    qc.H(0)
    var estimator = Estimator().run(qc, SparsePauliOp("I", 1.0))
    evaluate_estimator("Observable I |+⟩", estimator.expectation[0], 1.0)

def test_single_coeff() raises:
    var qc = QuantumCircuit(1)
    var estimator = Estimator().run(qc, SparsePauliOp("Z", 2.0))
    evaluate_estimator("Observable 2Z |0⟩", estimator.expectation[0], 2.0)

def test_bell_zz() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var estimator = Estimator().run(qc, SparsePauliOp("ZZ", 1.0))
    evaluate_estimator("Observable ZZ |Bell⟩", estimator.expectation[0], 1.0)

def test_bell_xx() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var estimator = Estimator().run(qc, SparsePauliOp("XX", 1.0))
    evaluate_estimator("Observable XX |Bell⟩", estimator.expectation[0], 1.0)

def test_bell_yy() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var estimator = Estimator().run(qc, SparsePauliOp("YY", 1.0))
    evaluate_estimator("Observable YY |Bell⟩", estimator.expectation[0], -1.0)

def test_bell_xy() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var estimator = Estimator().run(qc, SparsePauliOp("XY", 1.0))
    evaluate_estimator("Observable XY |Bell⟩", estimator.expectation[0], 0.0)

def test_bell_yx() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var estimator = Estimator().run(qc, SparsePauliOp("YX", 1.0))
    evaluate_estimator("Observable YX |Bell⟩", estimator.expectation[0], 0.0)

def test_bell_zi() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var estimator = Estimator().run(qc, SparsePauliOp("ZI", 1.0))
    evaluate_estimator("Observable ZI |Bell⟩", estimator.expectation[0], 0.0)

def test_bell_iz() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var estimator = Estimator().run(qc, SparsePauliOp("IZ", 1.0))
    evaluate_estimator("Observable IZ |Bell⟩", estimator.expectation[0], 0.0)

def test_bell_ii() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var estimator = Estimator().run(qc, SparsePauliOp("II", 1.0))
    evaluate_estimator("Observable II |Bell⟩", estimator.expectation[0], 1.0)

def test_bell_zz_coeff() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var estimator = Estimator().run(qc, SparsePauliOp("ZZ", -3.0))
    evaluate_estimator("Observable -3.0*ZZ |Bell⟩", estimator.expectation[0], -3.0)

def test_hamiltonian_zz_xy() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var H = List[SparsePauliOp]()
    H.append(SparsePauliOp("ZZ", -1.0))
    H.append(SparsePauliOp("XY", 1.0))
    var estimator = Estimator().run(qc, H)
    evaluate_estimator("Observable -1.0*ZZ + 1.0*XY", estimator.expectation[0], -1.0)

def test_hamiltonian_heisenberg() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var H = List[SparsePauliOp]()
    H.append(SparsePauliOp("XX", 0.5))
    H.append(SparsePauliOp("YY", 0.5))
    H.append(SparsePauliOp("ZZ", 0.5))
    var estimator = Estimator().run(qc, H)
    evaluate_estimator("Observable 0.5*XX + 0.5*YY + 0.5*ZZ", estimator.expectation[0], 0.5)

def test_hamiltonian_ising() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var H = List[SparsePauliOp]()
    H.append(SparsePauliOp("ZZ", -1.0))
    H.append(SparsePauliOp("XI", 0.5))
    H.append(SparsePauliOp("IX", 0.5))
    var estimator = Estimator().run(qc, H)
    evaluate_estimator("Observable -1.0*ZZ + 0.5*XI + 0.5*IX", estimator.expectation[0], -1.0)

def test_hamiltonian_all_zero() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var H = List[SparsePauliOp]()
    H.append(SparsePauliOp("ZI", 1.0))
    H.append(SparsePauliOp("IZ", 1.0))
    var estimator = Estimator().run(qc, H)
    evaluate_estimator("Observable 1.0*ZI + 1.0*IZ", estimator.expectation[0], 0.0)

def test_hamiltonian_cancel() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var H = List[SparsePauliOp]()
    H.append(SparsePauliOp("ZZ", 1.0))
    H.append(SparsePauliOp("ZZ", -1.0))
    var estimator = Estimator().run(qc, H)
    evaluate_estimator("Observable 1.0*ZZ + -1.0*ZZ", estimator.expectation[0], 0.0)

def main() raises:
    print("ESTIMATOR TEST")
    print("-----------------------------------------")
    print("Single qubit")
    print("-----------------------------------------")
    test_single_z()
    test_single_z_excited()
    test_single_x()
    test_single_x_excited()
    test_single_y()
    test_single_y_excited()
    test_single_i()
    test_single_coeff()
    print("-----------------------------------------")
    print("Two qubits - Bell state")
    print("-----------------------------------------")
    test_bell_zz()
    test_bell_xx()
    test_bell_yy()
    test_bell_xy()
    test_bell_yx()
    test_bell_zi()
    test_bell_iz()
    test_bell_ii()
    test_bell_zz_coeff()
    print("-----------------------------------------")
    print("Hamiltonian")
    print("-----------------------------------------")
    test_hamiltonian_zz_xy()
    test_hamiltonian_heisenberg()
    test_hamiltonian_ising()
    test_hamiltonian_all_zero()
    test_hamiltonian_cancel()