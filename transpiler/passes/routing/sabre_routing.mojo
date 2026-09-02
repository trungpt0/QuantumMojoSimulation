from transpiler import SabreDAG, SabreMapping, CouplingMap

struct SabreRouting:
    var weight: Float64
    var E_size: Int
    var delta: Float64
    var valve_limit: Int

    def __init__(
        out self,
        weight: Float64 = 0.5,
        E_size: Int = 20,
        delta: Float64 = 0.001,
        valve_limit: Int = 5
    ):
        self.weight = weight
        self.E_size = E_size
        self.delta = delta
        self.valve_limit = valve_limit

    def _candidate_swaps(
        self,
        front_layer: List[Int],
        mapping: SabreMapping,
        cm: CouplingMap,
        sd: SabreDAG
    ) -> List[Tuple[Int, Int]]:
        var candidates = List[Tuple[Int, Int]]()
        var seen = List[Bool]()
        for _ in range(cm.nq * cm.nq): seen.append(False)
        for fi in range(len(front_layer)):
            var g = sd.gates[front_layer[fi]].copy()
            for vq in [g.q0, g.q1]:
                var pq = mapping.physical(vq)
                for ni in range(len(cm.edges[pq])):
                    var nb = cm.edges[pq][ni]
                    var key = pq * cm.nq + nb if pq < nb else nb * cm.nq + pq
                    if seen[key]: continue
                    seen[key] = True
                    var v0 = mapping.virtual(pq)
                    var v1 = mapping.virtual(nb)
                    if v0 >= 0 and v1 >= 0:
                        candidates.append((v0, v1))
        return candidates^

    def _get_extended_set(
        self,
        front_layer: List[Int],
        in_degree: List[Int],
        sd: SabreDAG
    ) -> List[Int]:
        var E = List[Int]()
        var seen = List[Bool]()
        for _ in range(len(sd.gates)): seen.append(False)
        for i in range(len(front_layer)): seen[front_layer[i]] = True
        for fi in range(len(front_layer)):
            var gid = front_layer[fi]
            for si in range(len(sd.succs[gid])):
                var s = sd.succs[gid][si]
                if seen[s]: continue
                seen[s] = True
                E.append(s)
                if len(E) >= self.E_size: break
            if len(E) >= self.E_size: break
        return E^

    def _basic_heuristic(
        self,
        front_layer: List[Int],
        E: List[Int],
        mapping: SabreMapping,
        D: List[List[Int]],
        sd: SabreDAG
    ) -> Float64:
        var h: Float64 = 0.0
        var f_size = len(front_layer)
        var e_size = len(E)
        if f_size > 0:
            for i in range(f_size):
                var g = sd.gates[front_layer[i]].copy()
                var p0 = mapping.physical(g.q0)
                var p1 = mapping.physical(g.q1)
                h += Float64(D[p0][p1])
            h /= Float64(f_size)
        if e_size > 0:
            var e_sum: Float64 = 0.0
            for i in range(e_size):
                var g = sd.gates[E[i]].copy()
                var p0 = mapping.physical(g.q0)
                var p1 = mapping.physical(g.q1)
                e_sum += Float64(D[p0][p1])
            h += self.weight * e_sum / Float64(e_size)
        return h

    def _delta_heuristic(
        self,
        swap_v0: Int,
        swap_v1: Int,
        front_layer: List[Int],
        E: List[Int],
        mapping: SabreMapping,
        D: List[List[Int]],
        sd: SabreDAG,
        decay: List[Float64]
    ) -> Float64:
        var p0_before = mapping.physical(swap_v0)
        var p1_before = mapping.physical(swap_v1)
        var p0_after = p1_before
        var p1_after = p0_before
        var delta_f: Float64 = 0.0
        var f_size = len(front_layer)
        if f_size > 0:
            for i in range(f_size):
                var g = sd.gates[front_layer[i]].copy()
                var gp0_before = mapping.physical(g.q0)
                var gp1_before = mapping.physical(g.q1)
                var gp0_after = gp0_before
                var gp1_after = gp1_before
                if g.q0 == swap_v0: gp0_after = p0_after
                elif g.q0 == swap_v1: gp0_after = p1_after
                if g.q1 == swap_v0: gp1_after = p0_after
                elif g.q1 == swap_v1: gp1_after = p1_after
                delta_f += Float64(D[gp0_after][gp1_after] - D[gp0_before][gp1_before])
            delta_f /= Float64(f_size)
        var delta_e: Float64 = 0.0
        var e_size = len(E)
        if e_size > 0:
            for i in range(e_size):
                var g = sd.gates[E[i]].copy()
                var gp0_before = mapping.physical(g.q0)
                var gp1_before = mapping.physical(g.q1)
                var gp0_after = gp0_before
                var gp1_after = gp1_before
                if g.q0 == swap_v0: gp0_after = p0_after
                elif g.q0 == swap_v1: gp0_after = p1_after
                if g.q1 == swap_v0: gp1_after = p0_after
                elif g.q1 == swap_v1: gp1_after = p1_after
                delta_e += Float64(D[gp0_after][gp1_after] - D[gp0_before][gp1_before])
            delta_e = self.weight * delta_e / Float64(e_size)
        var score = delta_f + delta_e
        var decay_factor = max(decay[swap_v0], decay[swap_v1])
        score *= decay_factor
        return score

    def run(
        self, 
        sd: SabreDAG,
        init_mapping: SabreMapping,
        cm: CouplingMap,
        D: List[List[Int]]
    ) -> Tuple[List[Tuple[Int, Int]], SabreMapping]:
        var mapping = init_mapping.copy()
        var swaps = List[Tuple[Int, Int]]()
        var decay = List[Float64]()
        for _ in range(sd.qubits): decay.append(1.0)
        var cur_in_deg = List[Int]()
        for i in range(len(sd.gates)): cur_in_deg.append(sd.in_degree[i])
        var F = sd.front_layer()
        var stuck_count = 0
        while len(F) > 0:
            var execute_gate_list = List[Int]()
            for fi in range(len(F)):
                var gid = F[fi]
                var g = sd.gates[gid].copy()
                var p0 = mapping.physical(g.q0)
                var p1 = mapping.physical(g.q1)
                if cm.connected(p0, p1):
                    execute_gate_list.append(fi)
            if len(execute_gate_list) > 0:
                stuck_count = 0
                var new_F = List[Int]()
                var executed_gate_set = List[Bool]()
                for _ in range(len(F)): executed_gate_set.append(False)
                for i in range(len(execute_gate_list)): executed_gate_set[execute_gate_list[i]] = True
                for fi in range(len(F)):
                    if not executed_gate_set[fi]:
                        new_F.append(F[fi])
                for i in range(len(execute_gate_list)):
                    var gid = F[execute_gate_list[i]]
                    for si in range(len(sd.succs[gid])):
                        var s = sd.succs[gid][si]
                        cur_in_deg[s] -= 1
                        if cur_in_deg[s] == 0:
                            new_F.append(s)
                F = new_F^
                continue
            stuck_count += 1
            var E = self._get_extended_set(F, cur_in_deg, sd)
            var swap_candidate_list = self._candidate_swaps(F, mapping, cm, sd)
            if len(swap_candidate_list) == 0: break
            var use_value = stuck_count > self.valve_limit
            var best_score = Float64(999999)
            var best_swaps = List[Tuple[Int, Int]]()
            for ci in range(len(swap_candidate_list)):
                var v0 = swap_candidate_list[ci][0]
                var v1 = swap_candidate_list[ci][1]
                var score: Float64
                if use_value:
                    var empty_E = List[Int]()
                    score = self._delta_heuristic(v0, v1, F, empty_E, mapping, D, sd, decay)
                else:
                    score = self._delta_heuristic(v0, v1, F, E, mapping, D, sd, decay)
                if score < best_score - 1e-9:
                    best_score = score
                    best_swaps = List[Tuple[Int, Int]]()
                    best_swaps.append((v0, v1))
                elif abs(score - best_score) < 1e-9:
                    best_swaps.append((v0, v1))
            if len(best_swaps) == 0: break
            var chosen = best_swaps[0]
            var sv0 = chosen[0]
            var sv1 = chosen[1]
            mapping.swap(sv0, sv1)
            swaps.append((sv0, sv1))
            decay[sv0] += self.delta
            decay[sv1] += self.delta
            if stuck_count > self.valve_limit:
                stuck_count = 0
        return (swaps^, mapping^)