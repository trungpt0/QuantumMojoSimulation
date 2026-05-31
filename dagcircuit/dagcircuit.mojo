from .dagnode import DAGNode, DAGEdge
from circuit import QuantumCircuit
from gates import GateOp

struct DAGCircuit(Copyable, Movable):
    var qubits: Int
    var nodes: List[DAGNode]
    var edges: List[DAGEdge]
    var input_nodes: List[Int]
    var output_nodes: List[Int]
    var frontier: List[Int]

    def __init__(out self, qubits: Int):
        self.qubits = qubits
        self.nodes = List[DAGNode]()
        self.edges = List[DAGEdge]()
        self.input_nodes = List[Int]()
        self.output_nodes = List[Int]()
        self.frontier = List[Int]()

        for q in range(qubits):
            var dqubits = List[Int]()
            dqubits.append(q)
            var inode = DAGNode(len(self.nodes), GateOp("INPUT", dqubits), "input")
            self.input_nodes.append(inode.id)
            self.frontier.append(inode.id)
            self.nodes.append(inode^)

        for q in range(qubits):
            var dqubits = List[Int]()
            dqubits.append(q)
            var onode = DAGNode(len(self.nodes), GateOp("OUTPUT", dqubits), "output")
            self.output_nodes.append(onode.id)
            self.nodes.append(onode^)

    def __moveinit__(out self, owned other: Self):
        self.qubits = other.qubits
        self.nodes = other.nodes^
        self.edges = other.edges^
        self.input_nodes = other.input_nodes^
        self.output_nodes = other.output_nodes^
        self.frontier = other.frontier^

    def __copyinit__(out self, other: Self):
        self.qubits = other.qubits
        self.nodes = other.nodes
        self.edges = other.edges
        self.input_nodes = other.input_nodes
        self.output_nodes = other.output_nodes
        self.frontier = other.frontier

    def _add_edge_if_not_exists(mut self, src: Int, dst: Int, qubit: Int):
        for i in range(len(self.edges)):
            if (self.edges[i].src == src and
                self.edges[i].dst == dst and
                self.edges[i].qubit == qubit):
                return
        self.edges.append(DAGEdge(src, dst, qubit))
    
    def _remove_edge_to_output(mut self, q: Int):
        var onode_id = self.output_nodes[q]
        var new_edges = List[DAGEdge]()
        for i in range(len(self.edges)):
            var e = self.edges[i].copy()
            if e.src == self.frontier[q] and e.dst == onode_id and e.qubit == q:
                continue
            new_edges.append(e.copy())
        self.edges = new_edges^

    def add_operation(mut self, gate: GateOp):
        var node_id = len(self.nodes)
        self.nodes.append(DAGNode(node_id, gate, "gate"))
        for i in range(len(gate.qubit)):
            var q = gate.qubit[i]
            var prev_node_id = self.frontier[q]
            self._remove_edge_to_output(q)
            self.edges.append(DAGEdge(prev_node_id, node_id, q))
            self.frontier[q] = node_id
    
    def finalize_operation(mut self):
        for q in range(self.qubits):
            var onode_id = self.output_nodes[q]
            var fnode_id = self.frontier[q]
            if fnode_id == self.input_nodes[q]:
                self._add_edge_if_not_exists(fnode_id, onode_id, q)
                continue
            self._add_edge_if_not_exists(fnode_id, onode_id, q)

    def remove_operation(mut self, node_id: Int):
        var in_edges = List[DAGEdge]()
        var out_edges = List[DAGEdge]()
        var keep_edges = List[DAGEdge]()
        for i in range(len(self.edges)):
            var edge = self.edges[i].copy()
            if edge.dst == node_id:
                in_edges.append(edge.copy())
            elif edge.src == node_id:
                out_edges.append(edge.copy())
            else:
                keep_edges.append(edge.copy())
        for i in range(len(in_edges)):
            var iedge = in_edges[i].copy()
            for j in range(len(out_edges)):
                var oedge = out_edges[j].copy()
                if iedge.qubit == oedge.qubit:
                    keep_edges.append(DAGEdge(iedge.src, oedge.dst, iedge.qubit))
        self.edges = keep_edges.copy()
        for q in range(self.qubits):
            if self.frontier[q] == node_id:
                var new_front = self.input_nodes[q]
                for i in range(len(in_edges)):
                    if in_edges[i].qubit == q:
                        new_front = in_edges[i].src
                        break
                self.frontier[q] = new_front
        self.nodes[node_id] = DAGNode(node_id, GateOp("REMOVED", List[Int]()), "removed")

    def predecessors(self, node_id: Int) -> List[Int]:
        var preds = List[Int]()
        for i in range(len(self.edges)):
            if self.edges[i].dst == node_id:
                preds.append(self.edges[i].src)
        return preds^

    def successors(self, node_id: Int) -> List[Int]:
        var succs = List[Int]()
        for i in range(len(self.edges)):
            if self.edges[i].src == node_id:
                succs.append(self.edges[i].dst)
        return succs^

    def topological_sort(self) -> List[Int]:
        """
        Kahn's algorithm
        """
        var in_degree = List[Int]()
        for i in range(len(self.nodes)):
            in_degree.append(0)
        for i in range(len(self.edges)):
            in_degree[self.edges[i].dst] += 1
        var queue = List[Int]()
        for i in range(len(self.input_nodes)):
            queue.append(self.input_nodes[i])
        var sorted_nodes = List[Int]()
        var queue_idx: Int = 0
        while queue_idx < len(queue):
            var curr_node = queue[queue_idx]
            queue_idx += 1
            if self.nodes[curr_node].type == "gate":
                sorted_nodes.append(curr_node)
            for i in range(len(self.edges)):
                if self.edges[i].src == curr_node:
                    var dst_node = self.edges[i].dst
                    in_degree[dst_node] -= 1
                    if in_degree[dst_node] == 0:
                        queue.append(dst_node)
        return sorted_nodes^

    def count_operation(self) -> Int:
        var cnt: Int = 0
        for i in range(len(self.nodes)):
            if self.nodes[i].type == "gate":
                cnt += 1
        return cnt

    def depth(self) -> Int:
        var node_depth = List[Int]()
        for _ in range(len(self.nodes)):
            node_depth.append(0)
        var topo = self.topological_sort()
        var depth: Int = 0
        for i in range(len(topo)):
            var node_id = topo[i]
            var d: Int = 0
            var preds = self.predecessors(node_id)
            for j in range(len(preds)):
                if node_depth[preds[j]] > d:
                    d = node_depth[preds[j]]
            node_depth[node_id] = d + 1
            if node_depth[node_id] > depth:
                depth = node_depth[node_id]
        return depth

    @staticmethod
    def from_circuit(qc: QuantumCircuit) -> DAGCircuit:
        var dag = DAGCircuit(qc.n)
        for i in range(len(qc.gates)):
            dag.add_operation(qc.gates[i])
        dag.finalize_operation()
        return dag^
    
    def to_circuit(self) -> QuantumCircuit:
        var qc = QuantumCircuit(self.qubits)
        var N = 1 << self.qubits
        var topo = self.topological_sort()
        for i in range(len(topo)):
            var node = self.nodes[topo[i]].copy()
            var gate = node.gate.copy()
            if gate.name == "X": qc.X(gate.qubit[0])
            elif gate.name == "Y": qc.Y(gate.qubit[0])
            elif gate.name == "Z": qc.Z(gate.qubit[0])
            elif gate.name == "H": qc.H(gate.qubit[0])
            elif gate.name == "S": qc.S(gate.qubit[0])
            elif gate.name == "SDG": qc.Sdg(gate.qubit[0])
            elif gate.name == "T": qc.T(gate.qubit[0])
            elif gate.name == "RX": qc.RX(gate.qubit[0], gate.theta[0])
            elif gate.name == "RY": qc.RY(gate.qubit[0], gate.theta[0])
            elif gate.name == "RZ": qc.RZ(gate.qubit[0], gate.theta[0])
            elif gate.name == "P": qc.P(gate.qubit[0], gate.theta[0])
            elif gate.name == "IP": qc.IP(gate.qubit[0], gate.theta[0])
            elif gate.name == "CX": qc.CX(gate.qubit[0], gate.qubit[1])
            elif gate.name == "MEASURE": qc.measure(gate.qubit[0])
        return qc^

    def print_dag(self):
        print("DAGCIRCUIT")
        print("Qubits:", self.qubits)
        print("Nodes:", len(self.nodes))
        for i in range(len(self.nodes)):
            var node = self.nodes[i].copy()
            if node.type != "removed":
                var preds = self.predecessors(node.id)
                var succs = self.successors(node.id)
                print("[ Node", node.id, "]", node.__str__(), "| PREDS:", preds, "| SUCCS:", succs)
        print("Edges:", len(self.edges))
        print("Operations:", self.count_operation())
        print("Depth:", self.depth())
        print("Topo:")
        var topo = self.topological_sort()
        print("Length topo:", len(topo))
        for i in range(len(topo)):
            print(i, "→", self.nodes[topo[i]].__str__())

    def _sort_by_topo(self, topo: List[Int], nodes: List[Int]) -> List[Int]:
        var res = List[Int]()
        for i in range(len(topo)):
            for j in range(len(nodes)):
                if topo[i] == nodes[j]:
                    res.append(nodes[j])
                    break
        return res^

    def collect_1q_runs(self) -> List[List[Int]]:
        var topo = self.topological_sort()
        var in_collected = List[Bool]()
        for i in range(len(self.nodes)):
            in_collected.append(False)
        var collected = List[List[Int]]()
        for i in range(len(topo)):
            var start = topo[i]
            if in_collected[start]: continue
            if self.nodes[start].type != "gate": continue
            var gate = self.nodes[start].gate.copy()
            if len(gate.qubit) != 1: continue
            if (gate.name == "MEASURE" or
                gate.name == "RESET" or
                gate.name == "BARRIER"): continue
            var q = gate.qubit[0]
            var coll = List[Int]()
            coll.append(start)
            in_collected[start] = True
            var j = i + 1
            while j < len(topo):
                var nid = topo[j]
                if in_collected[nid]: j += 1; continue
                if self.nodes[nid].type != "gate": j += 1; continue
                var ng = self.nodes[nid].gate.copy()
                if len(ng.qubit) != 1 or ng.qubit[0] != q:
                    var uses_q = False
                    for k in range(len(ng.qubit)):
                        if ng.qubit[k] == q:
                            uses_q = True
                    if uses_q: break
                    j += 1
                    continue
                if (ng.name == "MEASURE" or
                    ng.name == "RESET" or
                    ng.name == "BARRIER"): break
                var preds = self.predecessors(nid)
                var pred_on_q: Int = -1
                for k in range(len(preds)):
                    var pid = preds[k]
                    if self.nodes[pid].type == "input": continue
                    var pg = self.nodes[pid].gate.copy()
                    for l in range(len(pg.qubit)):
                        if pg.qubit[l] == q:
                            pred_on_q = pid
                            break
                if pred_on_q == coll[len(coll) - 1]:
                    coll.append(nid)
                    in_collected[nid] = True
                else:
                    break
                j += 1
            if len(coll) >= 1:
                collected.append(coll.copy())
        return collected^

    def collect_2q_runs(self) -> List[List[Int]]:
        var topo = self.topological_sort()
        var in_collected = List[Bool]()
        for i in range(len(self.nodes)):
            in_collected.append(False)
        var collected = List[List[Int]]()
        for i in range(len(topo)):
            var start = topo[i]
            if in_collected[start]: continue
            if self.nodes[start].type != "gate": continue
            var gate = self.nodes[start].gate.copy()
            if len(gate.qubit) != 2: continue
            if (gate.name == "MEASURE" or
                gate.name == "BARRIER" or
                gate.name == "RESET"): continue
            var q0 = gate.qubit[0]
            var q1 = gate.qubit[1]
            var coll = List[Int]()
            var j = i - 1
            while j >= 0:
                var nid = topo[j]
                if in_collected[nid]:
                    j -= 1
                    continue
                if self.nodes[nid].type != "gate":
                    j -= 1
                    continue
                var ng = self.nodes[nid].gate.copy()
                if len(ng.qubit) != 1:
                    j -= 1
                    continue
                var q = ng.qubit[0]
                if q != q0 and q != q1:
                    j -= 1
                    continue
                if (ng.name == "MEASURE" or
                    ng.name == "BARRIER" or
                    ng.name == "RESET"):
                    j -= 1
                    continue
                var succs = self.successors(nid)
                var check = True
                for k in range(len(succs)):
                    var sid = succs[k]
                    if self.nodes[sid].type == "output": continue
                    if sid == start: continue
                    if not in_collected[sid]:
                        check = False
                        break
                if check:
                    coll.append(nid)
                    in_collected[nid] = True
                j -= 1
            coll.append(start)
            in_collected[start] = True
            j = i + 1
            while j < len(topo):
                var nid = topo[j]
                if in_collected[nid]:
                    j += 1
                    continue
                if self.nodes[nid].type != "gate":
                    j += 1
                    continue
                var ng = self.nodes[nid].gate.copy()
                if (ng.name == "MEASURE" or
                    ng.name == "BARRIER" or
                    ng.name == "RESET"):
                    for k in range(len(ng.qubit)):
                        if ng.qubit[k] == q0 or ng.qubit[k] == q1:
                            j = len(topo)
                            break
                    j += 1
                    continue
                var uses_q0 = False
                var uses_q1 = False
                var uses_other = False
                for k in range(len(ng.qubit)):
                    var q = ng.qubit[k]
                    if q == q0: uses_q0 = True
                    elif q == q1: uses_q1 = True
                    else: uses_other = True
                if uses_other:
                    if uses_q0 or uses_q1:
                        break
                    j += 1
                    continue
                var preds = self.predecessors(nid)
                var all_preds_in_coll = True
                for k in range(len(preds)):
                    var pid = preds[k]
                    if self.nodes[pid].type == "input": continue
                    if self.nodes[pid].type == "removed": continue
                    var pg = self.nodes[pid].gate.copy()
                    var pred_on_block = False
                    for l in range(len(pg.qubit)):
                        if pg.qubit[l] == q0 or pg.qubit[l] == q1:
                            pred_on_block = True
                            break
                    if pred_on_block and not in_collected[pid]:
                        all_preds_in_coll = False
                        break
                if all_preds_in_coll:
                    coll.append(nid)
                    in_collected[nid] = True
                else:
                    if uses_q0 or uses_q1:
                        break
                j += 1
            var sorted_coll = self._sort_by_topo(topo, coll)
            var has_2q = False
            for k in range(len(sorted_coll)):
                if len(self.nodes[sorted_coll[k]].gate.qubit) == 2:
                    has_2q = True
                    break
            if has_2q:
                collected.append(sorted_coll.copy())
        return collected^