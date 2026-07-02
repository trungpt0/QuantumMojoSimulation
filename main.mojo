from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler.passes.optimization import RemoveIdentityEquivalent, RemoveDiagonalGatesBeforeMeasure, InverseCancellation, CommutativeInverseCancellation, ConsolidateBlocks, Split2QUnitaries
from qmath import PI, Matrix4x4, Complex

def main() raises:
    var z = Complex(3.0, 4.0)
    var r = z.pow(1.0)
    print(r.re, r.im)