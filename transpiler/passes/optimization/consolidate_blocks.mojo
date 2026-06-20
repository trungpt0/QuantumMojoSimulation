from dagcircuit import DAGCircuit
from gates import GateOp
from qmath import Matrix2x2, Matrix4x4, GateMatrix, Complex
from transpiler.passes.optimization import Collect1qRuns, Collect2qBlocks

struct ConsolidateBlocks:
    var kak_basis_gate: String
    var force_consolidate: Bool
    var approximation_degree: Float64

    def __init__(out self, kak_basis_gate: String = "cx", force_consolidate: Bool = True, approximation_degree: Float64 = 1.0):
        self.kak_basis_gate = kak_basis_gate
        self.force_consolidate = force_consolidate
        self.approximation_degree = approximation_degree

    def _get_block_qubits(self, dag: DAGCircuit, block: List[Int]) -> Tuple[Int, Int]:
        for i in range(len(block)):
            var nid = block[i]
            if dag.nodes[nid].type == "removed": continue
            var gate = dag.nodes[nid].gate.copy()
            if len(gate.qubit) == 2:
                if gate.qubit[0] > gate.qubit[1]: return (gate.qubit[1], gate.qubit[0])
                else: return (gate.qubit[0], gate.qubit[1])
        return (-1, -1)
        
    def _should_consolidate_1q(self, dag: DAGCircuit, run: List[Int]) -> Bool:
        if self.force_consolidate: return True
        var count: Int = 0
        for i in range(len(run)):
            if dag.nodes[run[i]].type != "removed":
                count += 1
        return count >= 2

    def _should_consolidate_2q(self, dag: DAGCircuit, block: List[Int]) -> Bool:
        if self.force_consolidate: return True
        var count: Int = 0
        var has_2q = False
        for i in range(len(block)):
            if dag.nodes[block[i]].type == "removed": continue
            count += 1
            if (len(dag.nodes[block[i]].gate.qubit)) == 2:
                has_2q = True
        return has_2q and count >= 1
    
    def _gate_to_2x2(self, gate: GateOp) -> Matrix2x2:
        if gate.name == "UnitaryGate1q":
            return Matrix2x2(
                Complex(gate.theta[0], gate.theta[1]),
                Complex(gate.theta[2], gate.theta[3]),
                Complex(gate.theta[4], gate.theta[5]),
                Complex(gate.theta[6], gate.theta[7])
            )
        return GateMatrix.get_1q(gate.name, gate.theta)

    def _gate_to_4x4(self, gate: GateOp, q0: Int, q1: Int) -> Matrix4x4:
        if len(gate.qubit) == 1:
            var m1 = self._gate_to_2x2(gate)
            var phys_q = gate.qubit[0]
            var eye = Matrix2x2()
            if phys_q == q0:
                return GateMatrix.tensor(m1, eye)
            else:
                return GateMatrix.tensor(eye, m1)
        else:
            var m4 = GateMatrix.get_2q(gate.name)
            var gq0 = gate.qubit[0]
            var gq1 = gate.qubit[1]
            if gq0 == q0 and gq1 == q1:
                return m4^
            elif gq0 == q1 and gq1 == q0:
                var swap = GateMatrix.get_2q("SWAP")
                return swap.mul(m4.mul(swap))
            else:
                return Matrix4x4()

    def _compute_1q_unitary(self, dag: DAGCircuit, run: List[Int]) -> Matrix2x2:
        var res = Matrix2x2()
        for i in range(len(run)):
            var nid = run[i]
            if dag.nodes[nid].type == "removed": continue
            var m2 = self._gate_to_2x2(dag.nodes[nid].gate)
            res = m2.mul(res)
        return res^

    def _compute_2q_unitary(self, dag: DAGCircuit, block: List[Int], q0: Int, q1: Int) -> Matrix4x4:
        var res = Matrix4x4()
        for i in range(len(block)):
            var nid = block[i]
            if dag.nodes[nid].type == "removed": continue
            var m4 = self._gate_to_4x4(dag.nodes[nid].gate, q0, q1)
            res = m4.mul(res)
        return res^

    def _process_1q_runs(self, mut dag: DAGCircuit, run_list: List[List[Int]]):
        for r in range(len(run_list)):
            var run = run_list[r].copy()
            if not self._should_consolidate_1q(dag, run): continue
            var q: Int = -1
            for i in range(len(run)):
                if dag.nodes[run[i]].type != "removed":
                    q = dag.nodes[run[i]].gate.qubit[0]
                    break
            if q < 0: continue
            var u2 = self._compute_1q_unitary(dag, run)
            if u2.is_identity():
                for i in range(len(run)):
                    dag.remove_operation(run[i])
                continue
            var ql = List[Int]()
            ql.append(q)
            var params = List[Float64]()
            for row in range(2):
                for col in range(2):
                    var v = u2.get(row, col)
                    params.append(v.re)
                    params.append(v.im)
            dag.replace_block_operation(GateOp("UnitaryGate1q", ql, params), run)

    def _process_2q_blocks(self, mut dag: DAGCircuit, block_list: List[List[Int]]):
        for b in range(len(block_list)):
            var block = block_list[b].copy()
            if not self._should_consolidate_2q(dag, block): continue
            var qubits = self._get_block_qubits(dag, block)
            var q0 = qubits[0]
            var q1 = qubits[1]
            if q0 < 0 or q1 < 0: continue
            var u4 = self._compute_2q_unitary(dag, block, q0, q1)
            var u_qubits = List[Int]()
            u_qubits.append(q0)
            u_qubits.append(q1)
            var new_gate = GateOp("UnitaryGate2q", u_qubits, u4.serialize())
            dag.replace_block_operation(new_gate, block)

    def run(self, dag: DAGCircuit) -> DAGCircuit:
        var dagc = dag.copy()
        print("---DEBUG: Dag before consolidate")
        dagc.print_dag()
        print("---DEBUG END")
        var run_list = Collect1qRuns().run(dagc)
        var block_list = Collect2qBlocks().run(dagc)
        print("Consolidate blocks:")
        print("1q runs", len(run_list))
        print("2q blocks", len(block_list))
        self._process_1q_runs(dagc, run_list)
        print("---DEBUG: Dag after process 1q")
        dagc.print_dag()
        print("---END: Dag after process 1q")
        block_list = Collect2qBlocks().run(dagc)
        print("---DEBUG: Collect 2q")
        print("Len of blocklist: ", len(block_list))
        for i in range(len(block_list)):
            print("Block ", i)
            var block = block_list[i].copy()
            for j in range(len(block)):
                print(String(block[j]) + " ")
        print("---END: Collect 2q")
        self._process_2q_blocks(dagc, block_list)
        print("---DEBUG: Dag after consolidate")
        dagc.print_dag()
        print("---DEBUG END")
        return dagc^