from transpiler import CouplingMap

struct GateProperties(Copyable, Movable):
    var error: Float64
    var duration: Float64
    var qubits: List[Int]

    def __init__(
        out self,
        error: Float64 = 0.0,
        duration: Float64 = 0.0,
        qubits: List[Int] = List[Int]()
    ):
        self.error = error
        self.duration = duration
        self.qubits = qubits.copy()

struct Target(Copyable, Movable):
    var num_qubits: Int
    var basis_gates: List[String]
    var gate_props: List[Tuple[String, GateProperties]]
    var coupling_map: CouplingMap

    def __init__(
        out self,
        num_qubits: Int,
        coupling_map: CouplingMap,
        basis_gates: List[String] = List[String]()
    ):
        self.num_qubits = num_qubits
        self.coupling_map = coupling_map.copy()
        self.basis_gates = basis_gates.copy()
        self.gate_props = List[Tuple[String, GateProperties]]()
        if len(self.basis_gates) == 0:
            self.basis_gates.append("CX")
            self.basis_gates.append("RZ")
            self.basis_gates.append("SX")
            self.basis_gates.append("X")
            self.basis_gates.append("MEASURE")

    def supports_gate(self, name: String) -> Bool:
        for i in range(len(self.basis_gates)):
            if self.basis_gates[i] == name: return True
        return False

    def needs_decompose(self, name: String) -> Bool:
        return not self.supports_gate(name)

    def add_gate_props(mut self, name: String, props: GateProperties):
        self.gate_props.append((name, props.copy()))

    def get_gate_error(self, name: String) -> Float64:
        for i in range(len(self.gate_props)):
            if self.gate_props[i][0] == name:
                return self.gate_props[i][1].error
        return 0.0

    def get_gate_duration(self, name: String) -> Float64:
        for i in range(len(self.gate_props)):
            if self.gate_props[i][0] == name:
                return self.gate_props[i][1].duration
        return 0.0

    def add_basis_gate(mut self, name: String):
        if not self.supports_gate(name):
            self.basis_gates.append(name)

    def remove_basis_gate(mut self, name: String):
        var new_basis = List[String]()
        for i in range(len(self.basis_gates)):
            if self.basis_gates[i] != name:
                new_basis.append(self.basis_gates[i])
        self.basis_gates = new_basis^

def target_ibm_basis(num_qubits: Int, cm: CouplingMap) -> Target:
    var basis = List[String]()
    basis.append("CX")
    basis.append("RZ")
    basis.append("SX")
    basis.append("X")
    basis.append("MEASURE")
    basis.append("RESET")
    return Target(num_qubits, cm, basis)

def target_custom(num_qubits: Int, cm: CouplingMap, gates: List[String]) -> Target:
    return Target(num_qubits, cm, gates)