from dagcircuit import DAGCircuit
from gates import GateOp

struct CommutativeInverseCancellation:
    
    def __init__(out self):
        pass
    
    def _are_inverses(self, g1: GateOp, g2: GateOp) -> Bool:
        if len(g1.qubit) != len(g2.qubit): return False
        for i in range(len(g1.qubit)):
            if g1.qubit[i] != g2.qubit[i]: return False
        if g1.name == "H" and g2.name == "H": return True
        if g1.name == "X" and g2.name == "X": return True
        if g1.name == "Y" and g2.name == "Y": return True
        if g1.name == "Z" and g2.name == "Z": return True
        if g1.name == "CX" and g2.name == "CX": return True
        if g1.name == "S" and g2.name == "SDG": return True
        if g1.name == "SDG" and g2.name == "S": return True
        if g1.name == "T" and g2.name == "TDG": return True
        if g1.name == "TDG" and g2.name == "T": return True
        return False

    def _commute_past(self, dag: DAGCircuit, src: Int, dst: Int) -> Bool:
        var visited = List[Bool]()
        for i in range(len(dag.nodes)):
            visited.append(False)
        var queue = List[Int]()
        var succs = dag.successors(src)
        for i in range(len(succs)):
            if succs[i] != dst:
                queue.append(succs[i])
                visited[succs[i]] = True
        var head = 0
        while head < len(queue):
            var curr = queue[head]
            head += 1
            if curr == dst: continue
            if dag.nodes[curr].type == "gate":
                if self._same_qubits(dag.nodes[src].gate, dag.nodes[curr].gate): return False
            var next_succs = dag.successors(curr)
            for i in range(len(next_succs)):
                if not visited[next_succs[i]]:
                    visited[next_succs[i]] = True
                    queue.append(next_succs[i])
        return True

    def run(self, owned dag: DAGCircuit) -> DAGCircuit:
        var changed = True
        while changed:
            change = False
            var topo = topological_sort()
            for i in range(len(topo)):
                var nid = topo[i]
                if dag.nodes[nid].type == "removed": continue
                for j in range(i + 1, len(topo)):
                    var cnid = topo[j]
                    if dag.nodes[cnid].type == "removed": continue
                    if not self._are_inverses(dag.nodes[nid].gate, dag, nodes[cnid].gate): continue
                    if self._commute_past(dag, nid, cnid):
                        dag.remove_operation(nid)
                        dag.remove_operation(cnid)
                        changed = True
                        break
                if changed: break
        return dag^
        

