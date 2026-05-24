from dagcircuit import DAGCircuit
from gates import GateOp
from qmath import sqrt, GateMaxtrix

struct CommutationCheck:
    """
    @ Theory: AB = BA
    """
    def __init__(out self):
        pass

    def _share_qubit(self, g1: GateOp, g2: GateOp) -> Bool:
        for i in range(len(g1.qubit)):
            for j in range(len(g2.qubit)):
                if g1.qubit[i] == g2.qubit[j]:
                    return True
        return False

    def _in_list(self, name: String, list: List[String]) -> Bool:
        for i in range(len(list)):
            if name == list[i]: return True
        return False

    def _same_single_qubit(self, g1: GateOp, g2: GateOp) -> Bool:
        return (len(g1.qubit) == 1 and len(g2.qubit) == 1 and g1.qubit[0] == g2.qubit[0])

    def _cx_commute(self, g1: GateOp, g2: GateOp) -> Int:
        var cx = g1.copy() if g1.name == "CX" else g2.copy()
        var other = g2.copy() if g1.name == "CX" else g1.copy()
        var cx_c = cx.qubit[0].copy()
        var cx_t = cx.qubit[1].copy()
        var on = other.name
        # CX control: Z-type gates commute
        if (len(other.qubit) == 1 and other.qubit[0] == cx_c):
            var z_cm_list = List[String]()
            z_cm_list.append("Z")
            z_cm_list.append("RZ")
            z_cm_list.append("S")
            z_cm_list.append("SDG")
            z_cm_list.append("T")
            z_cm_list.append("TDG")
            z_cm_list.append("P")
            z_cm_list.append("IP")
            var z_uncm_list = List[String]()
            z_uncm_list.append("X")
            z_uncm_list.append("Y")
            z_uncm_list.append("RX")
            z_uncm_list.append("RY")
            z_uncm_list.append("H")
            if self._in_list(on, z_cm_list): return 1
            if self._in_list(on, z_uncm_list): return 0
        # CX target: X-type gates commute
        if(len(other.qubit) == 1 and other.qubit[0] == cx_t):
            var x_cm_list = List[String]()
            x_cm_list.append("X")
            x_cm_list.append("RX")
            var x_uncm_list = List[String]()
            x_uncm_list.append("Y")
            x_uncm_list.append("RY")
            x_uncm_list.append("Z")
            x_uncm_list.append("RZ")
            x_uncm_list.append("H")
            x_uncm_list.append("S")
            x_uncm_list.append("SDG")
            x_uncm_list.append("T")
            x_uncm_list.append("TDG")
            x_uncm_list.append("P")
            x_uncm_list.append("IP")
            if self._in_list(on, x_cm_list): return 1
            if self._in_list(on, x_uncm_list): return 0
        # CX - CX commute
        if (on == "CX" and cx_c == other.qubit[0] and cx_t != other.qubit[1]): return 1
        if (on == "CX" and cx_t == other.qubit[1] and cx_c != other.qubit[0]): return 1
        if (on == "CX" and cx_c == other.qubit[1] and cx_t == other.qubit[0]): return 0
        return -1

    def _cz_commute(self, g1: GateOp, g2: GateOp) -> Int:
        var cz = g1.copy() if g1.name == "CZ" else g2.copy()
        var other = g2.copy() if g1.name == "CZ" else g1.copy()
        var on = other.name
        # CZ target or control: Z-type gates commute
        if len(other.qubit) == 1:
            if other.qubit[0] == cz.qubit[0] or other.qubit[0] == cz.qubit[1]:
                var z_cm_list = List[String]()
                z_cm_list.append("Z")
                z_cm_list.append("RZ")
                z_cm_list.append("S")
                z_cm_list.append("SDG")
                z_cm_list.append("T")
                z_cm_list.append("TDG")
                z_cm_list.append("P")
                z_cm_list.append("IP")
                var z_uncm_list = List[String]()
                z_uncm_list.append("X")
                z_uncm_list.append("Y")
                z_uncm_list.append("RX")
                z_uncm_list.append("RY")
                z_uncm_list.append("H")
                if self._in_list(on, z_cm_list): return 1
                if self._in_list(on, z_uncm_list): return 0
        # CZ - CZ commute
        if on == "CZ":
            if ((other.qubit[0] == cz.qubit[0] and other.qubit[1] == cz.qubit[1]) or
                 other.qubit[1] == cz.qubit[0] and other.qubit[0] == cz.qubit[1]):
                return 1
        return -1

    def _swap_commute(self, g1: GateOp, g2: GateOp) -> Int:
        var swap = g1.copy() if g1.name == "SWAP" else g2.copy()
        var other = g2.copy() if g1.name == "SWAP" else g1.copy()
        var on = other.name
        # SWAP - SWAP commute
        if on == "SWAP":
            if ((other.qubit[0] == swap.qubit[0] and other.qubit[1] == swap.qubit[1]) or
                 other.qubit[1] == swap.qubit[0] and other.qubit[0] == swap.qubit[1]):
                return 1
        if len(other.qubit) == 1:
            if other.qubit[0] != swap.qubit[0] and other.qubit[0] != swap.qubit[1]:
                return 1
        return -1

    def _table_check(self, g1: GateOp, g2: GateOp) -> Int:
        # Unitary gates commutation
        var name_g1 = g1.name
        var name_g2 = g2.name
        if name_g1 == name_g2 and g1.qubit == g2.qubit:
            if name_g1 == "RX" or name_g1 == "RY" or name_g1 == "RZ" or name_g1 == "P" or name_g1 == "IP":
                return 1
            if name_g1 == "X" or name_g1 == "Y" or name_g1 == "Z":
                return 1
            if name_g1 == "H":
                return 1
            if name_g1 == "CX" or name_g1 == "CZ" or name_g1 == "SWAP":
                return 1
        # Z-axis rotation gates commutation
        var z_axis = List[String]()
        z_axis.append("Z")
        z_axis.append("RZ")
        z_axis.append("S")
        z_axis.append("SDG")
        z_axis.append("T")
        z_axis.append("TDG")
        z_axis.append("P")
        z_axis.append("IP")
        var name_g1_is_z = self._in_list(name_g1, z_axis)
        var name_g2_is_z = self._in_list(name_g2, z_axis)
        if name_g1_is_z and name_g2_is_z and self._same_single_qubit(g1, g2):
            return 1
        # X-axis rotation gates commutation
        var x_axis = List[String]()
        x_axis.append("X")
        x_axis.append("RX")
        var name_g1_is_x = self._in_list(name_g1, x_axis)
        var name_g2_is_x = self._in_list(name_g2, x_axis)
        if name_g1_is_x and name_g2_is_x and self._same_single_qubit(g1, g2):
            return 1
        # Y-axis rotarion gates commutation
        var y_axis = List[String]()
        y_axis.append("Y")
        y_axis.append("RY")
        var name_g1_is_y = self._in_list(name_g1, y_axis)
        var name_g2_is_y = self._in_list(name_g2, y_axis)
        if name_g1_is_y and name_g2_is_y and self._same_single_qubit(g1, g2):
            return 1
        # CX commutation
        if name_g1 == "CX" or name_g2 == "CX":
            return self._cx_commute(g1, g2)
        # CZ commutation
        if name_g1 == "CZ" or name_g2 == "CZ":
            return self._cz_commute(g1, g2)
        # SWAP commutation
        if name_g1 == "SWAP" or name_g2 == "SWAP":
            return self._swap_commute(g1, g2)
        # I commutation
        if name_g1 == "I" or name_g2 == "I":
            return 1
        return -1

    def _single_qubit_matrix_commute(self, g1: GateOp, g2: GateOp) -> Bool:
        if (len(g1.qubit) != 1 or len(g2.qubit) != 1 or g1.qubit[0] != g2.qubit[0]):
            return False
        var m1 = GateMaxtrix.get_1q(g1.name, g1.theta)
        var m2 = GateMaxtrix.get_1q(g2.name, g2.theta)
        var g1g2 = m1.mul(m2)
        var g2g1 = m2.mul(m1)
        var tol: Float64 = 1e-10
        for row in range(2):
            for col in range(2):
                var diff = g1g2.get(row, col).sub(g2g1.get(row, col))
                if sqrt(diff.re * diff.re + diff.im * diff.im) > tol:
                    return False
        return True

    def commute(self, g1: GateOp, g2: GateOp) -> Bool:
        if not self._share_qubit(g1, g2):
            return True
        var tab = self._table_check(g1, g2)
        if tab != -1: return tab == 1
        return self._single_qubit_matrix_commute(g1, g2)

struct DependencyCheck:
    def __init__(out self):
        pass

    def _is_ancestor(self, dag: DAGCircuit, src: Int, dst: Int) -> Bool:
        if src == dst: return False
        var visited = List[Bool]()
        for i in range(len(dag.nodes)):
            visited.append(False)
        var queue = List[Int]()
        queue.append(src)
        visited[src] = True
        var head: Int = 0
        while head < len(queue):
            var curr = queue[head]
            head += 1
            var succs = dag.successors(curr)
            for i in range(len(succs)):
                var s = succs[i]
                if s == dst: return True
                if not visited[s]:
                    visited[s] = True
                    queue.append(s)
        return False

    def _reachable_forward(self, dag: DAGCircuit, start: Int) -> List[Bool]:
        var visited = List[Bool]()
        for i in range(len(dag.nodes)):
            visited.append(False)
        var queue = List[Int]()
        queue.append(start)
        visited[start] = True
        var head: Int = 0
        while head < len(queue):
            var curr = queue[head]
            head += 1
            var succs = dag.successors(curr)
            for i in range(len(succs)):
                if not visited[succs[i]]:
                    visited[succs[i]] = True
                    queue.append(succs[i])
        return visited^

    def _reachable_backward(self, dag: DAGCircuit, start: Int) -> List[Bool]:
        var visited = List[Bool]()
        for i in range(len(dag.nodes)):
            visited.append(False)
        var queue = List[Int]()
        queue.append(start)
        visited[start] = True
        var head: Int = 0
        while head < len(queue):
            var curr = queue[head]
            head += 1
            var preds = dag.predecessors(curr)
            for i in range(len(preds)):
                if not visited[preds[i]]:
                    visited[preds[i]] = True
                    queue.append(preds[i])
        return visited^

    def _gate_between(self, dag: DAGCircuit, src: Int, dst: Int) -> List[Int]:
        var node_ids = List[Int]()
        if not self._is_ancestor(dag, src, dst):
            return node_ids^
        var reachable_from_src = self._reachable_forward(dag, src)
        var reachable_to_dst = self._reachable_backward(dag, dst)
        for i in range(len(dag.nodes)):
            if i == src or i == dst: continue
            if dag.nodes[i].type == "removed": continue
            if dag.nodes[i].type != "gate": continue
            if reachable_from_src[i] and reachable_to_dst[i]:
                    node_ids.append(i)
        return node_ids^

struct CommutativeInverseCancellation:

    def __init__(out self):
        pass
    
    def _are_inverses(self, g1: GateOp, g2: GateOp) -> Bool:
        if len(g1.qubit) != len(g2.qubit): return False
        for i in range(len(g1.qubit)):
            if g1.qubit[i] != g2.qubit[i]: return False
        if g1.name == "H" and g2.name == "H": return True
        if g1.name == "X" and g2.name == "X": return True
        if g1.name == "Y" and g2.name == "Y": return True
        if g1.name == "Z" and g2.name == "Z": return True
        if g1.name == "CX" and g2.name == "CX": return True
        if g1.name == "S" and g2.name == "SDG": return True
        if g1.name == "SDG" and g2.name == "S": return True
        if g1.name == "T" and g2.name == "TDG": return True
        if g1.name == "TDG" and g2.name == "T": return True
        return False

    def _can_cancel(self, dag: DAGCircuit, src: Int, dst: Int, cm_check: CommutationCheck, dp_check: DependencyCheck) -> Bool:
        if not dp_check._is_ancestor(dag, src, dst): return False
        var path_gates = dp_check._gate_between(dag, src, dst)
        var src_gate = dag.nodes[src].gate.copy()
        for i in range(len(path_gates)):
            mid = path_gates[i]
            if dag.nodes[mid].type == "removed": continue
            var mid_gate = dag.nodes[mid].gate.copy()
            if not cm_check.commute(src_gate, mid_gate):
                return False
        return True

    def run(self, dag: DAGCircuit) -> DAGCircuit:
        var commute_check = CommutationCheck()
        var depend_check = DependencyCheck()
        var dagc = dag.copy()
        var changed = True
        while changed:
            changed = False
            var topo = dagc.topological_sort()
            for i in range(len(topo)):
                var nid = topo[i]
                if dagc.nodes[nid].type == "removed": continue
                var gnid = dagc.nodes[nid].gate.copy()
                for j in range(i + 1, len(topo)):
                    var cid = topo[j]
                    if dagc.nodes[cid].type == "removed": continue
                    var gcid = dagc.nodes[cid].gate.copy()
                    if not self._are_inverses(gnid, gcid): continue
                    if self._can_cancel(dagc, nid, cid, commute_check, depend_check):
                        dagc.remove_operation(nid)
                        dagc.remove_operation(cid)
                        changed = True
                if changed: break
        return dagc^