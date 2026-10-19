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
            for g in ["CX", "RZ", "SX", "X", "MEASURE", "RESET"]:
                self.basis_gates.append(g)

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

    def has_ccx(self) -> Bool: return self.supports_gate("CCX")
    def has_cx(self) -> Bool: return self.supports_gate("CX")
    def has_t(self) -> Bool: return self.supports_gate("T") or self.supports_gate("TDG")
    def has_rz(self) -> Bool: return self.supports_gate("RZ")
    def has_swap(self) -> Bool: return self.supports_gate("SWAP")
    def has_cp(self) -> Bool: return self.supports_gate("CP")
    def has_crx(self) -> Bool: return self.supports_gate("CRX")
    def has_cry(self) -> Bool: return self.supports_gate("CRY")
    def has_crz(self) -> Bool: return self.supports_gate("CRZ")

def target_ibm_basis(num_qubits: Int, cm: CouplingMap) -> Target:
    var basis = List[String]()
    for g in ["CX", "RZ", "SX", "X", "MEASURE", "RESET"]: basis.append(g)
    return Target(num_qubits, cm, basis)

def target_ibm_ecr(num_qubits: Int, cm: CouplingMap) -> Target:
    var basic = List[String]()
    for g in ["ECR", "RZ", "SX", "X", "MEASURE"]: basic.append(g)
    return Target(num_qubits, cm, basic)

def target_clifford_t(num_qubits: Int, cm: CouplingMap) -> Target:
    var basic = List[String]()
    for g in ["CX", "H", "T", "TDG", "S", "SDG", "X", "Y", "Z", "MEASURE"]: basic.append(g)
    return Target(num_qubits, cm, basic)

def target_universal(num_qubits: Int, cm: CouplingMap) -> Target:
    var basic = List[String]()
    for g in ["CX","CCX","U","RZ","RY","RX","H","S","SDG","T","TDG",
              "SX","X","Y","Z","SWAP","CP","CRZ","CRY","CRX","MEASURE"]:
        basic.append(g)
    return Target(num_qubits, cm, basic)

def target_custom(num_qubits: Int, cm: CouplingMap, gates: List[String]) -> Target:
    return Target(num_qubits, cm, gates)