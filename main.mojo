from circuit import QuantumCircuit
from qmath import random_int
from primitives.sampler import Sampler
from primitives.estimator import Estimator, SparsePauliOp

def main() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    var sampler = Sampler(shots=1000)
    var sampler_res = sampler.run(qc)
    sampler_res.print_results()

    var estimator = Estimator()
    var esimator_res = estimator.run(qc, SparsePauliOp("ZZ", -1.0), SparsePauliOp("XY", 1.0))
    esimator_res.print_results()

    var H = List[SparsePauliOp]()
    H.append(SparsePauliOp("ZZ", -1.0))
    H.append(SparsePauliOp("XY", 1.0))
    var esimator_res2 = estimator.run(qc, H)
    esimator_res2.print_results()