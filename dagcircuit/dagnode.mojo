from gates import GateOp

struct DAGNode(Copyable, Moveable):
    var id: Int
    var gate: GateOp
    var type: String

    def __init__(out self, id: Int, gate: GateOp, type: String = "gate"):
        self.id = id
        self.gate = gate
        self.type = type

    def __copy__(self) -> Self:
        var node = DAGNode.__new__(DAGNode)
        node.id = self.id
        node.gate = self.gate
        node.type = self.type
        return node^

    def __moveinit__(out self, owned other: Self):
        self.id = other.id
        self.gate = other.gate^
        self.type = other.type^

    def __str__(self) -> String:
        return self.type + "(" + String(self.id) + "): " + str(self.gate)

struct DAGEdge(Copyable, Moveable):
    var src: Int
    var dst: Int
    var qubit: Int

    def __init__(out self, src: Int, dst: Int, qubit: Int):
        self.src = src
        self.dst = dst
        self.qubit = qubit

    def __copy__(self) -> Self:
        var edge = DAGEdge.__new__(DAGEdge)
        edge.src = self.src
        edge.dst = self.dst
        edge.qubit = self.qubit
        return edge^

    def __moveinit__(out self, owned other: Self):
        self.src = other.src
        self.dst = other.dst
        self.qubit = other.qubit