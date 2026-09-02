from dagcircuit import DAGCircuit
from transpiler import CouplingMap, SabreRouting

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
        for _ in range(n): last_gate.append(-1)
        var topo = dag.topological_sort()
        for i in range(len(topo)):
            var gate = dag.nodes[topo[i]].gate.copy()
            if len(gate.qubit) != 2: continue
            var q0 = gate.qubit[0]
            var q1 = gate.qubit[1]
            if q0 >= n or q1 >= n: continue
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
                        already = True; break
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
            var g = self.gates[ri].copy()
            rdag.gates.append(Sabre2QGate(g.q0, g.q1, g.id))
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

    def swap(mut self, v0: Int, v1: Int):
        var p0 = self.pi[v0]
        var p1 = self.pi[v1]
        self.pi[v0] = p1
        self.pi[v1] = p0
        self.pi_inv[p0] = v1
        self.pi_inv[p1] = v0

    def physical(self, v: Int) -> Int:
        return self.pi[v]
    
    def virtual(self, p: Int) -> Int:
        return self.pi_inv[p]

    def layout(self) -> List[Int]:
        return self.pi.copy()
        
struct SabreLayout:
    var trials: Int
    var iter: Int
    var weight: Float64
    var E_size: Int
    var delta: Float64
    var valve_limit: Int

    def __init__(
        out self,
        trials: Int = 5,
        iter: Int = 3,
        weight: Float64 = 0.5,
        E_size: Int = 20,
        delta: Float64 = 0.001,
        valve_limit: Int = 5
    ):
        self.trials = trials
        self.iter = iter
        self.weight = weight
        self.E_size = E_size
        self.delta = delta
        self.valve_limit = valve_limit

    def _dense_mapping(self, n: Int, cm: CouplingMap) -> SabreMapping:
        var m = SabreMapping(n, cm.nq)
        var deg_order = List[Int]()
        for i in range(cm.nq): deg_order.append(i)
        for i in range(cm.nq):
            for j in range(i + 1, cm.nq):
                if len(cm.edges[deg_order[i]]) < len(cm.edges[deg_order[j]]):
                    var tmp = deg_order[i]
                    deg_order[i] = deg_order[j]
                    deg_order[j] = tmp
        var used = List[Bool]()
        for _ in range(cm.nq): used.append(False)
        for v in range(n):
            var best_p = -1
            for ki in range(len(deg_order)):
                var p = deg_order[ki]
                if not used[p]:
                    best_p = p; break
            if best_p >= 0:
                m.pi[v] = best_p
                m.pi_inv[best_p] = v
                used[best_p] = True
        return m^

    def _random_mapping(self, n_virt: Int, n_phys: Int, seed: Int) -> SabreMapping:
        """
        Linear Congruential Generator
        """
        var m = SabreMapping(n_virt, n_phys)
        var arr = List[Int]()
        for i in range(n_phys): arr.append(i)
        var state = seed
        for i in range(n_virt):
            state = (state * 1664525 + 1013904223) & 0x7FFFFFFF
            var j = i + (state % (n_phys - i))
            var tmp = arr[i]
            arr[i] = arr[j]
            arr[j] = tmp
            m.pi[i] = arr[i]
            m.pi_inv[arr[i]] = i
        return m^

    def _count_swaps_needed(
        self,
        sd: SabreDAG,
        mapping: SabreMapping,
        cm: CouplingMap,
        D: List[List[Int]]
    ) -> Int:
        var total = 0
        for i in range(len(sd.gates)):
            var g = sd.gates[i].copy()
            var p0 = mapping.physical(g.q0)
            var p1 = mapping.physical(g.q1)
            if D[p0][p1] > 1:
                total += D[p0][p1] - 1
        return total

    def run(self, dag: DAGCircuit, cm: CouplingMap) -> DAGCircuit:
        var dagc = dag.copy()
        var n_virt = dag.qubits
        var n_phys = cm.nq
        if n_virt == 0 or n_virt > n_phys:
            return dagc^
        var sd = SabreDAG.from_dag(dag)
        if len(sd.gates) == 0:
            print("SabreLayout: no 2-qubit gates")
            return dagc^
        print("SabreLayout: virt =", n_virt, "phys =", n_phys, "2-qubit gates =", len(sd.gates))
        D = compute_distance_matrix(cm)
        var router = SabreRouting(self.weight, self.E_size, self.delta, self.valve_limit)
        var sd_rev = sd.reversed()
        var best_layout: List[Int] = List[Int]()
        var best_swap_count: Int = 999999999
        for trial in range(self.trials):
            var mapping: SabreMapping
            if trial == 0:
                mapping = self._dense_mapping(n_virt, cm)
            else:
                mapping = self._random_mapping(n_virt, n_phys, trial * 7919 + 1234)
            for i in range(self.iter):
                print("DEBUG: trial =", trial, "iter =", i)
                var fwd = router.run(sd, mapping, cm, D)
                var final_map = fwd[1].copy()
                var rev = router.run(sd_rev, final_map, cm, D)
                var new_init_map = rev[1].copy()
                mapping = new_init_map^
            var est_swaps = self._count_swaps_needed(sd, mapping, cm, D)
            print("SabreLayout: trial", trial, "swaps =", est_swaps)
            if est_swaps < best_swap_count:
                best_swap_count = est_swaps
                best_layout = mapping.layout()
        print("SabreLayout: best swaps =", best_swap_count, "best layout =", best_layout)
        dagc.layout = best_layout^
        return dagc^
        
def compute_distance_matrix(cm: CouplingMap) -> List[List[Int]]:
    """
    Compute the All-Pairs Shortest Path (APSP) by Floyd-Warshall algorithm
    """
    var n = cm.nq
    var INF = 99999999
    var D = List[List[Int]]()
    for i in range(n):
        var row = List[Int]()
        for j in range(n):
            if i == j:
                row.append(0)
            else:
                row.append(INF)
        D.append(row^)
    for i in range(n):
        for ki in range(len(cm.edges[i])):
            var j = cm.edges[i][ki]
            D[i][j] = 1
    for i in range(n):
        for j in range(n):
            for k in range(n):
                if D[j][i] < INF and D[i][k] < INF:
                    if D[j][i] + D[i][k] < D[j][k]:
                        D[j][k] = D[j][i] + D[i][k]
    return D^