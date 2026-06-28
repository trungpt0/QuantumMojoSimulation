import time

from qiskit import QuantumCircuit
from qiskit.circuit.library import (
    IGate, XGate, YGate, ZGate, HGate,
    SGate, SdgGate, TGate, TdgGate,
    RXGate, RYGate, RZGate, PhaseGate, CXGate,
)
from qiskit.converters import circuit_to_dag
from qiskit.transpiler.passes import (
    RemoveIdentityEquivalent,
    RemoveDiagonalGatesBeforeMeasure,
    InverseCancellation,
    CommutativeInverseCancellation,
    Collect1qRuns,
    Collect2qBlocks,
    ConsolidateBlocks,
)

GATE_MAP = {
    "I":   lambda p: IGate(),
    "X":   lambda p: XGate(),
    "Y":   lambda p: YGate(),
    "Z":   lambda p: ZGate(),
    "H":   lambda p: HGate(),
    "S":   lambda p: SGate(),
    "SDG": lambda p: SdgGate(),
    "T":   lambda p: TGate(),
    "TDG": lambda p: TdgGate(),
    "RX":  lambda p: RXGate(float(p[0])),
    "RY":  lambda p: RYGate(float(p[0])),
    "RZ":  lambda p: RZGate(float(p[0])),
    "P":   lambda p: PhaseGate(float(p[0])),
    "IP":  lambda p: PhaseGate(-float(p[0])),
    "CX":  lambda p: CXGate(),
}

def _run_consolidate(dag):
    from qiskit.transpiler import PropertySet
    prop = PropertySet()
    p1 = Collect1qRuns()
    p2 = Collect2qBlocks()
    p3 = ConsolidateBlocks(force_consolidate=True)
    p1.property_set = prop
    p2.property_set = prop
    p3.property_set = prop
    p1.run(dag)
    p2.run(dag)
    return p3.run(dag)

PASSES_ORDER = [
    ("RemoveIdentityEquivalent",        "no_measure",   lambda dag: RemoveIdentityEquivalent().run(dag)),
    ("RemoveDiagonalGatesBeforeMeasure","with_measure", lambda dag: RemoveDiagonalGatesBeforeMeasure().run(dag)),
    ("InverseCancellation",             "no_measure",   lambda dag: InverseCancellation().run(dag)),
    ("CommutativeInverseCancellation",  "no_measure",   lambda dag: CommutativeInverseCancellation().run(dag)),
    ("ConsolidateBlocks",               "no_measure",   _run_consolidate),
]

OUTPUT_FILE = "results/optimization_transpiler/data/exe_timing_qiskit_data.txt"

def circuit_from_parse(path: str) -> dict[int, tuple[QuantumCircuit, QuantumCircuit]]:
    blocks: list[tuple[int, list[tuple[str, list[str]]]]] = []
    with open(path, "r") as f:
        lines = [ln.strip() for ln in f if ln.strip()]
    current_qubits: int | None = None
    current_gates: list[tuple[str, list[str]]] = []
    for line in lines:
        if line.startswith("Qubits"):
            if current_qubits is not None:
                blocks.append((current_qubits, current_gates))
            current_qubits = int(line.split()[1])
            current_gates = []
        elif line.startswith("Gate"):
            tokens = line.split()
            gate_name = tokens[1].upper()
            rest = tokens[2:]
            current_gates.append((gate_name, rest))
    if current_qubits is not None:
        blocks.append((current_qubits, current_gates))
    seen: dict[int, list] = {}
    for num_q, gates in blocks:
        seen.setdefault(num_q, []).append(gates)

    def build_circuit(num_q: int, gate_list: list[tuple[str, list[str]]],
                      include_measure: bool) -> QuantumCircuit:
        from qiskit import ClassicalRegister
        qc = QuantumCircuit(num_q)
        for gate_name, rest in gate_list:
            if gate_name == "MEASURE":
                if include_measure:
                    qubit = int(rest[0])
                    qc.add_register(ClassicalRegister(1))
                    qc.measure(qubit, qc.num_clbits - 1)
                continue
            if gate_name == "MEASURE_ALL":
                if include_measure:
                    qc.measure_all()
                continue
            if gate_name not in GATE_MAP:
                raise ValueError(f"Unknown gate: {gate_name}")
            qubit_indices: list[int] = []
            params: list[str] = []
            for token in rest:
                try:
                    qubit_indices.append(int(token))
                except ValueError:
                    params.append(token)
            gate = GATE_MAP[gate_name](params)
            qc.append(gate, qubit_indices)
        return qc

    result: dict[int, tuple[QuantumCircuit, QuantumCircuit]] = {}
    for num_q, gate_lists in seen.items():
        circuit_no_measure   = build_circuit(num_q, gate_lists[0], include_measure=False)
        circuit_with_measure = build_circuit(num_q, gate_lists[1], include_measure=True)
        result[num_q] = (circuit_no_measure, circuit_with_measure)
    return result

N_RUNS = 50
def time_pass(run_fn, qc: QuantumCircuit) -> int:
    samples: list[int] = []
    for _ in range(N_RUNS):
        dag = circuit_to_dag(qc)
        t0 = time.perf_counter_ns()
        run_fn(dag)
        t1 = time.perf_counter_ns()
        samples.append(t1 - t0)
    return round(sum(samples) / N_RUNS)

def time_optimization_pass_run():
    circuits = circuit_from_parse("results/optimization_transpiler/data/circuit_data.txt")
    for nq, (qc_no_meas, qc_with_meas) in circuits.items():
        with open(OUTPUT_FILE, "a") as f:
            f.write(f"Qubits {nq}\n")
        for pass_name, circuit_type, run_fn in PASSES_ORDER:
            qc = qc_no_meas if circuit_type == "no_measure" else qc_with_meas
            elapsed = time_pass(run_fn, qc)
            with open(OUTPUT_FILE, "a") as f:
                f.write(f"{pass_name} {elapsed}\n")

def main():
    with open(OUTPUT_FILE, "w"):
        pass
    time_optimization_pass_run()

if __name__ == '__main__':
    main()