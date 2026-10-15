from gates import GateOp
from qmath import sqrt, PI
from gateop_shortcut import *

def toffoli_standard(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(H(t))
    g.append(CX(c1, t))
    g.append(Tdg(t))
    g.append(CX(c0, t))
    g.append(T(t))
    g.append(CX(c1, t))
    g.append(Tdg(t))
    g.append(CX(c0, t))
    g.append(T(c1))
    g.append(T(t))
    g.append(H(t))
    g.append(CX(c0, c1))
    g.append(T(c0))
    g.append(Tdg(c1))
    g.append(CX(c0, c1))
    return g^