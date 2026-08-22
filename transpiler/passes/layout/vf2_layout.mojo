from dagcircuit import DAGCircuit
from transpiler import CouplingMap

struct InteractionGraph(Copyable, Movable):
    var nq: Int
    var adj: List[List[Int]]
    var weight: List[List[Int]]

    def __init__(out self, nq: Int):
        self.nq = nq
        self.adj = List[List[Int]]()
        self.weight = List[List[Int]]()
        for _ in range(nq):
            self.adj.append(List[Int]())
            var row = List[Int]()
            for _ in range(nq): row.append(0)
            self.weight.append(row^)

    def add_edge(mut self, u: Int, v: Int):
        if u < 0 or v < 0 or u >= self.nq or v >= self.nq:
            return
        if u == v: return
        self.weight[u][v] += 1
        self.weight[v][u] += 1
        for i in range(len(self.adj[u])):
            if self.adj[u][i] == v: return
        self.adj[u].append(v)
        self.adj[v].append(u)

    def degree(self, u: Int) -> Int:
        return len(self.adj[u])

    def connected(self, u: Int, v: Int) -> Bool:
        for i in range(len(self.adj[u])):
            if self.adj[u][i] == v: return True
        return False

    def total_edges(self) -> Int:
        var s = 0
        for u in range(self.nq):
            s += len(self.adj[u])
        return s // 2

    @staticmethod
    def from_dag(dag: DAGCircuit) -> InteractionGraph:
        var nq = dag.qubits
        var g = InteractionGraph(nq)
        var topo = dag.topological_sort()
        for i in range(len(topo)):
            var gate = dag.nodes[topo[i]].gate.copy()
            if len(gate.qubit) == 2:
                g.add_edge(gate.qubit[0], gate.qubit[1])
        return g^

struct VF2State(Copyable, Movable):
    var n1: Int
    var n2: Int
    var core_1: List[Int]
    var core_2: List[Int]
    var t1: List[Bool]
    var t2: List[Bool]
    var depth: Int

    def __init__(out self, n1: Int,  n2: Int):
        self.n1 = n1
        self.n2 = n2
        self.depth = 0
        self.core_1 = List[Int]()
        self.core_2 = List[Int]()
        self.t1 = List[Bool]()
        self.t2 = List[Bool]()
        for _ in range(n1):
            self.core_1.append(-1)
            self.t1.append(False)
        for _ in range(n2):
            self.core_2.append(-1)
            self.t2.append(False)

    def add_pair(mut self, u: Int, v: Int, g1: InteractionGraph, cm: CouplingMap):
        self.core_1[u] = v
        self.core_2[v] = u
        self.t1[u] = False
        self.t2[u] = False
        self.depth += 1
        for i in range(len(g1.adj[u])):
            var nb = g1.adj[u][i]
            if self.core_1[nb] < 0:
                self.t1[nb] = True
        for i in range(len(cm.edges[v])):
            var nb = cm.edges[v][i]
            if self.core_2[nb] < 0:
                self.t2[nb] = True
    
    def remove_pair(mut self, u: Int, v: Int, g1: InteractionGraph, cm: CouplingMap):
        self.core_1[u] = -1
        self.core_2[v] = -1
        self.depth -= 1
        for i in range(self.n1): self.t1[i] = False
        for i in range(self.n2): self.t2[i] = False
        for uu in range(self.n1):
            if self.core_1[uu] < 0: continue
            for i in range(len(g1.adj[uu])):
                var nb = g1.adj[uu][i]
                if self.core_1[nb] < 0: self.t1[nb] = True
        for vv in range(self.n2):
            if self.core_2[vv] < 0: continue
            for i in range(len(cm.edges[vv])):
                var nb = cm.edges[vv][i]
                if self.core_2[nb] < 0: self.t2[nb] = True
    
    def is_complete(self) -> Bool:
        return self.depth == self.n1

    def get_layout(self) -> List[Int]:
        var layout = List[Int]()
        for u in range(self.n1):
            layout.append(self.core_1[u])
        return layout^

struct VF2Feasibility(Copyable, Movable):
    """
    Consistency is TRUE:
        SUB: edge (u, u1) ∈ G1 → edge (v, v1) ∈ G2
    Cutting is FALSE:
        |{Γ2(v) ∩ T2}| < |{Γ1(u) ∩ T1}| ∨
        |{Γ2(v) ∩ T˜2}| < |{Γ1(u) ∩ T˜1}|
    """
    def __init__(out self):
        pass

    def check(
        self,
        state: VF2State,
        u: Int,
        v: Int,
        g1: InteractionGraph,
        cm: CouplingMap
    ) -> Bool:
        for i in range(len(g1.adj[u])):
            var u2 = g1.adj[u][i]
            if state.core_1[u2] < 0: continue
            var v2 = state.core_1[u2]
            if not cm.connected(v, v2):
                return False
        var t1_count = 0
        for i in range(len(g1.adj[u])):
            var nb = g1.adj[u][i]
            if state.t1[nb]: t1_count += 1
        var t2_count = 0
        for i in range(len(cm.edges[v])):
            var nb = cm.edges[v][i]
            if state.t2[nb]: t2_count += 1
        if t2_count < t1_count:
            return False
        var new1 = 0
        for i in range(len(g1.adj[u])):
            var nb = g1.adj[u][i]
            if state.core_1[nb] < 0 and not state.t1[nb]:
                new1 += 1
        var new2 = 0
        for i in range(len(cm.edges[v])):
            var nb = cm.edges[v][i]
            if state.core_2[nb] < 0 and not state.t2[nb]:
                new2 += 1
        if new2 < new1:
            return False
        return True

struct VF2Matcher(Copyable, Movable):
    var call_limit: Int
    var max_solutions: Int

    def __init__(out self, call_limit: Int = 100000, max_solutions: Int = 3):
        self.call_limit = call_limit
        self.max_solutions = max_solutions

    def _candidate_pairs(
        self,
        state: VF2State,
        g1: InteractionGraph,
        cm: CouplingMap
    ) -> List[Tuple[Int, Int]]:
        var pairs = List[Tuple[Int, Int]]()
        var u_min = -1
        for u in range(state.n1):
            if state.t1[u]:
                u_min = u; break
        if u_min >= 0:
            for v in range(state.n2):
                if state.t2[v]:
                    pairs.append((u_min, v))
            return pairs^
        for u in range(state.n1):
            if state.core_1[u] < 0:
                u_min = u; break
        if u_min < 0: return pairs^
        for v in range(state.n2):
            if state.core_2[v] < 0:
                pairs.append((u_min, v))
        return pairs^

    def _dfs(
        mut self,
        mut state: VF2State,
        g1: InteractionGraph,
        cm: CouplingMap,
        feas: VF2Feasibility,
        mut solutions: List[List[Int]],
        mut calls: Int
    ):
        calls += 1
        if calls > self.call_limit: return
        if len(solutions) >= self.max_solutions: return
        if state.is_complete():
            solutions.append(state.get_layout())
            return
        var pairs = self._candidate_pairs(state, g1, cm)
        for pi in range(len(pairs)):
            var u = pairs[pi][0]
            var v = pairs[pi][1]
            if not feas.check(state, u, v, g1, cm):
                continue
            state.add_pair(u, v, g1, cm)
            self._dfs(state, g1, cm, feas, solutions, calls)
            state.remove_pair(u, v, g1, cm)
            if len(solutions) >= self.max_solutions: return

    def match(
        mut self,
        g1: InteractionGraph,
        cm: CouplingMap
    ) -> List[List[Int]]:
        var solutions = List[List[Int]]()
        var call_count = 0
        var feas = VF2Feasibility()
        var state = VF2State(g1.nq, cm.nq)
        self._dfs(state, g1, cm, feas, solutions, call_count)
        return solutions^

struct VF2Layout:
    var call_limit: Int
    var max_solutions: Int

    def __init__(out self, call_limit: Int = 100000, max_solutions: Int = 3):
        self.call_limit = call_limit
        self.max_solutions = max_solutions

    def _dense_fallback(self, dag: DAGCircuit, cm: CouplingMap) -> List[Int]:
        var nq = dag.qubits
        var ig = InteractionGraph.from_dag(dag)
        var virt_score = List[Int]()
        for i in range(nq):
            var tot = 0
            for j in range(nq): tot += ig.weight[i][j]
            virt_score.append(tot)
        var order = List[Int]()
        for i in range(nq): order.append(i)
        for i in range(nq):
            for j in range(i+1, nq):
                if virt_score[order[i]] < virt_score[order[j]]:
                    var tmp = order[i]; order[i] = order[j]; order[j] = tmp
        var phys_deg = List[Int]()
        for p in range(cm.nq): phys_deg.append(len(cm.edges[p]))
        var used = List[Bool]()
        for _ in range(cm.nq): used.append(False)
        var layout = List[Int]()
        for i in range(nq): layout.append(i)
        for idx in range(len(order)):
            var vq = order[idx]
            var best_p = -1
            var best_d = -1
            for p in range(cm.nq):
                if not used[p] and phys_deg[p] > best_d:
                    best_d = phys_deg[p]
                    best_p = p
            if best_p >= 0:
                layout[vq] = best_p
                used[best_p] = True
        return layout^

    def run(self, dag: DAGCircuit, cm: CouplingMap) -> DAGCircuit:
        var dagc = dag.copy()
        var nq = dag.qubits
        if nq > cm.nq or nq == 0:
            return dagc^
        var ig = InteractionGraph.from_dag(dag)
        if ig.total_edges() == 0:
            print("VF2Layout: no 2-qubit gate → Trivial layout")
            return dagc^
        print("VF2Layout: nodes =", nq,
              "edges =", ig.total_edges(),
              "phys =", cm.nq)
        var matcher = VF2Matcher(self.call_limit, self.max_solutions)
        var solutions = matcher.match(ig, cm)
        if len(solutions) > 0:
            print("VF2Layout: found", len(solutions), "solution(s)")
            dagc.layout = best_layout(solutions, ig, cm)
        else:
            print("VF2Layout: no match → dense fallback")
            dagc.layout = self._dense_fallback(dagc, cm)
        print("VF2Layout: layout =", dagc.layout)
        return dagc^

def score_layout(
    layout: List[Int],
    ig: InteractionGraph,
    cm: CouplingMap
) -> Float64:
    var score: Float64 = 0.0
    for u in range(ig.nq):
        if u >= len(layout) or layout[u] < 0: continue
        var v = layout[u]
        for i in range(len(ig.adj[u])):
            var u2 = ig.adj[u][i]
            if u2 <= u: continue
            if u2 >= len(layout) or layout[u2] < 0: continue
            var v2 = layout[u2]
            if cm.connected(v, v2):
                score += Float64(ig.weight[u][u2]) * 10.0
            else:
                var path = cm.shortest_path(v, v2)
                score -= Float64(len(path) - 1) * 5.0
    for u in range(ig.nq):
        if u >= len(layout) or layout[u] < 0: continue
        score += Float64(len(cm.edges[layout[u]])) * 0.1
    return score
    
def best_layout(
    solutions: List[List[Int]],
    ig: InteractionGraph,
    cm: CouplingMap
) -> List[Int]:
    if len(solutions) == 0:
        return List[Int]()
    if len(solutions) == 1:
        return solutions[0].copy()
    var best_idx = 0
    var best_score = score_layout(solutions[0], ig, cm)
    for i in range(1, len(solutions)):
        var s = score_layout(solutions[i], ig, cm)
        if s > best_score:
            best_score = s
            best_idx = i
    return solutions[best_idx].copy()