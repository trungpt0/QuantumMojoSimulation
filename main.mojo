from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler.passes.optimization import TParOptimization
from gates import GateOp

def main() raises:
    var qc = QuantumCircuit(4)
    qc.T(0)
    qc.CX(0,1)
    qc.CX(2,3)
    qc.T(3)
    qc.CX(2,3)
    qc.CX(1,2)
    qc.CX(1,0)
    qc.CX(3,2)
    qc.CX(1,2)
    qc.CX(0,1)
    qc.T(2)
    qc.Tdg(1)
    var dag = DAGCircuit.from_circuit(qc)
    var opt = TParOptimization()
    var dag1 = opt.run(dag^)
    # dag1.print_dag()