from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler.passes.optimization import RemoveIdentityEquivalent, RemoveDiagonalGatesBeforeMeasure, InverseCancellation, CommutativeInverseCancellation, ConsolidateBlocks, Split2QUnitaries
from qmath import PI, Matrix4x4

def main() raises:
    var qc = QuantumCircuit(2)
    qc.CX(1,0)
    var dag = DAGCircuit.from_circuit(qc)
    var pass1 = ConsolidateBlocks()
    var block = List[Int]()
    block.append(4)
    var qs = pass1._get_block_qubits(dag, block)
    print("q0 =", qs[0])
    print("q1 =", qs[1])
    var u = pass1._compute_2q_unitary(
        dag,
        block,
        qs[0],
        qs[1]
    )
    u.print_matrix()
    # var qc = QuantumCircuit(2)
    # qc.H(2)
    # qc.CX(1,0)
    # qc.Tdg(1)
    # qc.S(1)
    # qc.CX(0,1)
    # qc.H(3)
    # var dag = DAGCircuit.from_circuit(qc)
    # dag.print_dag()
    # var pass1 = ConsolidateBlocks()
    # var dag1 = pass1.run(dag^)
    # dag1.print_dag()
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