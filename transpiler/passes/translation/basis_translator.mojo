from gates import GateOp
from transpiler import Target
from qmath import PI
from dagcircuit import DAGCircuit
from gateop_shortcut import _H, _S, _Sdg, _P, _RX, _RY, _RZ, _SX, _CX

def _build_h_rz_sx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], PI / 2))
    g.append(_SX(qubits[0]))
    g.append(_RZ(qubits[0], PI / 2))
    return g^

def _build_h_rz_ry(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], PI / 2))
    g.append(_RY(qubits[0], PI / 2))
    g.append(_RZ(qubits[0], -PI / 2))
    return g^

def _build_s_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], PI / 2))
    return g^

def _build_sdg_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], -PI / 2))
    return g^

def _build_t_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], PI / 4))
    return g^

def _build_tdg_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], -PI / 4))
    return g^

def _build_z_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], PI))
    return g^

def _build_x_rz_sx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_SX(qubits[0]))
    g.append(_SX(qubits[0]))
    return g^

def _build_x_rx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RX(qubits[0], PI))
    return g^

def _build_y_rz_sx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], PI))
    g.append(_SX(qubits[0]))
    g.append(_SX(qubits[0]))
    return g^

def _build_sx_h_s(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_H(qubits[0]))
    g.append(_S(qubits[0]))
    g.append(_H(qubits[0]))
    return g^

def _build_p_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], params[0]))
    return g^

def _build_u3_rz_sx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], params[2]))
    g.append(_SX(qubits[0]))
    g.append(_RZ(qubits[0], params[0] + PI))
    g.append(_SX(qubits[0]))
    g.append(_RZ(qubits[0], params[1] + PI))
    return g^

def _build_u3_rz_ry(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], params[2]))
    g.append(_RY(qubits[0], params[0]))
    g.append(_RZ(qubits[0], params[1]))
    return g^

def _build_u1_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[0], params[0]))
    return g^

def _build_swap_cx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_CX(qubits[1], qubits[0]))
    g.append(_CX(qubits[0], qubits[1]))
    return g^

def _build_cz_cx_h(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_H(qubits[1]))
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_H(qubits[1]))
    return g^

def _build_cy_cx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_Sdg(qubits[1]))
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_S(qubits[1]))
    return g^

def _build_cp_cx_p(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_P(qubits[0], params[0] / 2))
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_P(qubits[1], -params[0] / 2))
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_P(qubits[1], params[0] / 2))
    return g^

def _build_crz_cx_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[1], params[0] / 2))
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_RZ(qubits[1], -params[0] / 2))
    g.append(_CX(qubits[0], qubits[1]))
    return g^

def _build_cry_cx_ry(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RY(qubits[1], params[0] / 2))
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_RY(qubits[1], -params[0] / 2))
    g.append(_CX(qubits[0], qubits[1]))
    return g^

def _build_crx_cx_rx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_RZ(qubits[1], PI / 2))
    g.append(_RY(qubits[1], params[0] / 2))
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_RY(qubits[1], -params[0] / 2))
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_RZ(qubits[1], -PI / 2))
    return g^

def _build_rzz_cx_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_CX(qubits[0], qubits[1]))
    g.append(_RZ(qubits[1], params[0]))
    g.append(_CX(qubits[0], qubits[1]))
    return g^

def _build_ccx_std(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    from transpiler import toffoli_standard
    return toffoli_standard(qubits[0], qubits[1], qubits[2])

def _build_ccx_rz(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    from transpiler import toffoli_rz_based
    return toffoli_rz_based(qubits[0], qubits[1], qubits[2])

def _build_rccx_cx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    from transpiler import toffoli_relative_phase
    return toffoli_relative_phase(qubits[0], qubits[1], qubits[2])

def _build_cswap_cx_ccx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_CX(qubits[2], qubits[1]))
    from transpiler import toffoli_standard
    var sub = toffoli_standard(qubits[0], qubits[1], qubits[2])
    for i in range(len(sub)): g.append(sub[i].copy())
    g.append(_CX(qubits[2], qubits[1]))
    return g^
    
def _build_ccz_h_ccx(qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    var g = List[GateOp]()
    g.append(_H(qubits[1]))
    from transpiler import toffoli_standard
    var sub = toffoli_standard(qubits[0], qubits[1], qubits[2])
    for i in range(len(sub)): g.append(sub[i].copy())
    g.append(_H(qubits[1]))
    return g^

comptime RULE_H_RZ_SX      = 0
comptime RULE_H_RZ_RY      = 1
comptime RULE_S_RZ         = 2
comptime RULE_SDG_RZ       = 3
comptime RULE_T_RZ         = 4
comptime RULE_TDG_RZ       = 5
comptime RULE_Z_RZ         = 6
comptime RULE_X_RZ_SX      = 7
comptime RULE_X_RX         = 8
comptime RULE_Y_RZ_SX      = 9
comptime RULE_SX_H_S       = 10
comptime RULE_P_RZ         = 11
comptime RULE_U3_RZ_SX     = 12
comptime RULE_U3_RZ_RY     = 13
comptime RULE_U1_RZ        = 14
comptime RULE_SWAP_CX      = 15
comptime RULE_CZ_CX_H      = 16
comptime RULE_CY_CX        = 17
comptime RULE_CP_CX_P      = 18
comptime RULE_CRZ_CX_RZ    = 19
comptime RULE_CRY_CX_RY    = 20
comptime RULE_CRX_CX_RX    = 21
comptime RULE_RZZ_CX_RZ    = 22
comptime RULE_CCX_STD      = 23
comptime RULE_CCX_RZ       = 24
comptime RULE_RCCX_CX      = 25
comptime RULE_CSWAP        = 26
comptime RULE_CCZ          = 27

def _apply_rule(rule_id: Int, qubits: List[Int], params: List[Float64]) -> List[GateOp]:
    if rule_id == RULE_H_RZ_SX:     return _build_h_rz_sx(qubits, params)
    if rule_id == RULE_H_RZ_RY:     return _build_h_rz_ry(qubits, params)
    if rule_id == RULE_S_RZ:        return _build_s_rz(qubits, params)
    if rule_id == RULE_SDG_RZ:      return _build_sdg_rz(qubits, params)
    if rule_id == RULE_T_RZ:        return _build_t_rz(qubits, params)
    if rule_id == RULE_TDG_RZ:      return _build_tdg_rz(qubits, params)
    if rule_id == RULE_Z_RZ:        return _build_z_rz(qubits, params)
    if rule_id == RULE_X_RZ_SX:     return _build_x_rz_sx(qubits, params)
    if rule_id == RULE_X_RX:        return _build_x_rx(qubits, params)
    if rule_id == RULE_Y_RZ_SX:     return _build_y_rz_sx(qubits, params)
    if rule_id == RULE_SX_H_S:      return _build_sx_h_s(qubits, params)
    if rule_id == RULE_P_RZ:        return _build_p_rz(qubits, params)
    if rule_id == RULE_U3_RZ_SX:    return _build_u3_rz_sx(qubits, params)
    if rule_id == RULE_U3_RZ_RY:    return _build_u3_rz_ry(qubits, params)
    if rule_id == RULE_U1_RZ:       return _build_u1_rz(qubits, params)
    if rule_id == RULE_SWAP_CX:     return _build_swap_cx(qubits, params)
    if rule_id == RULE_CZ_CX_H:     return _build_cz_cx_h(qubits, params)
    if rule_id == RULE_CY_CX:       return _build_cy_cx(qubits, params)
    if rule_id == RULE_CP_CX_P:     return _build_cp_cx_p(qubits, params)
    if rule_id == RULE_CRZ_CX_RZ:   return _build_crz_cx_rz(qubits, params)
    if rule_id == RULE_CRY_CX_RY:   return _build_cry_cx_ry(qubits, params)
    if rule_id == RULE_CRX_CX_RX:   return _build_crx_cx_rx(qubits, params)
    if rule_id == RULE_RZZ_CX_RZ:   return _build_rzz_cx_rz(qubits, params)
    if rule_id == RULE_CCX_STD:     return _build_ccx_std(qubits, params)
    if rule_id == RULE_CCX_RZ:      return _build_ccx_rz(qubits, params)
    if rule_id == RULE_RCCX_CX:     return _build_rccx_cx(qubits, params)
    if rule_id == RULE_CSWAP:       return _build_cswap_cx_ccx(qubits, params)
    if rule_id == RULE_CCZ:         return _build_ccz_h_ccx(qubits, params)
    return List[GateOp]()

struct EquivalenceLibrary(Copyable, Movable):
    var rules: List[Tuple[String, Int, Int, List[String], Int]]
    
    def __init__(out self):
        self.rules = List[Tuple[String, Int, Int, List[String], Int]]()

    def add_rule(mut self, src_name: String, n_qubits: Int, n_params: Int, dst_gate: List[String], rule_id: Int):
        self.rules.append((src_name, n_qubits, n_params, dst_gate.copy(), rule_id))

    def find_rule(self, gate_name: String, n_qubits: Int, n_params: Int, target: Target) -> Int:
        var best_rule_id = -1
        var best_dst_len = 999999
        for i in range(len(self.rules)):
            var r = self.rules[i].copy()
            if r[0] != gate_name: continue
            if r[1] != n_qubits: continue
            if n_params > 0 and r[2] == 0: continue
            var dst = r[3].copy()
            var valid = True
            for j in range(len(dst)):
                if not target.supports_gate(dst[j]):
                    valid = False
                    break
            if valid:
                var rule_id = r[4]
                var dst_len = len(dst)
                if dst_len < best_dst_len:
                    best_dst_len = dst_len
                    best_rule_id = rule_id
        return best_rule_id

def build_standard_library() -> EquivalenceLibrary:
    var lib = EquivalenceLibrary()
    def make_dst(*names: String) -> List[String]:
        var d = List[String]()
        for n in names: d.append(n)
        return d^
    lib.add_rule("H", 1, 0, make_dst("RZ", "SX"), RULE_H_RZ_SX)
    lib.add_rule("H", 1, 0, make_dst("RZ", "RY"), RULE_H_RZ_RY)
    lib.add_rule("S", 1, 0, make_dst("RZ"), RULE_S_RZ)
    lib.add_rule("SDG", 1, 0, make_dst("RZ"), RULE_SDG_RZ)
    lib.add_rule("T", 1, 0, make_dst("RZ"), RULE_T_RZ)
    lib.add_rule("TDG", 1, 0, make_dst("RZ"), RULE_TDG_RZ)
    lib.add_rule("Z", 1, 0, make_dst("RZ"), RULE_Z_RZ)
    lib.add_rule("X", 1, 0, make_dst("RZ", "SX"), RULE_X_RZ_SX)
    lib.add_rule("X", 1, 0, make_dst("RX"), RULE_X_RX)
    lib.add_rule("Y", 1, 0, make_dst("RZ", "SX"), RULE_Y_RZ_SX)
    lib.add_rule("SX", 1, 0, make_dst("H", "S"), RULE_SX_H_S)
    lib.add_rule("SX", 1, 1, make_dst("RZ"), RULE_P_RZ)
    lib.add_rule("U3", 1, 3, make_dst("RZ", "SX"), RULE_U3_RZ_SX)
    lib.add_rule("U3", 1, 3, make_dst("RZ", "RY"), RULE_U3_RZ_RY)
    lib.add_rule("U", 1, 3, make_dst("RZ", "SX"), RULE_U3_RZ_SX)
    lib.add_rule("U", 1, 3, make_dst("RZ", "RY"), RULE_U3_RZ_RY)
    lib.add_rule("U1", 1, 1, make_dst("RZ"), RULE_U1_RZ)
    lib.add_rule("SWAP", 2, 0, make_dst("CX"), RULE_SWAP_CX)
    lib.add_rule("CZ", 2, 0, make_dst("CX", "H"), RULE_CZ_CX_H)
    lib.add_rule("CY", 2, 0, make_dst("CX", "S", "SDG"), RULE_CY_CX)
    lib.add_rule("CP", 2, 1, make_dst("CX", "P"), RULE_CP_CX_P)
    lib.add_rule("CRZ", 2, 1, make_dst("CX", "RZ"), RULE_CRZ_CX_RZ)
    lib.add_rule("CRY", 2, 1, make_dst("CX", "RY"), RULE_CRY_CX_RY)
    lib.add_rule("CRX", 2, 1, make_dst("CX", "RZ", "RY"), RULE_CRX_CX_RX)
    lib.add_rule("RZZ", 2, 1, make_dst("CX", "RZ"), RULE_RZZ_CX_RZ)
    lib.add_rule("CCX", 3, 0, make_dst("CX", "H", "T", "TDG", "S"), RULE_CCX_STD)
    lib.add_rule("CCX", 3, 0, make_dst("CX", "H", "RZ"), RULE_CCX_RZ)
    lib.add_rule("RCCX", 3, 0, make_dst("CX", "H", "RZ"), RULE_RCCX_CX)
    lib.add_rule("RCCX", 3, 0, make_dst("CX", "H", "T", "TDG"), RULE_RCCX_CX)
    lib.add_rule("CSWAP", 3, 0, make_dst("CX", "H", "T", "TDG", "S"), RULE_CSWAP)
    lib.add_rule("CCZ", 3, 0, make_dst("CX", "H", "T", "TDG", "S"), RULE_CCZ)
    lib.add_rule("CCZ", 3, 0, make_dst("CX", "H", "RZ"), RULE_CCZ)
    return lib^

struct BasisTranslator:
    var target: Target
    var lib: EquivalenceLibrary
    var max_passes: Int

    def __init__(out self, target: Target, max_passes: Int = 20):
        self.target = target.copy()
        self.lib = build_standard_library()
        self.max_passes = max_passes

    def add_rule(mut self, src_name: String, n_qubits: Int, n_params: Int, dst_gates: List[String], rule_id: Int):
        self.lib.add_rule(src_name, n_qubits, n_params, dst_gates, rule_id)

    def _needs_translation(self, gate: GateOp) -> Bool:
        var name = gate.name
        if name == "INPUT" or name == "OUTPUT" or name == "MEASURE" or name == "BARRIER":
            return False
        return not self.target.supports_gate(name)

    def _translate_gate(self, gate: GateOp) -> Tuple[Bool, List[GateOp]]:
        if not self._needs_translation(gate):
            return (False, List[GateOp]())
        var n_q = len(gate.qubit)
        var n_p = len(gate.theta)
        var rule_id = self.lib.find_rule(gate.name, n_q, n_p, self.target)
        if rule_id < 0:
            rule_id = self.lib.find_rule(gate.name, n_q, 0, self.target)
        if rule_id < 0:
            return (False, List[GateOp]())
        var new_gates = _apply_rule(rule_id, gate.qubit, gate.theta)
        return (True, new_gates^)

    def run(self, dag: DAGCircuit) -> DAGCircuit:
        var dagc = dag.copy()
        for _pass in range(self.max_passes):
            var topo = dagc.topological_sort()
            var targets = List[Int]()
            for i in range(len(topo)):
                var nid = topo[i]
                if dagc.nodes[nid].type != "gate": continue
                if self._needs_translation(dagc.nodes[nid].gate):
                    targets.append(nid)
            if len(targets) == 0: break
            for ti in range(len(targets)):
                var nid = targets[ti]
                if dagc.nodes[nid].type == "removed": continue
                var res = self._translate_gate(dagc.nodes[nid].gate.copy())
                if not res[0]: continue
                var block = List[Int]()
                block.append(nid)
                dagc.replace_block_operations(res[1], block)
            dagc.finalize_operation()
        return dagc^

def _apply_basis_translator(gates: List[GateOp], target: Target) -> List[GateOp]:
    var translator = BasisTranslator(target)
    var result = gates.copy()
    for _pass in range(10):
        var new_result = List[GateOp]()
        var changed = False
        for i in range(len(result)):
            var res = translator._translate_gate(result[i].copy())
            if res[0]:
                var sub = res[1].copy()
                for j in range(len(sub)): new_result.append(sub[j].copy())
                changed = True
            else:
                new_result.append(result[i].copy())
        result = new_result^
        if not changed: break
    return result^