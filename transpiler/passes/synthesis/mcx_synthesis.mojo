from gates import GateOp
from qmath import sqrt, PI
from gateop_shortcut import *


def toffoli_standard(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(h(t))
    g.append(cx(c0, t))
    g.append(tdg(t))