from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler.passes.optimization import RemoveIdentityEquivalent, RemoveDiagonalGatesBeforeMeasure, InverseCancellation, CommutativeInverseCancellation, ConsolidateBlocks
from qmath import PI, Matrix4x4

def main() raises:
    var qc = QuantumCircuit(3)
    qc.H(0)
    qc.X(0)
    qc.CX(0,1)
    qc.Z(0)
    qc.CX(0,2)
    qc.H(0)
    qc.CX(0,1)
    qc.RZ(0, 0.5 * PI)
    qc.Z(0)
    var dag = DAGCircuit.from_circuit(qc)
    dag.print_dag()
    var passs = ConsolidateBlocks()
    var dag1 = passs.run(dag^)
    dag1.print_dag()
    # var assd = dag.collect_2q_runs()
    # for i in range(len(assd)):
    #     print("*")
    #     for j in range(len(assd[i])):
    #         print(assd[i][j])
    # var pass1 = RemoveIdentityEquivalent()
    # var pass2 = RemoveDiagonalGatesBeforeMeasure()
    # var pass3 = InverseCancellation()
    # var pass4 = CommutativeInverseCancellation()
    # var pass5 = ConsolidateBlocks()
    # var dag1 = pass1.run(dag^)
    # var dag2 = pass2.run(dag1^)
    # var dag3 = pass3.run(dag2^)
    # var dag4 = pass4.run(dag^)
    # var dag5 = pass5.run(dag^)
    # dag4.print_dag()
    # var qc2 = dag4.to_circuit()
    # qc2.print_psi()