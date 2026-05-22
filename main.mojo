from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler.passes.optimization import RemoveIdentityEquivalent, RemoveDiagonalGatesBeforeMeasure, InverseCancellation
from qmath import PI

def main() raises:
    var qc = QuantumCircuit(3)
    qc.H(0)
    qc.CX(0, 1)
    qc.RZ(0, 0)
    qc.RZ(0, 2*PI)
    qc.CX(0, 2)
    qc.H(0)
    qc.I(1)
    qc.I(0)
    qc.S(0)
    qc.Tdg(1)
    qc.measure_all()
    qc.print_psi()
    var dag = DAGCircuit.from_circuit(qc)
    dag.print_dag()
    var pass1 = RemoveIdentityEquivalent()
    var pass2 = RemoveDiagonalGatesBeforeMeasure()
    var pass3 = InverseCancellation()
    var dag1 = pass1.run(dag^)
    var dag2 = pass2.run(dag1^)
    var dag3 = pass3.run(dag2^)
    dag3.print_dag()
    var qc2 = dag3.to_circuit()
    qc2.print_psi()