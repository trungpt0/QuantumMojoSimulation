from circuit import QuantumCircuit
from qmath import random_int

struct SamplerResult(Movable):
    var count: Dict[String, Int]
    var quasi_dists: Dict[String, Float64]
    var shots: Int
    var n: Int

    def __init__(out self, shots: Int, n: Int):
        self.count = Dict[String, Int]()
        self.quasi_dists = Dict[String, Float64]()
        self.shots = shots
        self.n = n
    
    def __moveinit__(out self, owned other: Self):
        self.count = other.count
        self.quasi_dists = other.quasi_dists
        self.shots = other.shots
        self.n = other.n

    def add_count(mut self, bitstring: String) raises:
        if bitstring in self.count:
            self.count[bitstring] += 1
        else:
            self.count[bitstring] = 1
    
    def compute_quasi_dists(mut self) raises:
        for key in self.count:
            var k = key
            var c = self.count[k]
            var p = Float64(c) / Float64(self.shots)
            self.quasi_dists[key] = p

    def print_results(self):
        print("SAMPLER")
        print("Shots:", self.shots)
        print("Qubits:", self.n)
        print("Counts:", self.count)
        print("Distributions:", self.quasi_dists)

struct Sampler:
    var shots: Int

    def __init__(out self, shots: Int):
        self.shots = shots

    def _get_probs(self, qc: QuantumCircuit) -> List[Float64]:
        var probs = List[Float64]()
        for amp in qc.psi:
            var p = amp.re * amp.re + amp.im * amp.im
            probs.append(p)
        return probs^

    def _sample(self, probs: List[Float64]) -> Int:
        var r = Float64(random_int(0, 1000000)) / 1000000.0
        var cdf: Float64 = 0.0
        for i in range(len(probs)):
            cdf += probs[i]
            if r < cdf:
                return i
        return len(probs) - 1

    def _index_to_bitstring(self, index: Int, n: Int) -> String:
        var bits: String = ""
        var idx = index
        for _ in range(n):
            bits = String(idx & 1) + bits
            idx >>= 1
        return bits

    def run(self, qc: QuantumCircuit) raises -> SamplerResult:
        var res = SamplerResult(self.shots, qc.n)
        var probs = self._get_probs(qc)
        for _ in range(self.shots):
            var outcome = self._sample(probs)
            var bitstring = self._index_to_bitstring(outcome, qc.n)
            res.add_count(bitstring)
        res.compute_quasi_dists()
        return res^