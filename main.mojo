from circuit import QuantumCircuit
from qmath import random_int
from sampler import Sampler
from estimator import Estimator, PauliOp

def main() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var sampler = Sampler(shots=1000)
    var sampler_res = sampler.run(qc)
    sampler_res.print_results()
    var estimator = Estimator()
    var esimator_res = estimator.run(qc, PauliOp("ZZ", -1.0))
    esimator_res.print_results()