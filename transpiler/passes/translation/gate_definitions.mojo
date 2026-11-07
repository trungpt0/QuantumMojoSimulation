from gates import GateOp
from qmath import PI
from gateop_shortcut import _T, _Tdg, _CX

def ccz_definition(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_CX(c1, t))
    g.append(_Tdg(t))
    g.append(_CX(c0, t))
    g.append(_T(t))
    g.append(_CX(c1, t))
    g.append(_Tdg(t))
    g.append(_CX(c0, t))
    g.append(_T(c1))
    g.append(_T(t))
    g.append(_CX(c0, c1))
    g.append(_T(c0))
    g.append(_Tdg(c1))
    g.append(_CX(c0, c1))
    return g^