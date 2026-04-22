from circuit import QuantumCircuit
from qmath import Complex, inv

struct PauliOp:
    var pauli: List[String]
    var coeff: Float64

    def __init__(out self, pauli: String, coeff: Float64 = 1.0):
        self.pauli = List[String]()
        self.coeff = coeff
        var bytes = pauli.as_bytes()
        for i in range(len(bytes)):
            var b = Int(bytes[i])
            if b == 73: self.pauli.append("I")
            elif b == 88: self.pauli.append("X")
            elif b == 89: self.pauli.append("Y")
            elif b == 90: self.pauli.append("Z")
    
    def __str__(self) -> String:
        var s: String = String(self.coeff) + "*"
        for i in range(len(self.pauli)):
            s += self.pauli[i]
        return s

    def pauli_length(self) -> Int:
        return len(self.pauli)

struct EstimatorResult(Movable):
    var expectation: List[Float64]
    var observable: List[String]

    def __init__(out self):
        self.expectation = List[Float64]()
        self.observable = List[String]()

    def add(mut self, obs: String, exp_val: Float64):
        self.observable.append(obs)
        self.expectation.append(exp_val)

    def print_results(self):
        print("ESTIMATOR")
        for i in range(len(self.expectation)):
            print(self.observable[i], "->", self.expectation[i])

struct Estimator:

    def __init__(out self):
        pass

    def _apply_H(self, psi: List[Complex], w: Int, n: Int) -> List[Complex]:
        var inv = inv()
        var new_psi = psi.copy()
        var pairs = len(psi) >> 1
        for i in range(len(psi)):
            if (i >> w) & 1 == 0:
                var j = i | (1 << w)
                var a = psi[i].copy()
                var b = psi[j].copy()
                var qsum = a.add(b)
                var qdif = a.dif(b)
                new_psi[i] = qsum.mul_fnumber(inv)
                new_psi[j] = qdif.mul_fnumber(inv)
        return new_psi^

    def _apply_Sdg(self, psi: List[Complex], w: Int, n: Int) -> List[Complex]:
        var new_psi = psi.copy()
        for i in range(len(psi)):
            if (i >> w) & 1 == 1:
                new_psi[i] = Complex(psi[i].im, -psi[i].re)
        return new_psi^

    def _rotate_to_z(self, rotate_psi: List[Complex], op: PauliOp) -> List[Complex]:
        var n = op.pauli_length()
        var psi = rotate_psi.copy()
        for q in range(n):
            var p = op.pauli[q]
            if p == "X":
                psi = self._apply_H(psi, q, n)
            elif p == "Y":
                psi = self._apply_Sdg(psi, q, n)
                psi = self._apply_H(psi, q, n)
        return psi^

    def _expectation_pauli(self, rotate_psi: List[Complex], op: PauliOp) -> Float64:
        var n = op.pauli_length()
        var exp_val: Float64 = 0.0
        for i in range(len(rotate_psi)):
            var amp = rotate_psi[i].copy()
            var prob = amp.re * amp.re + amp.im * amp.im
            var sign: Float64 = 1.0
            for q in range(n):
                var p = op.pauli[q]
                if p != "I":
                    var bit = (i >> q) & 1
                    if bit == 1:
                        sign *= -1
            exp_val += prob * sign
        return op.coeff * exp_val 

    def run(self, qc: QuantumCircuit, *ops: PauliOp) -> EstimatorResult:
        var res = EstimatorResult()
        var total: Float64 = 0.0
        var label: String = ""
        for i in range(len(ops)):
            var rotated = self._rotate_to_z(qc.psi, ops[i])
            var val = self._expectation_pauli(rotated, ops[i])
            total += val
            if i > 0:
                label += " + "
            label += ops[i].__str__()
        res.add(label, total)
        return res^