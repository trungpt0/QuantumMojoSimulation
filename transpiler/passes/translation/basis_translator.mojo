from gates import GateOp
from qmath import PI, PI4
from gateop_shortcut import _Z, _H, _T, _Tdg, _S, _Sdg, _P, _RZ, _SX, _CX, _CCX, _CCZ
from transpiler import Target
from transpiler import toffoli_standard, ccz_definition, toffoli_relative_phase

comptime R_CCX_STD = 0      # CCX   -> toffoli_standard
comptime R_CCX_CCZ = 1      # CCX   -> H . CCZ . H
comptime R_CCZ_STD = 2      # CCZ   -> ccz_definition
comptime R_RCCX    = 3      # RCCX  -> toffoli_relative_phase
comptime R_H       = 4      # H     -> RZ(pi/2) . SX . RZ(pi/2)
comptime R_SX      = 5      # SX    -> SDG . H . SDG
comptime R_X       = 6      # X     -> SX . SX
comptime R_T_RZ    = 7      # T     -> RZ(pi/4)
comptime R_TDG_RZ  = 8      # TDG   -> RZ(-pi/4)
comptime R_S_RZ    = 9      # S     -> RZ(pi/2)
comptime R_SDG_RZ  = 10     # SDG   -> RZ(-pi/2)
comptime R_Z_RZ    = 11     # Z     -> RZ(pi)
comptime R_S_TT    = 12     # S     -> T . T
comptime R_SDG_TT  = 13     # SDG   -> TDG . TDG
comptime R_Z_SS    = 14     # Z     -> S . S
comptime R_P_RZ    = 15     # P(a)  -> RZ(a)
comptime R_RZ_P    = 16     # RZ(a) -> P(a)

def _expand(rid: Int, g: GateOp) raises -> List[GateOp]:
    var out = List[GateOp]()
    var q0 = g.qubit[0]
    if rid == R_CCX_STD:
        return toffoli_standard(g.qubit[0], g.qubit[1], g.qubit[2])
    elif rid == R_CCX_CCZ:
        out.append(_H(g.qubit[2]))
        out.append(_CCZ(g.qubit[0], g.qubit[1], g.qubit[2]))
        out.append(_H(g.qubit[2]))
    elif rid == R_CCZ_STD:
        return ccz_definition(g.qubit[0], g.qubit[1], g.qubit[2])
    elif rid == R_RCCX:
        return toffoli_relative_phase(g.qubit[0], g.qubit[1], g.qubit[2])
    elif rid == R_H:
        out.append(_RZ(q0, PI / 2))
        out.append(_SX(q0))
        out.append(_RZ(q0, PI / 2))
    elif rid == R_SX:
        out.append(_Sdg(q0))
        out.append(_H(q0))
        out.append(_Sdg(q0))
    elif rid == R_X:
        out.append(_SX(q0))
        out.append(_SX(q0))
    elif rid == R_T_RZ:
        out.append(_RZ(q0, PI4))
    elif rid == R_TDG_RZ:
        out.append(_RZ(q0, -PI4))
    elif rid == R_S_RZ:
        out.append(_RZ(q0, PI / 2))
    elif rid == R_SDG_RZ:
        out.append(_RZ(q0, -PI / 2))
    elif rid == R_Z_RZ:
        out.append(_RZ(q0, PI))
    elif rid == R_S_TT:
        out.append(_T(q0))
        out.append(_T(q0))
    elif rid == R_SDG_TT:
        out.append(_Tdg(q0))
        out.append(_Tdg(q0))
    elif rid == R_Z_SS:
        out.append(_S(q0))
        out.append(_S(q0))
    elif rid == R_P_RZ:
        out.append(_RZ(q0, g.theta[0]))
    elif rid == R_RZ_P:
        out.append(_P(q0, g.theta[0]))
    else:
        raise Error("Invalid rule ID: " + String(rid))
    return out^

struct Rule(Copyable, Movable):
    var src: String
    var outs: List[String]

    def __init__(out self, src: String, outs: List[String]):
        self.src = src
        self.outs = outs.copy()

def _dummy(name: String, arity: Int) -> GateOp:
    if arity == 3:
        return _CCX(0, 1, 2)
    if arity == 2:
        return _CX(0, 1)
    return _RZ(0, 0.3)

struct EquivalenceLibrary(Copyable, Movable):
    var rules: List[Rule]

    def __init__(out self):
        self.rules = List[Rule]()

    def add(mut self, src: String, arity: Int) raises:
        var sub = _expand(len(self.rules), _dummy(src, arity))
        var outs = List[String]()
        for i in range(len(sub)):
            outs.append(sub[i].name)
        self.rules.append(Rule(src, outs))

def default_equivalence_library() raises -> EquivalenceLibrary:
    var lib = EquivalenceLibrary()
    lib.add("CCX", 3)    # R_CCX_STD
    lib.add("CCX", 3)    # R_CCX_CCZ
    lib.add("CCZ", 3)    # R_CCZ_STD
    lib.add("RCCX", 3)   # R_RCCX
    lib.add("H", 1)      # R_H
    lib.add("SX", 1)     # R_SX
    lib.add("X", 1)      # R_X
    lib.add("T", 1)      # R_T_RZ
    lib.add("TDG", 1)    # R_TDG_RZ
    lib.add("S", 1)      # R_S_RZ
    lib.add("SDG", 1)    # R_SDG_RZ
    lib.add("Z", 1)      # R_Z_RZ
    lib.add("S", 1)      # R_S_TT
    lib.add("SDG", 1)    # R_SDG_TT
    lib.add("Z", 1)      # R_Z_SS
    lib.add("P", 1)      # R_P_RZ
    lib.add("RZ", 1)     # R_RZ_P
    return lib^

def build_plan(lib: EquivalenceLibrary, target: Target) raises -> Dict[String, Int]:
    var cost = Dict[String, Int]()
    for i in range(len(target.basis_gates)):
        cost[target.basis_gates[i]] = 1
    var choice = Dict[String, Int]()
    var changed = True
    while changed:
        changed = False
        for ri in range(len(lib.rules)):
            var r = lib.rules[ri].copy()
            if target.supports_gate(r.src):
                continue
            var total = 1
            var ok = True
            for oi in range(len(r.outs)):
                if r.outs[oi] not in cost:
                    ok = False
                    break
                total += cost[r.outs[oi]]
            if not ok:
                continue
            if r.src not in cost or total < cost[r.src]:
                cost[r.src] = total
                choice[r.src] = ri
                changed = True
    return choice^

def _clifford_phase(mut out: List[GateOp], q: Int, theta: Float64) -> Bool:
    var kf = theta / PI4
    var k = Int(round(kf))
    if abs(kf - Float64(k)) > 1e-9:
        return False
    var m = ((k % 8) + 8) % 8
    if m == 1:
        out.append(_T(q))
    elif m == 2:
        out.append(_S(q))
    elif m == 3:
        out.append(_S(q))
        out.append(_T(q))
    elif m == 4:
        out.append(_Z(q))
    elif m == 5:
        out.append(_Z(q))
        out.append(_T(q))
    elif m == 6:
        out.append(_Sdg(q))
    elif m == 7:
        out.append(_Tdg(q))
    return True

def _translate_gate(mut out: List[GateOp], g: GateOp, target: Target, choice: Dict[String, Int]) raises:
    if target.supports_gate(g.name):
        out.append(g.copy())
        return
    if g.name in choice:
        var sub = _expand(choice[g.name], g)
        for i in range(len(sub)):
            _translate_gate(out, sub[i], target, choice)
        return
    if (g.name == "P" or g.name == "RZ") and len(g.theta) > 0:
        var sub = List[GateOp]()
        if _clifford_phase(sub, g.qubit[0], g.theta[0]):
            for i in range(len(sub)):
                _translate_gate(out, sub[i], target, choice)
            return
        raise Error("Angle " + String(g.theta[0]) + " cannot be represented exactly in the basis")
    raise Error("Cannot decompose gate " + g.name + " into the basis")

def basis_translate(gates: List[GateOp], target: Target, lib: EquivalenceLibrary) raises -> List[GateOp]:
    var choice = build_plan(lib, target)
    var out = List[GateOp]()
    for i in range(len(gates)):
        _translate_gate(out, gates[i], target, choice)
    return out^

def basis_translate(gates: List[GateOp], target: Target) raises -> List[GateOp]:
    return basis_translate(gates, target, default_equivalence_library())