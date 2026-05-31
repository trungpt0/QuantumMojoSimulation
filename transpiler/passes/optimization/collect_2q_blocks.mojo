from dagcircuit import DAGCircuit
from gates import GateOp

struct Collect2qBlocks:
    var filter_fn_enabled: Bool

    def __init__(out self, filter_fn_enabled: Bool = False):
        self.filter_fn_enabled = filter_fn_enabled

    def _default_filter(self, dag: DAGCircuit, block: List[Int]) -> Bool:
        return True

    def run(self, dag: DAGCircuit) -> List[List[Int]]:
        var block_list = dag.collect_2q_runs()
        if self.filter_fn_enabled:
            var filtered = List[List[Int]]()
            for i in range(len(block_list)):
                if self._default_filter(dag, block_list[i]):
                    filtered.append(block_list[i].copy())
            return filtered^
        return block_list^
