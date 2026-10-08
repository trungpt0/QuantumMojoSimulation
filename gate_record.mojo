struct ApplyGateLog(Copyable, Movable):
    var gate_name: String
    var q0: Int
    var q1: Int
    var theta: Float64

    def __init__(out self, gate_name: String, q0: Int = -1, q1: Int = -1, theta: Float64 = 0.0):
        self.gate_name = gate_name
        self.q0 = q0
        self.q1 = q1
        self.theta = theta

struct ApplyUnitaryGateLog(Copyable, Movable):
    var gate_name: String
    var qubits: List[Int]
    var params: List[Float64]

    def __init__(out self, gate_name: String, qubits: List[Int], params: List[Float64]):
        self.gate_name = gate_name
        self.qubits = qubits.copy()
        self.params = params.copy()