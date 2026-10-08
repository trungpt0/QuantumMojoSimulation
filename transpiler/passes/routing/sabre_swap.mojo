from dagcircuit import DAGCircuit
from transpiler import CouplingMap, SabreRNG, DistTable, SabreMapping, SabreDAG, RouteResult, SabreRouting

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

    def run(
        mut self,
        dag: DAGCircuit,
        cm: CouplingMap,
        initial_layout: List[Int]
    ) -> DAGCircuit:
        var routed_dag = dag.copy()
        var n_virt = dag.qubits
        var n_phys = cm.nq
        if n_virt == 0 or n_virt > n_phys:
            return routed_dag^
        var sd = SabreDAG.from_dag(dag)
        if len(sd.gates) == 0:
            return routed_dag^
        var D = DistTable(cm)
        var init_map = SabreMapping(n_virt, n_phys, initial_layout)
        var router = SabreRouting(
            basic_weight=self.basic_weight,
            weight=self.weight,
            E_size=self.E_size,
            delta=self.delta,
            valve_limit=self.valve_limit
        )
        var best_route = router.route(sd, init_map, cm, D, self.seed)
        var min_swaps = len(best_route.swaps)
        var min_depth = best_route.depth
        for t in range(1, self.trials):
            var current_seed = self.seed + t * 7919
            var r = router.route(sd, init_map, cm, D, current_seed)
            var cur_swaps = len(r.swaps)
            if cur_swaps < min_swaps or (cur_swaps == min_swaps and r.depth < min_depth):
                min_swaps = cur_swaps
                min_depth = r.depth
                best_route = r
        