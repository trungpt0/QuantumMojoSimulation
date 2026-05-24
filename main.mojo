from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler.passes.optimization import RemoveIdentityEquivalent, RemoveDiagonalGatesBeforeMeasure, InverseCancellation, CommutativeInverseCancellation
from qmath import PI

def main() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0,1)
    qc.H(1)
    qc.RZ(0, 0.5 * PI)
    qc.Z(0)
    qc.H(0)
    qc.H(0)
    qc.H(1)
    qc.print_psi()
    var dag = DAGCircuit.from_circuit(qc)
    dag.print_dag()
    # var pass1 = RemoveIdentityEquivalent()
    # var pass2 = RemoveDiagonalGatesBeforeMeasure()
    # var pass3 = InverseCancellation()
    var pass4 = CommutativeInverseCancellation()
    # var dag1 = pass1.run(dag^)
    # var dag2 = pass2.run(dag1^)
    # var dag3 = pass3.run(dag2^)
    var dag4 = pass4.run(dag^)
    dag4.print_dag()
    var qc2 = dag4.to_circuit()
    qc2.print_psi()