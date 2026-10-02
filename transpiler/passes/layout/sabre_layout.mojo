from dagcircuit import DAGCircuit
from transpiler import CouplingMap

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
            rdag.gates.append(
                Sabre2QGate(self.gates[ri].q0, self.gates[ri].q1, self.gates[ri].id)
            )
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
    var pi: List[Int]       # virtual -> physical
    var pi_inv: List[Int]   # physical -> virtual
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


def _moved(p: Int, pa: Int, pb: Int) -> Int:
    if p == pa:
        return pb
    if p == pb:
        return pa
    return p


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
        valve_limit: Int = 0,
    ):
        self.weight = weight
        self.E_size = E_size
        self.delta = delta
        self.valve_limit = valve_limit

    def _candidate_swaps(
        self, F: List[Int], mapping: SabreMapping, cm: CouplingMap, sd: SabreDAG
    ) -> List[Tuple[Int, Int]]:
        var cands = List[Tuple[Int, Int]]()
        for fi in range(len(F)):
            var gid = F[fi]
            for side in range(2):
                var vq = sd.gates[gid].q0 if side == 0 else sd.gates[gid].q1
                var pq = mapping.physical(vq)
                for ni in range(len(cm.edges[pq])):
                    var nb = cm.edges[pq][ni]
                    var a = min(pq, nb)
                    var b = max(pq, nb)
                    var dup = False
                    for k in range(len(cands)):
                        if cands[k][0] == a and cands[k][1] == b:
                            dup = True
                            break
                    if not dup:
                        cands.append((a, b))
        return cands^

    def _get_extended_set(
        self, F: List[Int], mut in_degree: List[Int], sd: SabreDAG
    ) -> List[Int]:
        var E = List[Int]()
        var touched = List[Int]()
        var queue = F.copy()
        var head = 0
        while head < len(queue) and len(E) < self.E_size:
            var gid = queue[head]
            head += 1
            for si in range(len(sd.succs[gid])):
                var s = sd.succs[gid][si]
                in_degree[s] -= 1
                touched.append(s)
                if in_degree[s] == 0:
                    E.append(s)
                    queue.append(s)
                    if len(E) >= self.E_size:
                        break
        for t in range(len(touched)):
            in_degree[touched[t]] += 1
        return E^

    def _score(
        self,
        pa: Int,
        pb: Int,
        F: List[Int],
        E: List[Int],
        mapping: SabreMapping,
        D: List[List[Int]],
        sd: SabreDAG,
        decay: List[Float64],
    ) -> Float64:
        var f_sum: Float64 = 0.0
        for i in range(len(F)):
            var gid = F[i]
            var p0 = _moved(mapping.physical(sd.gates[gid].q0), pa, pb)
            var p1 = _moved(mapping.physical(sd.gates[gid].q1), pa, pb)
            f_sum += Float64(D[p0][p1])
        var h = f_sum / Float64(len(F))
        if len(E) > 0:
            var e_sum: Float64 = 0.0
            for i in range(len(E)):
                var gid = E[i]
                var p0 = _moved(mapping.physical(sd.gates[gid].q0), pa, pb)
                var p1 = _moved(mapping.physical(sd.gates[gid].q1), pa, pb)
                e_sum += Float64(D[p0][p1])
            h += self.weight * e_sum / Float64(len(E))
        return max(decay[pa], decay[pb]) * h

    def _apply_swap(
        self,
        pa: Int,
        pb: Int,
        mut swaps: List[Tuple[Int, Int]],
        mut pswaps: List[Tuple[Int, Int]],
        mut mapping: SabreMapping,
    ):
        swaps.append((mapping.virtual(pa), mapping.virtual(pb)))
        pswaps.append((pa, pb))
        mapping.swap_physical(pa, pb)

    def _release_valve(
        self,
        F: List[Int],
        n_undo: Int,
        mut swaps: List[Tuple[Int, Int]],
        mut pswaps: List[Tuple[Int, Int]],
        mut mapping: SabreMapping,
        cm: CouplingMap,
        D: List[List[Int]],
        sd: SabreDAG,
    ) -> Bool:
        for _ in range(n_undo):
            var ps = pswaps.pop()
            _ = swaps.pop()
            mapping.swap_physical(ps[0], ps[1])
        var best_g = F[0]
        var best_d = 1 << 62
        for i in range(len(F)):
            var gid = F[i]
            var d = D[mapping.physical(sd.gates[gid].q0)][mapping.physical(sd.gates[gid].q1)]
            if d < best_d:
                best_d = d
                best_g = gid
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
            self._apply_swap(path[i], path[i + 1], swaps, pswaps, mapping)
            i += 1
            if j - i > 1:
                self._apply_swap(path[j], path[j - 1], swaps, pswaps, mapping)
                j -= 1
        return True

    def run(
        self,
        sd: SabreDAG,
        init_mapping: SabreMapping,
        cm: CouplingMap,
        D: List[List[Int]],
        seed: Int = 0,
    ) -> Tuple[List[Tuple[Int, Int]], SabreMapping]:
        var mapping = init_mapping.copy()
        var swaps = List[Tuple[Int, Int]]()
        var pswaps = List[Tuple[Int, Int]]()
        var decay = List[Float64]()
        for _ in range(cm.nq):
            decay.append(1.0)
        var cur_in_deg = sd.in_degree.copy()
        var F = sd.front_layer()
        var limit = self.valve_limit if self.valve_limit > 0 else 10 * cm.nq
        var since_progress = 0
        var steps = 0
        var rng = (seed * 2654435761 + 1) & 0x7FFFFFFF
        while len(F) > 0:
            var exec_idx = List[Int]()
            for fi in range(len(F)):
                var gid = F[fi]
                if cm.connected(
                    mapping.physical(sd.gates[gid].q0),
                    mapping.physical(sd.gates[gid].q1),
                ):
                    exec_idx.append(fi)
            if len(exec_idx) > 0:
                var done = List[Bool]()
                for _ in range(len(F)):
                    done.append(False)
                for i in range(len(exec_idx)):
                    done[exec_idx[i]] = True
                var new_F = List[Int]()
                for fi in range(len(F)):
                    if not done[fi]:
                        new_F.append(F[fi])
                for i in range(len(exec_idx)):
                    var gid = F[exec_idx[i]]
                    for si in range(len(sd.succs[gid])):
                        var s = sd.succs[gid][si]
                        cur_in_deg[s] -= 1
                        if cur_in_deg[s] == 0:
                            new_F.append(s)
                F = new_F^
                since_progress = 0
                steps = 0
                for q in range(len(decay)):
                    decay[q] = 1.0
                continue
            if since_progress >= limit:
                if not self._release_valve(
                    F, since_progress, swaps, pswaps, mapping, cm, D, sd
                ):
                    break
                since_progress = 0
                steps = 0
                for q in range(len(decay)):
                    decay[q] = 1.0
                continue
            var E = self._get_extended_set(F, cur_in_deg, sd)
            var cands = self._candidate_swaps(F, mapping, cm, sd)
            if len(cands) == 0:
                break
            var best_score = Float64(1e30)
            var best_idx = List[Int]()
            for ci in range(len(cands)):
                var score = self._score(
                    cands[ci][0], cands[ci][1], F, E, mapping, D, sd, decay
                )
                if score < best_score - 1e-10:
                    best_score = score
                    best_idx.clear()
                    best_idx.append(ci)
                elif score <= best_score + 1e-10:
                    best_idx.append(ci)
            rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
            var k = best_idx[(rng >> 16) % len(best_idx)]
            var pa = cands[k][0]
            var pb = cands[k][1]
            self._apply_swap(pa, pb, swaps, pswaps, mapping)
            since_progress += 1
            steps += 1
            if steps % 5 == 0:
                for q in range(len(decay)):
                    decay[q] = 1.0
            else:
                decay[pa] += self.delta
                decay[pb] += self.delta
        return (swaps^, mapping^)

struct SabreLayout:
    var trials: Int
    var iter: Int
    var weight: Float64
    var E_size: Int
    var delta: Float64
    var valve_limit: Int
    var seed: Int

    def __init__(
        out self,
        trials: Int = 5,
        iter: Int = 3,
        weight: Float64 = 0.5,
        E_size: Int = 20,
        delta: Float64 = 0.001,
        valve_limit: Int = 0,
        seed: Int = 1234,
    ):
        self.trials = trials
        self.iter = iter
        self.weight = weight
        self.E_size = E_size
        self.delta = delta
        self.valve_limit = valve_limit
        self.seed = seed

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

    def _random_mapping(self, n_virt: Int, n_phys: Int, seed: Int) -> SabreMapping:
        var m = SabreMapping(n_virt, n_phys)
        m.clear()
        var arr = List[Int]()
        for i in range(n_phys):
            arr.append(i)
        var state = seed & 0x7FFFFFFF
        for i in range(n_virt):
            state = (state * 1103515245 + 12345) & 0x7FFFFFFF
            var j = i + ((state >> 16) % (n_phys - i))
            var tmp = arr[i]
            arr[i] = arr[j]
            arr[j] = tmp
            m.assign(i, arr[i])
        return m^

    def run(self, dag: DAGCircuit, cm: CouplingMap) -> DAGCircuit:
        var dagc = dag.copy()
        var n_virt = dag.qubits
        var n_phys = cm.nq
        if n_virt == 0 or n_virt > n_phys:
            return dagc^
        var sd = SabreDAG.from_dag(dag)
        if len(sd.gates) == 0:
            return dagc^
        var D = compute_distance_matrix(cm)
        var router = SabreRouting(self.weight, self.E_size, self.delta, self.valve_limit)
        var sd_rev = sd.reversed()
        var best_layout = List[Int]()
        var best_swaps = 1 << 62
        for trial in range(self.trials):
            var base = self.seed + trial * 7919
            var mapping: SabreMapping
            if trial == 0:
                mapping = self._dense_mapping(n_virt, cm)
            else:
                mapping = self._random_mapping(n_virt, n_phys, base)
            for i in range(self.iter):
                var fwd = router.run(sd, mapping, cm, D, base + 2 * i)
                var rev = router.run(sd_rev, fwd[1], cm, D, base + 2 * i + 1)
                mapping = rev[1].copy()
            var final = router.run(sd, mapping, cm, D, base + 2 * self.iter)
            var n_sw = len(final[0])
            if n_sw < best_swaps:
                best_swaps = n_sw
                best_layout = mapping.layout()
            if best_swaps == 0:
                break
        dagc.layout = best_layout^
        return dagc^

def compute_distance_matrix(cm: CouplingMap) -> List[List[Int]]:
    """All-Pairs Shortest Path by Floyd-Warshall"""
    var n = cm.nq
    var INF = 99999999
    var D = List[List[Int]]()
    for i in range(n):
        var row = List[Int]()
        for j in range(n):
            row.append(0 if i == j else INF)
        D.append(row^)
    for i in range(n):
        for ki in range(len(cm.edges[i])):
            var j = cm.edges[i][ki]
            D[i][j] = 1
            D[j][i] = 1
    for k in range(n):
        for i in range(n):
            if D[i][k] >= INF:
                continue
            for j in range(n):
                if D[k][j] < INF and D[i][k] + D[k][j] < D[i][j]:
                    D[i][j] = D[i][k] + D[k][j]
    return D^