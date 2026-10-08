from dagcircuit import DAGCircuit
from transpiler import CouplingMap

struct SabreRNG(Copyable, Movable):
    var state: UInt64

    def __init__(out self, seed: Int):
        self.state = UInt64(seed) * 0x9E3779B97F4A7C15 + 0x632BE59BD9B4E019

    def next(mut self) -> UInt64:
        self.state += 0x9E3779B97F4A7C15
        var z = self.state
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) * 0x94D049BB133111EB
        return z ^ (z >> 31)

    def below(mut self, n: Int) -> Int:
        return Int(self.next() % UInt64(n))

struct DistTable(Copyable, Movable):
    var n: Int
    var d: List[Int]

    def __init__(out self, cm: CouplingMap):
        self.n = cm.nq
        var INF = 1 << 30
        self.d = List[Int]()
        for _ in range(self.n * self.n):
            self.d.append(INF)
        var queue = List[Int]()
        for s in range(self.n):
            queue.clear()
            queue.append(s)
            self.d[s * self.n + s] = 0
            var head = 0
            while head < len(queue):
                var u = queue[head]
                head += 1
                var du = self.d[s * self.n + u]
                for k in range(len(cm.edges[u])):
                    var w = cm.edges[u][k]
                    if self.d[s * self.n + w] > du + 1:
                        self.d[s * self.n + w] = du + 1
                        queue.append(w)

    @always_inline
    def get(self, a: Int, b: Int) -> Int:
        return self.d[a * self.n + b]

struct Sabre2QGate(Copyable, Movable):
    var q0: Int
    var q1: Int
    var id: Int

    def __init__(out self, q0: Int, q1: Int, id: Int):
        self.q0 = q0
        self.q1 = q1
        self.id = id

struct SabreDAG(Copyable, Movable):
    var gates: List[Sabre2QGate]
    var preds: List[List[Int]]
    var succs: List[List[Int]]
    var in_degree: List[Int]
    var qubits: Int

    def __init__(out self, qubits: Int):
        self.qubits = qubits
        self.gates = List[Sabre2QGate]()
        self.preds = List[List[Int]]()
        self.succs = List[List[Int]]()
        self.in_degree = List[Int]()

    @staticmethod
    def from_dag(dag: DAGCircuit) -> SabreDAG:
        var n = dag.qubits
        var sd = SabreDAG(n)
        var last_gate = List[Int]()
        for _ in range(n):
            last_gate.append(-1)
        var topo = dag.topological_sort()
        for i in range(len(topo)):
            var gate = dag.nodes[topo[i]].gate.copy()
            if len(gate.qubit) != 2:
                continue
            var q0 = gate.qubit[0]
            var q1 = gate.qubit[1]
            if q0 >= n or q1 >= n:
                continue
            var gid = len(sd.gates)
            sd.gates.append(Sabre2QGate(q0, q1, topo[i]))
            sd.preds.append(List[Int]())
            sd.succs.append(List[Int]())
            sd.in_degree.append(0)
            if last_gate[q0] >= 0:
                var p = last_gate[q0]
                sd.preds[gid].append(p)
                sd.succs[p].append(gid)
                sd.in_degree[gid] += 1
            if last_gate[q1] >= 0:
                var p = last_gate[q1]
                var already = False
                for k in range(len(sd.preds[gid])):
                    if sd.preds[gid][k] == p:
                        already = True
                        break
                if not already:
                    sd.preds[gid].append(p)
                    sd.succs[p].append(gid)
                    sd.in_degree[gid] += 1
            last_gate[q0] = gid
            last_gate[q1] = gid
        return sd^

    def front_layer(self) -> List[Int]:
        var f = List[Int]()
        for i in range(len(self.gates)):
            if self.in_degree[i] == 0:
                f.append(i)
        return f^

    def reversed(self) -> SabreDAG:
        var rdag = SabreDAG(self.qubits)
        var ng = len(self.gates)
        for i in range(ng):
            var ri = ng - 1 - i
            rdag.gates.append(Sabre2QGate(self.gates[ri].q0, self.gates[ri].q1, self.gates[ri].id))
            rdag.preds.append(List[Int]())
            rdag.succs.append(List[Int]())
            rdag.in_degree.append(0)
        for i in range(ng):
            for j in range(len(self.succs[i])):
                var k = self.succs[i][j]
                var ri = ng - 1 - i
                var rj = ng - 1 - k
                rdag.succs[rj].append(ri)
                rdag.preds[ri].append(rj)
                rdag.in_degree[ri] += 1
        return rdag^

struct SabreMapping(Copyable, Movable):
    var pi: List[Int]
    var pi_inv: List[Int]
    var nv: Int
    var np: Int

    def __init__(out self, n_virt: Int, n_phys: Int):
        self.nv = n_virt
        self.np = n_phys
        self.pi = List[Int]()
        self.pi_inv = List[Int]()
        for i in range(n_virt):
            self.pi.append(i)
        for i in range(n_phys):
            if i < n_virt:
                self.pi_inv.append(i)
            else:
                self.pi_inv.append(-1)

    def __init__(out self, n_virt: Int, n_phys: Int, init_layout: List[Int]):
        self.nv = n_virt
        self.np = n_phys
        self.pi = List[Int]()
        self.pi_inv = List[Int]()
        for _ in range(n_phys):
            self.pi_inv.append(-1)
        for v in range(n_virt):
            var p = init_layout[v] if v < len(init_layout) else v
            self.pi.append(p)
            if p >= 0 and p < n_phys:
                self.pi_inv[p] = v

    def clear(mut self):
        for v in range(self.nv):
            self.pi[v] = -1
        for p in range(self.np):
            self.pi_inv[p] = -1

    def assign(mut self, v: Int, p: Int):
        self.pi[v] = p
        self.pi_inv[p] = v

    def swap_physical(mut self, pa: Int, pb: Int):
        var va = self.pi_inv[pa]
        var vb = self.pi_inv[pb]
        self.pi_inv[pa] = vb
        self.pi_inv[pb] = va
        if va >= 0:
            self.pi[va] = pb
        if vb >= 0:
            self.pi[vb] = pa

    def physical(self, v: Int) -> Int:
        return self.pi[v]

    def virtual(self, p: Int) -> Int:
        return self.pi_inv[p]

    def layout(self) -> List[Int]:
        return self.pi.copy()

struct RouteResult(Copyable, Movable):
    var swaps: List[Tuple[Int, Int]]
    var mapping: SabreMapping
    var depth: Int
    var complete: Bool

    def __init__(
        out self,
        swaps: List[Tuple[Int, Int]],
        mapping: SabreMapping,
        depth: Int,
        complete: Bool,
    ):
        self.swaps = swaps.copy()
        self.mapping = mapping.copy()
        self.depth = depth
        self.complete = complete

def _event_depth(ev_a: List[Int], ev_b: List[Int], ev_w: List[Int], n: Int) -> Int:
    var qd = List[Int]()
    for _ in range(n):
        qd.append(0)
    var depth = 0
    for i in range(len(ev_a)):
        var d = max(qd[ev_a[i]], qd[ev_b[i]]) + ev_w[i]
        qd[ev_a[i]] = d
        qd[ev_b[i]] = d
        if d > depth:
            depth = d
    return depth

struct SabreRouting:
    var basic_weight: Float64
    var weight: Float64
    var E_size: Int
    var delta: Float64
    var valve_limit: Int
    var basic_scale_size: Bool

    def __init__(
        out self,
        basic_weight: Float64 = 1.0,
        weight: Float64 = 0.5,
        E_size: Int = 20,
        delta: Float64 = 0.001,
        valve_limit: Int = 0,
        basic_scale_size: Bool = False,
    ):
        self.basic_weight = basic_weight
        self.weight = weight
        self.E_size = E_size
        self.delta = delta
        self.valve_limit = valve_limit
        self.basic_scale_size = basic_scale_size

    def _rebuild(
        self,
        F: List[Int],
        mut fpart: List[Int],
        mut fgate: List[Int],
        mut eadj: List[List[Int]],
        mut E: List[Int],
        mut in_degree: List[Int],
        sd: SabreDAG,
    ):
        for v in range(len(fpart)):
            fpart[v] = -1
            fgate[v] = -1
            eadj[v].clear()
        for i in range(len(F)):
            var g = F[i]
            fpart[sd.gates[g].q0] = sd.gates[g].q1
            fpart[sd.gates[g].q1] = sd.gates[g].q0
            fgate[sd.gates[g].q0] = g
            fgate[sd.gates[g].q1] = g
        E.clear()
        var touched = List[Int]()
        var queue = F.copy()
        var head = 0
        while head < len(queue) and len(E) < self.E_size:
            var g = queue[head]
            head += 1
            for si in range(len(sd.succs[g])):
                var s = sd.succs[g][si]
                in_degree[s] -= 1
                touched.append(s)
                if in_degree[s] == 0:
                    E.append(s)
                    queue.append(s)
                    if len(E) >= self.E_size:
                        break
        for t in range(len(touched)):
            in_degree[touched[t]] += 1
        for i in range(len(E)):
            var g = E[i]
            eadj[sd.gates[g].q0].append(sd.gates[g].q1)
            eadj[sd.gates[g].q1].append(sd.gates[g].q0)

    def _set_total(self, S: List[Int], mapping: SabreMapping, D: DistTable, sd: SabreDAG) -> Int:
        var t = 0
        for i in range(len(S)):
            var g = S[i]
            t += D.get(mapping.physical(sd.gates[g].q0), mapping.physical(sd.gates[g].q1))
        return t

    def _delta_front(self, pa: Int, pb: Int, va: Int, vb: Int, fpart: List[Int], mapping: SabreMapping, D: DistTable) -> Int:
        var d = 0
        if va >= 0:
            var w = fpart[va]
            if w >= 0 and w != vb:
                var pw = mapping.physical(w)
                d += D.get(pb, pw) - D.get(pa, pw)
        if vb >= 0:
            var w = fpart[vb]
            if w >= 0 and w != va:
                var pw = mapping.physical(w)
                d += D.get(pa, pw) - D.get(pb, pw)
        return d

    def _delta_ext(self, pa: Int, pb: Int, va: Int, vb: Int, eadj: List[List[Int]], mapping: SabreMapping, D: DistTable) -> Int:
        var d = 0
        if va >= 0:
            for k in range(len(eadj[va])):
                var w = eadj[va][k]
                if w != vb:
                    var pw = mapping.physical(w)
                    d += D.get(pb, pw) - D.get(pa, pw)
        if vb >= 0:
            for k in range(len(eadj[vb])):
                var w = eadj[vb][k]
                if w != va:
                    var pw = mapping.physical(w)
                    d += D.get(pa, pw) - D.get(pb, pw)
        return d

    def _apply_swap(
        self,
        pa: Int,
        pb: Int,
        mut swaps: List[Tuple[Int, Int]],
        mut pswaps: List[Tuple[Int, Int]],
        mut ev_a: List[Int],
        mut ev_b: List[Int],
        mut ev_w: List[Int],
        mut mapping: SabreMapping,
    ):
        swaps.append((mapping.virtual(pa), mapping.virtual(pb)))
        pswaps.append((pa, pb))
        ev_a.append(pa)
        ev_b.append(pb)
        ev_w.append(3)
        mapping.swap_physical(pa, pb)

    def _release_valve(
        self,
        F: List[Int],
        n_undo: Int,
        mut swaps: List[Tuple[Int, Int]],
        mut pswaps: List[Tuple[Int, Int]],
        mut ev_a: List[Int],
        mut ev_b: List[Int],
        mut ev_w: List[Int],
        mut mapping: SabreMapping,
        cm: CouplingMap,
        D: DistTable,
        sd: SabreDAG,
    ) -> Bool:
        for _ in range(n_undo):
            var ps = pswaps.pop()
            _ = swaps.pop()
            _ = ev_a.pop()
            _ = ev_b.pop()
            _ = ev_w.pop()
            mapping.swap_physical(ps[0], ps[1])
        var best_g = F[0]
        var best_d = 1 << 62
        for i in range(len(F)):
            var g = F[i]
            var d = D.get(mapping.physical(sd.gates[g].q0), mapping.physical(sd.gates[g].q1))
            if d < best_d:
                best_d = d
                best_g = g
        var src = mapping.physical(sd.gates[best_g].q0)
        var dst = mapping.physical(sd.gates[best_g].q1)
        var parent = List[Int]()
        for _ in range(cm.nq):
            parent.append(-1)
        parent[src] = src
        var queue = List[Int]()
        queue.append(src)
        var head = 0
        while head < len(queue):
            var u = queue[head]
            head += 1
            if u == dst:
                break
            for k in range(len(cm.edges[u])):
                var w = cm.edges[u][k]
                if parent[w] < 0:
                    parent[w] = u
                    queue.append(w)
        if parent[dst] < 0:
            return False
        var path = List[Int]()
        var cur = dst
        while cur != src:
            path.append(cur)
            cur = parent[cur]
        path.append(src)
        var i = 0
        var j = len(path) - 1
        while j - i > 1:
            self._apply_swap(path[i], path[i + 1], swaps, pswaps, ev_a, ev_b, ev_w, mapping)
            i += 1
            if j - i > 1:
                self._apply_swap(path[j], path[j - 1], swaps, pswaps, ev_a, ev_b, ev_w, mapping)
                j -= 1
        return True

    def route(
        self,
        sd: SabreDAG,
        init_mapping: SabreMapping,
        cm: CouplingMap,
        D: DistTable,
        seed: Int = 0,
        cutoff: Int = -1,
    ) -> RouteResult:
        var N = cm.nq
        var nv = sd.qubits
        var mapping = init_mapping.copy()
        var rng = SabreRNG(seed)
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
        var is_done = List[Bool]()
        for _ in range(len(sd.gates)):
            is_done.append(False)
        var in_deg = sd.in_degree.copy()
        var F = sd.front_layer()
        var E = List[Int]()
        self._rebuild(F, fpart, fgate, eadj, E, in_deg, sd)
        var f_total = self._set_total(F, mapping, D, sd)
        var e_total = self._set_total(E, mapping, D, sd)
        var limit = self.valve_limit if self.valve_limit > 0 else 10 * N
        var since_progress = 0
        var steps = 0
        var check_all = True
        var last_va = -1
        var last_vb = -1
        var complete = True
        var new_F = List[Int]()
        var done = List[Int]()
        var cand_a = List[Int]()
        var cand_b = List[Int]()
        var cand_df = List[Int]()
        var cand_de = List[Int]()
        var best = List[Int]()
        while len(F) > 0:
            if cutoff >= 0 and len(swaps) > cutoff:
                complete = False
                break
            done.clear()
            if check_all:
                for i in range(len(F)):
                    var g = F[i]
                    if D.get(mapping.physical(sd.gates[g].q0), mapping.physical(sd.gates[g].q1)) == 1:
                        done.append(g)
                        is_done[g] = True
            else:
                for side in range(2):
                    var v = last_va if side == 0 else last_vb
                    if v >= 0:
                        var g = fgate[v]
                        if g >= 0 and not is_done[g]:
                            if D.get(mapping.physical(sd.gates[g].q0), mapping.physical(sd.gates[g].q1)) == 1:
                                done.append(g)
                                is_done[g] = True
            if len(done) > 0:
                for i in range(len(done)):
                    var g = done[i]
                    ev_a.append(mapping.physical(sd.gates[g].q0))
                    ev_b.append(mapping.physical(sd.gates[g].q1))
                    ev_w.append(1)
                new_F.clear()
                for i in range(len(F)):
                    if not is_done[F[i]]:
                        new_F.append(F[i])
                for i in range(len(done)):
                    var g = done[i]
                    for si in range(len(sd.succs[g])):
                        var s = sd.succs[g][si]
                        in_deg[s] -= 1
                        if in_deg[s] == 0:
                            new_F.append(s)
                for i in range(len(done)):
                    is_done[done[i]] = False
                F = new_F.copy()
                self._rebuild(F, fpart, fgate, eadj, E, in_deg, sd)
                f_total = self._set_total(F, mapping, D, sd)
                e_total = self._set_total(E, mapping, D, sd)
                since_progress = 0
                steps = 0
                check_all = True
                for q in range(N):
                    decay[q] = 1.0
                continue
            check_all = False
            if since_progress >= limit:
                if not self._release_valve(F, since_progress, swaps, pswaps, ev_a, ev_b, ev_w, mapping, cm, D, sd):
                    break
                f_total = self._set_total(F, mapping, D, sd)
                e_total = self._set_total(E, mapping, D, sd)
                since_progress = 0
                steps = 0
                check_all = True
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
            var bw = self.basic_weight / Float64(len(F)) if self.basic_scale_size else self.basic_weight
            var lw = self.weight / Float64(len(E)) if len(E) > 0 else 0.0
            var best_score = Float64(1e300)
            best.clear()
            for c in range(len(cand_a)):
                var pa = cand_a[c]
                var pb = cand_b[c]
                var va = mapping.virtual(pa)
                var vb = mapping.virtual(pb)
                var df = self._delta_front(pa, pb, va, vb, fpart, mapping, D)
                var de = self._delta_ext(pa, pb, va, vb, eadj, mapping, D)
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
            last_va = mapping.virtual(pa)
            last_vb = mapping.virtual(pb)
            self._apply_swap(pa, pb, swaps, pswaps, ev_a, ev_b, ev_w, mapping)
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
        var depth = _event_depth(ev_a, ev_b, ev_w, N)
        return RouteResult(swaps, mapping, depth, complete)

    def run(
        self,
        sd: SabreDAG,
        init_mapping: SabreMapping,
        cm: CouplingMap,
        D: DistTable,
        seed: Int = 0,
    ) -> Tuple[List[Tuple[Int, Int]], SabreMapping]:
        var r = self.route(sd, init_mapping, cm, D, seed)
        return (r.swaps.copy(), r.mapping.copy())

struct SabreLayout:
    var trials: Int
    var iter: Int
    var weight: Float64
    var E_size: Int
    var delta: Float64
    var valve_limit: Int
    var seed: Int
    var score_trials: Int
    var basic_weight: Float64
    var greedy_seed: Bool
    var refine_steps: Int

    def __init__(
        out self,
        trials: Int = 15,
        iter: Int = 3,
        weight: Float64 = 0.5,
        E_size: Int = 20,
        delta: Float64 = 0.001,
        valve_limit: Int = 0,
        seed: Int = 1234,
        score_trials: Int = 3,
        basic_weight: Float64 = 1.0,
        greedy_seed: Bool = True,
        refine_steps: Int = -1,
    ):
        self.trials = trials
        self.iter = iter
        self.weight = weight
        self.E_size = E_size
        self.delta = delta
        self.valve_limit = valve_limit
        self.seed = seed
        self.score_trials = score_trials
        self.basic_weight = basic_weight
        self.greedy_seed = greedy_seed
        self.refine_steps = refine_steps

    def _dense_mapping(self, n: Int, cm: CouplingMap) -> SabreMapping:
        var best_nodes = List[Int]()
        var best_edges = -1
        for start in range(cm.nq):
            var inset = List[Bool]()
            for _ in range(cm.nq):
                inset.append(False)
            var nodes = List[Int]()
            nodes.append(start)
            inset[start] = True
            var head = 0
            while head < len(nodes) and len(nodes) < n:
                var u = nodes[head]
                head += 1
                for k in range(len(cm.edges[u])):
                    var w = cm.edges[u][k]
                    if not inset[w] and len(nodes) < n:
                        inset[w] = True
                        nodes.append(w)
            if len(nodes) < n:
                continue
            var cnt = 0
            for i in range(len(nodes)):
                var u = nodes[i]
                for k in range(len(cm.edges[u])):
                    if inset[cm.edges[u][k]]:
                        cnt += 1
            if cnt > best_edges:
                best_edges = cnt
                best_nodes = nodes^
        var m = SabreMapping(n, cm.nq)
        if len(best_nodes) < n:
            return m^
        m.clear()
        for v in range(n):
            m.assign(v, best_nodes[v])
        return m^

    def _random_mapping(self, n_virt: Int, n_phys: Int, rng_seed: Int) -> SabreMapping:
        var m = SabreMapping(n_virt, n_phys)
        m.clear()
        var arr = List[Int]()
        for i in range(n_phys):
            arr.append(i)
        var rng = SabreRNG(rng_seed)
        for i in range(n_virt):
            var j = i + rng.below(n_phys - i)
            var tmp = arr[i]
            arr[i] = arr[j]
            arr[j] = tmp
            m.assign(i, arr[i])
        return m^

    def _greedy_mapping(
        self, sd: SabreDAG, n: Int, cm: CouplingMap, D: DistTable
    ) -> SabreMapping:
        var N = cm.nq
        var ng = len(sd.gates)
        var W = List[Float64]()
        for _ in range(n * n):
            W.append(0.0)
        var tot = List[Float64]()
        for _ in range(n):
            tot.append(0.0)
        for t in range(ng):
            var a = sd.gates[t].q0
            var b = sd.gates[t].q1
            var w = Float64(ng - t) / Float64(ng)
            W[a * n + b] += w
            W[b * n + a] += w
            tot[a] += w
            tot[b] += w
        var pos = List[Int]()
        for _ in range(n):
            pos.append(-1)
        var used = List[Bool]()
        for _ in range(N):
            used.append(False)
        var m = SabreMapping(n, N)
        m.clear()
        for _ in range(n):
            var bv = -1
            var b_conn = -1.0
            var b_tot = -1.0
            for v in range(n):
                if pos[v] >= 0:
                    continue
                var conn = 0.0
                for u in range(n):
                    if pos[u] >= 0:
                        conn += W[v * n + u]
                if conn > b_conn + 1e-12 or (conn >= b_conn - 1e-12 and tot[v] > b_tot):
                    b_conn = conn
                    b_tot = tot[v]
                    bv = v
            var bp = -1
            var b_cost = Float64(1e300)
            var b_deg = -1
            for p in range(N):
                if used[p]:
                    continue
                var cost = 0.0
                for u in range(n):
                    if pos[u] >= 0:
                        var dist = Float64(D.get(p, pos[u]))
                        cost += (W[bv * n + u] + 1e-3) * dist
                var deg = len(cm.edges[p])
                if cost < b_cost - 1e-12 or (cost <= b_cost + 1e-12 and deg > b_deg):
                    b_cost = cost
                    bp = p
                    b_deg = deg
            pos[bv] = bp
            used[bp] = True
            m.assign(bv, bp)
        return m^

    def _score_layout(
        self,
        router: SabreRouting,
        sd: SabreDAG,
        mapping: SabreMapping,
        cm: CouplingMap,
        D: DistTable,
        base: Int,
        cutoff: Int,
    ) -> Tuple[Int, Int]:
        var best_sw = 1 << 62
        var best_dp = 1 << 62
        var cut = cutoff
        for k in range(self.score_trials):
            var r = router.route(sd, mapping, cm, D, base + 101 * k, cut)
            if not r.complete:
                continue
            var sw = len(r.swaps)
            if sw < best_sw or (sw == best_sw and r.depth < best_dp):
                best_sw = sw
                best_dp = r.depth
                if cut < 0 or sw < cut:
                    cut = sw
        return (best_sw, best_dp)

    def _refine(
        self,
        router: SabreRouting,
        sd: SabreDAG,
        mut layout: List[Int],
        mut best_sw: Int,
        mut best_dp: Int,
        n_virt: Int,
        cm: CouplingMap,
        D: DistTable,
    ):
        var steps = self.refine_steps if self.refine_steps >= 0 else 2 * n_virt
        if steps == 0 or best_sw == 0 or len(layout) < n_virt:
            return
        var N = cm.nq
        var rng = SabreRNG(self.seed * 7777 + 13)
        var cur = SabreMapping(n_virt, N)
        cur.clear()
        for v in range(n_virt):
            cur.assign(v, layout[v])
        for step in range(steps):
            if best_sw == 0:
                break
            var cand = cur.copy()
            var v = rng.below(n_virt)
            var pv = cand.physical(v)
            if n_virt >= 2 and rng.below(10) < 3:
                var w = rng.below(n_virt - 1)
                if w >= v:
                    w += 1
                cand.swap_physical(pv, cand.physical(w))
            else:
                var deg = len(cm.edges[pv])
                if deg == 0:
                    continue
                var p = cm.edges[pv][rng.below(deg)]
                cand.swap_physical(pv, p)
            var sc = self._score_layout(
                router, sd, cand, cm, D, self.seed * 31 + 97 * step, best_sw
            )
            if sc[0] < best_sw or (sc[0] == best_sw and sc[1] < best_dp):
                best_sw = sc[0]
                best_dp = sc[1]
                cur = cand^
                layout = cur.layout()

    def run(self, dag: DAGCircuit, cm: CouplingMap) -> DAGCircuit:
        var dagc = dag.copy()
        var n_virt = dag.qubits
        var n_phys = cm.nq
        if n_virt == 0 or n_virt > n_phys:
            return dagc^
        var sd = SabreDAG.from_dag(dag)
        if len(sd.gates) == 0:
            return dagc^
        var D = DistTable(cm)
        var router = SabreRouting(
            basic_weight=self.basic_weight,
            weight=self.weight,
            E_size=self.E_size,
            delta=self.delta,
            valve_limit=self.valve_limit,
        )
        var sd_rev = sd.reversed()
        var BIG = 1 << 62
        var best_layout = List[Int]()
        var best_sw = BIG
        var best_dp = BIG
        for trial in range(self.trials):
            var base = self.seed * 1000003 + trial * 7919
            var mapping: SabreMapping
            if trial == 0:
                mapping = self._dense_mapping(n_virt, cm)
            elif trial == 1 and self.greedy_seed:
                mapping = self._greedy_mapping(sd, n_virt, cm, D)
            else:
                mapping = self._random_mapping(n_virt, n_phys, base)
            for i in range(self.iter):
                var fwd = router.route(sd, mapping, cm, D, base + 2 * i)
                if len(fwd.swaps) <= best_sw:
                    var cut = best_sw if best_sw < BIG else -1
                    var sc = self._score_layout(router, sd, mapping, cm, D, base + 5000 + 211 * i, cut)
                    if sc[0] < best_sw or (sc[0] == best_sw and sc[1] < best_dp):
                        best_sw = sc[0]
                        best_dp = sc[1]
                        best_layout = mapping.layout()
                if best_sw == 0:
                    break
                var rev = router.route(sd_rev, fwd.mapping, cm, D, base + 2 * i + 1)
                mapping = rev.mapping.copy()
            if best_sw == 0:
                break
            var cut = best_sw if best_sw < BIG else -1
            var sc = self._score_layout(router, sd, mapping, cm, D, base + 9000, cut)
            if sc[0] < best_sw or (sc[0] == best_sw and sc[1] < best_dp):
                best_sw = sc[0]
                best_dp = sc[1]
                best_layout = mapping.layout()
            if best_sw == 0:
                break
        self._refine(router, sd, best_layout, best_sw, best_dp, n_virt, cm, D)
        print("SWAPs:", best_sw)
        dagc.layout = best_layout^
        return dagc^

def compute_distance_matrix(cm: CouplingMap) -> List[List[Int]]:
    var t = DistTable(cm)
    var D = List[List[Int]]()
    for i in range(t.n):
        var row = List[Int]()
        for j in range(t.n):
            row.append(t.get(i, j))
        D.append(row^)
    return D^