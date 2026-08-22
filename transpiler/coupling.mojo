struct CouplingMap(Copyable, Movable):
    var nq: Int
    var edges: List[List[Int]]
    
    def __init__(out self, num_qubits: Int):
        self.nq = num_qubits
        self.edges = List[List[Int]]()
        for _ in range(num_qubits):
            self.edges.append(List[Int]())

    def add_edge(mut self, qsrc: Int, qdst: Int):
        self.edges[qsrc].append(qdst)
        self.edges[qdst].append(qsrc)

    def connected(self, qsrc: Int, qdst: Int) -> Bool:
        for i in range(len(self.edges[qsrc])):
            if self.edges[qsrc][i] == qdst:
                return True
        return False

    def shortest_path(self, src: Int, dst: Int) -> List[Int]:
        var visited = List[Bool]()
        var parent = List[Int]()
        for _ in range(self.nq):
            visited.append(False)
            parent.append(-1)
        var queue = List[Int]()
        queue.append(src)
        visited[src] = True
        var found = False
        var head: Int = 0
        while head < len(queue):
            var curr = queue[head]
            head += 1
            if curr == dst:
                found = True
                break
            for i in range(len(self.edges[curr])):
                var nb = self.edges[curr][i]
                if not visited[nb]:
                    visited[nb] = True
                    parent[nb] = curr
                    queue.append(nb)
        var path = List[Int]()
        if not found:
            return path^
        var curr = dst
        while curr != -1:
            path.append(curr)
            curr = parent[curr]
        var reversed_path = List[Int]()
        for i in range(len(path)):
            reversed_path.append(path[len(path) - 1 - i])
        return reversed_path^
    
    def print_map(self):
        print("Coupling Map:")
        for i in range(self.nq):
            var s = " q" + String(i) + " → ["
            for j in range(len(self.edges[i])):
                if j > 0: s += ","
                s += "q" + String(self.edges[i][j])
            s += "]"
            print(s)

    @staticmethod
    def linear(nq: Int) -> CouplingMap:
        var cm = CouplingMap(nq)
        for i in range(nq - 1):
            cm.add_edge(i, i + 1)
        return cm^
    
    @staticmethod
    def ring(nq: Int) -> CouplingMap:
        var cm = CouplingMap(nq)
        for i in range(nq):
            cm.add_edge(i, (i + 1) % nq)
        return cm^
    
    @staticmethod
    def full(nq: Int) -> CouplingMap:
        var cm = CouplingMap(nq)
        for i in range(nq):
            for j in range(i + 1, nq):
                cm.add_edge(i, j)
        return cm^
    
    @staticmethod
    def manila() -> CouplingMap:
        var cm = CouplingMap(5)
        cm.add_edge(0, 1)
        cm.add_edge(1, 2)
        cm.add_edge(1, 3)
        cm.add_edge(3, 4)
        return cm^