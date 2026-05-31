from dagcircuit import DAGCircuit

struct Collect1qRuns:
    var filter_fn_enabled: Bool
    
    def __init__(out self, filter_fn_enabled: Bool = False):
        self.filter_fn_enabled = filter_fn_enabled

    def _default_filter(self, dag: DAGCircuit, run: List[Int]) -> Bool:
        if len(run) >= 2: return True
        if len(run) == 1:
            var name = dag.nodes[run[0]].gate.name.copy()
            var basis = List[String]()
            basis.append("RZ")
            basis.append("SX")
            basis.append("X")
            for i in range(len(basis)):
                if basis[i] == name: return False
            return True
        return False

    def run(self, dag: DAGCircuit) -> List[List[Int]]:
        var run_list = dag.collect_1q_runs()
        if self.filter_fn_enabled:
            var filtered = List[List[Int]]()
            for i in range(len(run_list)):
                if self._default_filter(dag, run_list[i]):
                    filtered.append(run_list[i].copy())
            return filtered^
        return run_list^