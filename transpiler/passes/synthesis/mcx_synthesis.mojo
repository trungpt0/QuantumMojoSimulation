from gates import GateOp
from qmath import sqrt, PI, PI4
from gateop_shortcut import *

def toffoli_standard(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    """
    {H, CX, T/TDG, CX}
    """
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

def toffoli_rz_based(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    """
    {H, CX, RZ}
    """
    var g = List[GateOp]()
    g.append(H(t))
    g.append(CX(c1, t))
    g.append(RZ(t, -PI4))
    g.append(CX(c0, t))
    g.append(RZ(t, PI4))
    g.append(CX(c1, t))
    g.append(RZ(t, -PI4))
    g.append(CX(c0, t))
    g.append(RZ(c1, PI4))
    g.append(RZ(t, PI4))
    g.append(H(t))
    g.append(CX(c0, c1))
    g.append(RZ(c0, PI4))
    g.append(RZ(c1, -PI4))
    g.append(CX(c0, c1))
    return g^

def toffoli_relative_phase1(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    """
    {H, T/TDG, CX}
    """
    var g = List[GateOp]()
    g.append(H(t))
    g.append(T(t))
    g.append(CX(c1, t))
    g.append(Tdg(t))
    g.append(CX(c0, t))
    g.append(T(t))
    g.append(CX(c1, t))
    g.append(Tdg(t))
    g.append(H(t))
    return g^

def toffoli_relative_phase2(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    """
    {H, RZ, CX}
    """
    var g = List[GateOp]()
    g.append(H(t))
    g.append(RZ(t, PI4))
    g.append(CX(c1, t))
    g.append(RZ(t, -PI4))
    g.append(CX(c0, t))
    g.append(RZ(t, PI4))
    g.append(CX(c1, t))
    g.append(RZ(t, -PI4))
    g.append(H(t))
    return g^

def toffoli_t_depth_optimal(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    """
    {H, CX, T/TDG}
    """
    var g = List[GateOp]()
    g.append(H(t))
    g.append(CX(c1, t))
    g.append(CX(c0, c1))
    g.append(CX(c0, t))
    g.append(T(c0))
    g.append(Tdg(c1))
    g.append(Tdg(t))
    g.append(T(c1))
    g.append(CX(c0, c1))
    g.append(CX(c1, t))
    g.append(T(t))
    g.append(Tdg(t))
    g.append(CX(c0, t))
    g.append(H(t))
    return g^
