from gates import GateOp
from qmath import PI, PI4
from dagcircuit import DAGCircuit
from gateop_shortcut import _Z, _H, _T, _Tdg, _S, _Sdg, _P, _RX, _RY, _RZ, _SX, _CX, _CCX, _CCZ
from transpiler import Target, toffoli_standard, ccz_definition, toffoli_relative_phase

comptime R_CCX_STD = 0
comptime R_CCX_CCZ = 1
comptime R_CCZ_STD = 2
comptime R_RCCX    = 3
comptime R_CSWAP   = 4
comptime R_H       = 5
comptime R_SX      = 6
comptime R_X_SX    = 7
comptime R_X_RX    = 8
comptime R_Y       = 9
comptime R_T_RZ    = 10
comptime R_TDG_RZ  = 11
comptime R_S_RZ    = 12
comptime R_SDG_RZ  = 13
comptime R_Z_RZ    = 14
comptime R_S_TT    = 15
comptime R_SDG_TT  = 16
comptime R_Z_SS    = 17
comptime R_P_RZ    = 18
comptime R_RZ_P    = 19
comptime R_U_SX    = 20
comptime R_U_RY    = 21
comptime R_U1      = 22
comptime R_RX_H    = 23
comptime R_RX_SX   = 24
comptime R_RY_RX   = 25
comptime R_RY_SX   = 26
comptime R_SWAP    = 27
comptime R_CZ      = 28
comptime R_CY      = 29
comptime R_CP      = 30
comptime R_CRZ     = 31
comptime R_CRY     = 32
comptime R_CRX     = 33
comptime R_RZZ     = 34

def _expand(rid: Int, g: GateOp) raises -> List[GateOp]:
    var o = List[GateOp]()
    var q0 = g.qubit[0]
    if rid == R_CCX_STD:
        return toffoli_standard(q0, g.qubit[1], g.qubit[2])
    elif rid == R_CCX_CCZ:
        o.append(_H(g.qubit[2]))
        o.append(_CCZ(q0, g.qubit[1], g.qubit[2]))
        o.append(_H(g.qubit[2]))
    elif rid == R_CCZ_STD:
        return ccz_definition(q0, g.qubit[1], g.qubit[2])
    elif rid == R_RCCX:
        return toffoli_relative_phase(q0, g.qubit[1], g.qubit[2])
    elif rid == R_CSWAP:
        var a = g.qubit[1]
        var b = g.qubit[2]
        o.append(_CX(b, a))
        o.append(_CCX(q0, a, b))
        o.append(_CX(b, a))
    elif rid == R_H:
        o.append(_RZ(q0, PI / 2)); o.append(_SX(q0)); o.append(_RZ(q0, PI / 2))
    elif rid == R_SX:
        o.append(_Sdg(q0)); o.append(_H(q0)); o.append(_Sdg(q0))
    elif rid == R_X_SX:
        o.append(_SX(q0)); o.append(_SX(q0))
    elif rid == R_X_RX:
        o.append(_RX(q0, PI))
    elif rid == R_Y:
        o.append(_RZ(q0, PI)); o.append(_SX(q0)); o.append(_SX(q0))
    elif rid == R_T_RZ:
        o.append(_RZ(q0, PI4))
    elif rid == R_TDG_RZ:
        o.append(_RZ(q0, -PI4))
    elif rid == R_S_RZ:
        o.append(_RZ(q0, PI / 2))
    elif rid == R_SDG_RZ:
        o.append(_RZ(q0, -PI / 2))
    elif rid == R_Z_RZ:
        o.append(_RZ(q0, PI))
    elif rid == R_S_TT:
        o.append(_T(q0)); o.append(_T(q0))
    elif rid == R_SDG_TT:
        o.append(_Tdg(q0)); o.append(_Tdg(q0))
    elif rid == R_Z_SS:
        o.append(_S(q0)); o.append(_S(q0))
    elif rid == R_P_RZ or rid == R_U1:
        o.append(_RZ(q0, g.theta[0]))
    elif rid == R_RZ_P:
        o.append(_P(q0, g.theta[0]))
    elif rid == R_U_SX:
        o.append(_RZ(q0, g.theta[2])); o.append(_SX(q0))
        o.append(_RZ(q0, g.theta[0] + PI)); o.append(_SX(q0))
        o.append(_RZ(q0, g.theta[1] + PI))
    elif rid == R_U_RY:
        o.append(_RZ(q0, g.theta[2])); o.append(_RY(q0, g.theta[0])); o.append(_RZ(q0, g.theta[1]))
    elif rid == R_RX_H:
        o.append(_H(q0)); o.append(_RZ(q0, g.theta[0])); o.append(_H(q0))
    elif rid == R_RX_SX:
        o.append(_RZ(q0, PI / 2)); o.append(_SX(q0))
        o.append(_RZ(q0, g.theta[0] + PI)); o.append(_SX(q0))
        o.append(_RZ(q0, PI / 2))
    elif rid == R_RY_RX:
        o.append(_RZ(q0, -PI / 2)); o.append(_RX(q0, g.theta[0])); o.append(_RZ(q0, PI / 2))
    elif rid == R_RY_SX:
        o.append(_SX(q0)); o.append(_RZ(q0, g.theta[0] + PI))
        o.append(_SX(q0)); o.append(_RZ(q0, PI))
    elif rid == R_SWAP:
        var b = g.qubit[1]
        o.append(_CX(q0, b)); o.append(_CX(b, q0)); o.append(_CX(q0, b))
    elif rid == R_CZ:
        var t = g.qubit[1]
        o.append(_H(t)); o.append(_CX(q0, t)); o.append(_H(t))
    elif rid == R_CY:
        var t = g.qubit[1]
        o.append(_Sdg(t)); o.append(_CX(q0, t)); o.append(_S(t))
    elif rid == R_CP:
        var t = g.qubit[1]
        var l = g.theta[0]
        o.append(_P(q0, l / 2)); o.append(_CX(q0, t)); o.append(_P(t, -l / 2))
        o.append(_CX(q0, t)); o.append(_P(t, l / 2))
    elif rid == R_CRZ:
        var t = g.qubit[1]
        var a = g.theta[0]
        o.append(_RZ(t, a / 2)); o.append(_CX(q0, t))
        o.append(_RZ(t, -a / 2)); o.append(_CX(q0, t))
    elif rid == R_CRY:
        var t = g.qubit[1]
        var a = g.theta[0]
        o.append(_RY(t, a / 2)); o.append(_CX(q0, t))
        o.append(_RY(t, -a / 2)); o.append(_CX(q0, t))
    elif rid == R_CRX:
        var t = g.qubit[1]
        var a = g.theta[0]
        o.append(_RZ(t, PI / 2))
        o.append(_RY(t, a / 2)); o.append(_CX(q0, t))
        o.append(_RY(t, -a / 2)); o.append(_CX(q0, t))
        o.append(_RZ(t, -PI / 2))
    elif rid == R_RZZ:
        var b = g.qubit[1]
        o.append(_CX(q0, b)); o.append(_RZ(b, g.theta[0])); o.append(_CX(q0, b))
    else:
        raise Error("Invalid rule ID: " + String(rid))
    return o^

struct Rule(Copyable, Movable):
    var src: String
    var rid: Int
    var outs: List[String]

    def __init__(out self, src: String, rid: Int, outs: List[String]):
        self.src = src
        self.rid = rid
        self.outs = outs.copy()

def _dummy(name: String, arity: Int) -> GateOp:
    var qs = List[Int]()
    for i in range(arity):
        qs.append(i)
    var th = List[Float64]()
    th.append(0.3); th.append(0.3); th.append(0.3)
    return GateOp(name, qs, th)

struct EquivalenceLibrary(Copyable, Movable):
    var rules: List[Rule]

    def __init__(out self):
        self.rules = List[Rule]()

    def add(mut self, src: String, arity: Int, rid: Int) raises:
        var sub = _expand(rid, _dummy(src, arity))
        var outs = List[String]()
        for i in range(len(sub)):
            outs.append(sub[i].name)
        self.rules.append(Rule(src, rid, outs))

def default_equivalence_library() raises -> EquivalenceLibrary:
    var lib = EquivalenceLibrary()
    lib.add("CCX", 3, R_CCX_STD);  lib.add("CCX", 3, R_CCX_CCZ)
    lib.add("CCZ", 3, R_CCZ_STD);  lib.add("RCCX", 3, R_RCCX)
    lib.add("CSWAP", 3, R_CSWAP)
    lib.add("H", 1, R_H);    lib.add("SX", 1, R_SX)
    lib.add("X", 1, R_X_SX); lib.add("X", 1, R_X_RX)
    lib.add("Y", 1, R_Y)
    lib.add("T", 1, R_T_RZ);   lib.add("TDG", 1, R_TDG_RZ)
    lib.add("S", 1, R_S_RZ);   lib.add("SDG", 1, R_SDG_RZ)
    lib.add("Z", 1, R_Z_RZ)
    lib.add("S", 1, R_S_TT);   lib.add("SDG", 1, R_SDG_TT); lib.add("Z", 1, R_Z_SS)
    lib.add("P", 1, R_P_RZ);   lib.add("RZ", 1, R_RZ_P)
    lib.add("U", 1, R_U_SX);   lib.add("U", 1, R_U_RY)
    lib.add("U3", 1, R_U_SX);  lib.add("U3", 1, R_U_RY)
    lib.add("U1", 1, R_U1)
    lib.add("RX", 1, R_RX_H);  lib.add("RX", 1, R_RX_SX)
    lib.add("RY", 1, R_RY_RX); lib.add("RY", 1, R_RY_SX)
    lib.add("SWAP", 2, R_SWAP)
    lib.add("CZ", 2, R_CZ);    lib.add("CY", 2, R_CY)
    lib.add("CP", 2, R_CP)
    lib.add("CRZ", 2, R_CRZ);  lib.add("CRY", 2, R_CRY); lib.add("CRX", 2, R_CRX)
    lib.add("RZZ", 2, R_RZZ)
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
                choice[r.src] = r.rid
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
        out.append(_S(q)); out.append(_T(q))
    elif m == 4:
        out.append(_Z(q))
    elif m == 5:
        out.append(_Z(q)); out.append(_T(q))
    elif m == 6:
        out.append(_Sdg(q))
    elif m == 7:
        out.append(_Tdg(q))
    return True

def _passthrough(name: String) -> Bool:
    return (name == "MEASURE" or name == "BARRIER" or name == "RESET"
            or name == "INPUT" or name == "OUTPUT")

struct BasisTranslator(Copyable, Movable):
    var target: Target
    var choice: Dict[String, Int]
    var in_basis: Dict[String, Bool]

    def __init__(out self, target: Target) raises:
        self.target = target.copy()
        self.choice = build_plan(default_equivalence_library(), target)
        self.in_basis = Dict[String, Bool]()
        for i in range(len(target.basis_gates)):
            self.in_basis[target.basis_gates[i]] = True

    def _emit(self, mut out: List[GateOp], g: GateOp) raises:
        if g.name in self.in_basis or _passthrough(g.name):
            out.append(g.copy())
            return
        if g.name in self.choice:
            var sub = _expand(self.choice[g.name], g)
            for i in range(len(sub)):
                self._emit(out, sub[i])
            return
        if (g.name == "P" or g.name == "RZ") and len(g.theta) > 0:
            var sub = List[GateOp]()
            if _clifford_phase(sub, g.qubit[0], g.theta[0]):
                for i in range(len(sub)):
                    self._emit(out, sub[i])
                return
            raise Error("Angle " + String(g.theta[0]) + " cannot be represented exactly in the basis")
        raise Error("Cannot decompose gate " + g.name + " into the basis")

    def translate(self, gates: List[GateOp]) raises -> List[GateOp]:
        var out = List[GateOp]()
        out.reserve(len(gates))
        for i in range(len(gates)):
            self._emit(out, gates[i])
        return out^

    def run(self, dag: DAGCircuit) raises -> DAGCircuit:
        var dagc = dag.copy()
        var topo = dagc.topological_sort()
        var targets = List[Int]()
        for i in range(len(topo)):
            var nid = topo[i]
            if dagc.nodes[nid].type != "gate":
                continue
            var nm = dagc.nodes[nid].gate.name
            if nm in self.in_basis or _passthrough(nm):
                continue
            targets.append(nid)
        for ti in range(len(targets)):
            var nid = targets[ti]
            var one = List[GateOp]()
            one.append(dagc.nodes[nid].gate.copy())
            var new_gates = self.translate(one)
            var block = List[Int]()
            block.append(nid)
            dagc.replace_block_operations(new_gates, block)
        dagc.finalize_operation()
        return dagc^

def _apply_basis_translator(gates: List[GateOp], target: Target) raises -> List[GateOp]:
    return BasisTranslator(target).translate(gates)