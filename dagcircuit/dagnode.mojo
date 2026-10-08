from gates import GateOp

struct DAGNode(Copyable, Movable):
    var id: Int
    var gate: GateOp
    var type: String

    def __init__(out self, id: Int, gate: GateOp, type: String = "gate"):
        self.id = id
        self.gate = gate.copy()
        self.type = type

    def __str__(self) -> String:
        return "Type: " + self.type + " | Gate: " + self.gate.__str__()

struct DAGEdge(Copyable, Movable):
    var src: Int
    var dst: Int
    var qubit: Int

    def __init__(out self, src: Int, dst: Int, qubit: Int):
        self.src = src
        self.dst = dst
        self.qubit = qubit