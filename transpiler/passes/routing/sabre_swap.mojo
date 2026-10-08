from gates import GateOp
from dagcircuit import DAGCircuit, DAGNode
from transpiler import CouplingMap, SabreRNG, DistTable, SabreMapping, SabreDAG, SabreRouting

struct RouteEvent(Copyable, Movable):
    var event_type: Int
    var node_id: Int
    var pa: Int
    var pb: Int

    @always_inline
    def __init__(out self, event_type: Int, node_id: Int, pa: Int, pb: Int):
        self.event_type = event_type
        self.node_id = node_id
        self.pa = pa
        self.pb = pb
    
    @staticmethod
    def gate(node_id: Int) -> RouteEvent:
        return RouteEvent(0, node_id, -1, -1)
    
    @staticmethod
    def swap(pa: Int, pb: Int) -> RouteEvent:
        return RouteEvent(1, -1, pa, pb)

struct FullSwapRouteResult(Copyable, Movable):
    var events: List[RouteEvent]
    var swap_count: Int
    var depth: Int

    def __init__(out self, events: List[RouteEvent], swap_count: Int, depth: Int):
        self.events = events.copy()
        self.swap_count = swap_count
        self.depth = depth

struct SabreSwap:
    var trials: Int
    var weight: Float64
    var E_size: Int
    var delta: Float64
    var valve_limit: Int
    var seed: Int
    var basic_weight: Float64

    def __init__(
        out self,
        trials: Int = 20,
        weight: Float64 = 0.5,
        E_size: Int = 20,
        delta: Float64 = 0.001,
        valve_limit: Int = 0,
        seed: Int = 42,
        basic_weight: Float64 = 1.0
    ):
        self.trials = trials
        self.weight = weight
        self.E_size = E_size
        self.delta = delta
        self.valve_limit = valve_limit
        self.seed = seed
        self.basic_weight = basic_weight

    def _route_and_record(
        self,
        sd: SabreDAG,
        init_mapping: SabreMapping,
        cm: CouplingMap,
        D: DistTable,
        seed: Int
    ) -> FullSwapRouteResult:
        var N = cm.nq
        var nv = sd.qubits
        var mapping = init_mapping.copy()
        var rng = SabreRNG(seed)
        var events = List[RouteEvent]()
        var swap_cnt = 0
        var swaps = List[Tuple[Int, Int]]()
        var pswaps = List[Tuple[Int, Int]]()
        var ev_a = List[Int]()
        var ev_b = List[Int]()
        var ev_w = List[Int]()
        var decay = List[Float64]()
        for _ in range(N):
            decay.append(1.0)
        var fpart = List[Int]()
        var fgate = List[Int]()
        var eadj = List[List[Int]]()
        for _ in range(nv):
            fpart.append(-1)
            fgate.append(-1)
            eadj.append(List[Int]())
        var in_deg = sd.in_degree.copy()
        var F = sd.front_layer()
        var E = List[Int]()
        var router = SabreRouting(
            basic_weight=self.basic_weight,
            weight=self.weight,
            E_size=self.E_size,
            delta=self.delta,
            valve_limit=self.valve_limit,
        )
        router._rebuild(F, fpart, fgate, eadj, E, in_deg, sd)
        var f_total = router._set_total(F, mapping, D, sd)
        var e_total = router._set_total(E, mapping, D, sd)
        var limit = self.valve_limit if self.valve_limit > 0 else 10 * N
        var since_progress = 0
        var steps = 0
        var new_F = List[Int]()
        var done = List[Int]()
        var cand_a = List[Int]()
        var cand_b = List[Int]()
        var cand_df = List[Int]()
        var cand_de = List[Int]()
        var best = List[Int]()
        while len(F) > 0:
            new_F.clear()
            done.clear()
            for i in range(len(F)):
                var g = F[i]
                var p0 = mapping.physical(sd.gates[g].q0)
                var p1 = mapping.physical(sd.gates[g].q1)
                if D.get(p0, p1) == 1:
                    done.append(g)
                    events.append(RouteEvent.gate(sd.gates[g].id))
                    ev_a.append(p0)
                    ev_b.append(p1)
                    ev_w.append(1)
                else:
                    new_F.append(g)
            if len(done) > 0:
                for i in range(len(done)):
                    var g = done[i]
                    for si in range(len(sd.succs[g])):
                        var s = sd.succs[g][si]
                        in_deg[s] -= 1
                        if in_deg[s] == 0:
                            new_F.append(s)
                F = new_F.copy()
                router._rebuild(F, fpart, fgate, eadj, E, in_deg, sd)
                f_total = router._set_total(F, mapping, D, sd)
                e_total = router._set_total(E, mapping, D, sd)
                since_progress = 0
                steps = 0
                for q in range(N):
                    decay[q] = 1.0
                continue
            if since_progress >= limit:
                var prev_swaps_len = len(pswaps)
                if not router._release_valve(F, since_progress, swaps, pswaps, ev_a, ev_b, ev_w, mapping, cm, D, sd): break
                for s_idx in range(prev_swaps_len, len(pswaps)):
                    var ps = pswaps[s_idx]
                    events.append(RouteEvent.swap(ps[0], ps[1]))
                    swap_cnt += 1
                f_total = router._set_total(F, mapping, D, sd)
                e_total = router._set_total(E, mapping, D, sd)
                since_progress = 0
                steps = 0
                for q in range(N):
                    decay[q] = 1.0
                continue
            cand_a.clear()
            cand_b.clear()
            cand_df.clear()
            cand_de.clear()
            for i in range(len(F)):
                var g = F[i]
                for side in range(2):
                    var v = sd.gates[g].q0 if side == 0 else sd.gates[g].q1
                    var p = mapping.physical(v)
                    for k in range(len(cm.edges[p])):
                        var nb = cm.edges[p][k]
                        var vn = mapping.virtual(nb)
                        if vn >= 0 and fpart[vn] >= 0 and nb < p:
                            continue
                        cand_a.append(p)
                        cand_b.append(nb)
            if len(cand_a) == 0:
                break
            var bw = self.basic_weight
            var lw = self.weight / Float64(len(E)) if len(E) > 0 else 0.0
            var best_score = Float64(1e300)
            best.clear()
            for c in range(len(cand_a)):
                var pa = cand_a[c]
                var pb = cand_b[c]
                var va = mapping.virtual(pa)
                var vb = mapping.virtual(pb)
                var df = router._delta_front(pa, pb, va, vb, fpart, mapping, D)
                var de = router._delta_ext(pa, pb, va, vb, eadj, mapping, D)
                cand_df.append(df)
                cand_de.append(de)
                var score = max(decay[pa], decay[pb]) * (bw * Float64(f_total + df) + lw * Float64(e_total + de))
                if score < best_score - 1e-10:
                    best_score = score
                    best.clear()
                    best.append(c)
                elif score <= best_score + 1e-10:
                    best.append(c)
            var k = best[rng.below(len(best))]
            var pa = cand_a[k]
            var pb = cand_b[k]
            router._apply_swap(pa, pb, swaps, pswaps, ev_a, ev_b, ev_w, mapping)
            events.append(RouteEvent.swap(pa, pb))
            swap_cnt += 1
            f_total += cand_df[k]
            e_total += cand_de[k]
            since_progress += 1
            steps += 1
            if steps % 5 == 0:
                for q in range(N):
                    decay[q] = 1.0
            else:
                decay[pa] += self.delta
                decay[pb] += self.delta
        var qd = List[Int]()
        for _ in range(N):
            qd.append(0)
        var max_depth = 0
        for i in range(len(ev_a)):
            var d = max(qd[ev_a[i]], qd[ev_b[i]]) + ev_w[i]
            qd[ev_a[i]] = d
            qd[ev_b[i]] = d
            if d > max_depth:
                max_depth = d
        return FullSwapRouteResult(events, swap_cnt, max_depth)

    def run(
        mut self,
        dag: DAGCircuit,
        cm: CouplingMap,
    ) -> DAGCircuit:
        var initial_layout = dag.layout.copy()
        var n_virt = dag.qubits
        var n_phys = cm.nq
        if n_virt == 0 or n_virt > n_phys:
            return dag.copy()
        var sd = SabreDAG.from_dag(dag)
        if len(sd.gates) == 0:
            return dag.copy()
        var D = DistTable(cm)
        var init_map = SabreMapping(n_virt, n_phys, initial_layout)
        var best_route = self._route_and_record(sd, init_map, cm, D, self.seed)
        var min_swaps = best_route.swap_count
        var min_depth = best_route.depth
        for t in range(1, self.trials):
            var current_seed = self.seed + t * 7919
            var r = self._route_and_record(sd, init_map, cm, D, current_seed)
            if r.swap_count < min_swaps or (r.swap_count == min_swaps and r.depth < min_depth):
                min_swaps = r.swap_count
                min_depth = r.depth
                best_route = r^
        var routed_dag = DAGCircuit(n_phys)
        var current_map = init_map.copy()
        for i in range(len(best_route.events)):
            var ev = best_route.events[i].copy()
            if ev.event_type == 1:
                var q_swap = List[Int]()
                q_swap.append(ev.pa)
                q_swap.append(ev.pb)
                routed_dag.add_operation(GateOp("SWAP", q_swap))
                current_map.swap_physical(ev.pa, ev.pb)
            elif ev.event_type == 0:
                var orig_node = dag.nodes[ev.node_id].copy()
                var gate = orig_node.gate.copy()
                for q_idx in range(len(gate.qubit)):
                    gate.qubit[q_idx] = current_map.physical(gate.qubit[q_idx])
                routed_dag.add_operation(gate)
        routed_dag.finalize_operation()
        routed_dag.layout = initial_layout.copy()
        return routed_dag^