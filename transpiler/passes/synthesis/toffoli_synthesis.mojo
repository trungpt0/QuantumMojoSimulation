from gates import GateOp
from qmath import PI
from gateop_shortcut import _H, _T, _Tdg, _CX, _RZ, _CCX
from transpiler import _apply_basis_translator

def toffoli_standard(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_H(t))
    g.append(_CX(c1, t))
    g.append(_Tdg(t))
    g.append(_CX(c0, t))
    g.append(_T(t))
    g.append(_CX(c1, t))
    g.append(_Tdg(t))
    g.append(_CX(c0, t))
    g.append(_T(c1))
    g.append(_T(t))
    g.append(_H(t))
    g.append(_CX(c0, c1))
    g.append(_T(c0))
    g.append(_Tdg(c1))
    g.append(_CX(c0, c1))
    return g^

def toffoli_relative_phase(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_H(t))
    g.append(_T(t))
    g.append(_CX(c1, t))
    g.append(_Tdg(t))
    g.append(_CX(c0, t))
    g.append(_T(t))
    g.append(_CX(c1, t))
    g.append(_Tdg(t))
    g.append(_H(t))
    return g^

def toffoli_t_depth_optimal(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_H(t))
    g.append(_T(c0))
    g.append(_T(c1))
    g.append(_T(t))
    g.append(_CX(c0, c1))
    g.append(_CX(c0, t))
    g.append(_CX(c1, c0))
    g.append(_CX(t, c0))
    g.append(_T(c0))
    g.append(_Tdg(c1))
    g.append(_Tdg(t))
    g.append(_CX(c1, t))
    g.append(_Tdg(t))
    g.append(_CX(c1, t))
    g.append(_CX(t, c0))
    g.append(_CX(c1, c0))
    g.append(_CX(c0, t))
    g.append(_CX(c0, c1))
    g.append(_H(t))
    return g^

def toffoli_rz_based(c0: Int, c1: Int, t: Int) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_H(t))
    g.append(_CX(c1, t))
    g.append(_RZ(t, -PI / 4))
    g.append(_CX(c0, t))
    g.append(_RZ(t, PI / 4))
    g.append(_CX(c1, t))
    g.append(_RZ(t, -PI / 4))
    g.append(_CX(c0, t))
    g.append(_RZ(c1, PI / 4))
    g.append(_RZ(t, PI / 4))
    g.append(_H(t))
    g.append(_CX(c0, c1))
    g.append(_RZ(c0, PI / 4))
    g.append(_RZ(c1, -PI / 4))
    g.append(_CX(c0, c1))
    return g^

def toffoli_gates(
    c0: Int,
    c1: Int,
    t: Int,
    method: String,
    ancilla: List[Int] = List[Int]()
) raises -> List[GateOp]:
    if method == "ccx":
        var g = List[GateOp]()
        g.append(_CCX(c0, c1, t))
        return g^
    if method == "standard" or method == "noancilla":
        return toffoli_standard(c0, c1, t)
    if method == "relative_phase" or method == "rccx":
        return toffoli_relative_phase(c0, c1, t)
    if method == "t_depth":
        return toffoli_t_depth_optimal(c0, c1, t)
    raise Error("Invalid method: " + method)

def toffoli_synthesize(
    c0: Int, 
    c1: Int, 
    t: Int, target: Target, 
    method: String = "standard",
    ancilla: List[Int] = List[Int]()
) raises -> List[GateOp]:
    return _apply_basis_translator(toffoli_gates(c0, c1, t, method, ancilla), target)