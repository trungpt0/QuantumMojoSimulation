from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler.passes.optimization import RemoveIdentityEquivalent, RemoveDiagonalGatesBeforeMeasure, InverseCancellation, CommutativeInverseCancellation, ConsolidateBlocks, Split2QUnitaries
from qmath import PI, Matrix4x4, Complex

def main() raises:
    var M = Matrix4x4()
    M.set(0,0, Complex(1, 1))
    M.set(0,1, Complex(2, -3))
    M.set(1,0, Complex(4, 5))
    M.set(1,1, Complex(-2, 1))
    var B = M.conjugate()
    B.print_matrix()