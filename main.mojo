from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler.passes.optimization import RemoveIdentityEquivalent, RemoveDiagonalGatesBeforeMeasure, InverseCancellation, CommutativeInverseCancellation, ConsolidateBlocks, Split2QUnitaries
from qmath import PI, Matrix4x4, Complex
from gates import GateOp

def main() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0,1)
    qc.T(1)
    var dag = DAGCircuit.from_circuit(qc)
    dag.print_dag()
    var block = List[Int]()
    block.append(5)
    var listgate = List[GateOp]()
    var ql = List[Int]()
    ql.append(0)
    var ql10 = List[Int]()
    ql10.append(1)
    ql10.append(0)
    var ql1 = List[Int]()
    ql1.append(1)
    listgate.append(GateOp("X", ql))
    listgate.append(GateOp("CX", ql10))
    listgate.append(GateOp("Y", ql1))
    dag.replace_block_operations(listgate, block)
    dag.print_dag()