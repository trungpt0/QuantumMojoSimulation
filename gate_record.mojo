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

    def __copy__(self) -> Self:
        var new_log = ApplyGateLog.__new__(ApplyGateLog)
        new_log.gate_name = self.gate_name
        new_log.q0 = self.q0
        new_log.q1 = self.q1
        new_log.theta = self.theta
        return new_log

    def __moveinit__(out self, owned other: Self):
        self.gate_name = other.gate_name
        self.q0 = other.q0
        self.q1 = other.q1
        self.theta = other.theta

struct ApplyUnitaryGateLog(Copyable, Movable):
    var gate_name: String
    var qubits: List[Int]
    var params: List[Float64]

    def __init__(out self, gate_name: String, qubits: List[Int], params: List[Float64]):
        self.gate_name = gate_name
        self.qubits = qubits.copy()
        self.params = params.copy()

    def __copy__(self) -> Self:
        var new_log = ApplyUnitaryGateLog.__new__(ApplyUnitaryGateLog)
        new_log.gate_name = self.gate_name
        new_log.qubits = self.qubits.copy()
        new_log.params = self.params.copy()
        return new_log^

    def __moveinit__(out self, owned other: Self):
        self.gate_name = other.gate_name
        self.qubits = other.qubits^
        self.params = other.params^