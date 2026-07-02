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

GATE_NAME_MAP = {
    "id":    "I",
    "x":     "X",
    "y":     "Y",
    "z":     "Z",
    "h":     "H",
    "s":     "S",
    "sdg":   "SDG",
    "t":     "T",
    "tdg":   "TDG",
    "rx":    "RX",
    "ry":    "RY",
    "rz":    "RZ",
    "p":     "P",
    "cx":    "CX",
    "measure": "MEASURE",
}

N_RUNS = 30
N_ITER = 500
PASS_DEFS = [
    ("RemoveIdentityEquivalent",        "no_measure"),
    ("RemoveDiagonalGatesBeforeMeasure","with_measure"),
    ("InverseCancellation",             "no_measure"),
    ("CommutativeInverseCancellation",  "no_measure"),
    ("ConsolidateBlocks",               "no_measure"),
    ("AllOptimization",                 "no_measure"),
]

OUTPUT_FILE = "results/optimization_transpiler/data/exe_timing_qiskit_data.txt"
CIRCUIT_VERIFY = "results/optimization_transpiler/data/circuit_data_qiskit.txt"

def _run_remove_identity(dag):
    RemoveIdentityEquivalent().run(dag)
 
def _run_remove_diagonal(dag):
    RemoveDiagonalGatesBeforeMeasure().run(dag)
 
def _run_inverse_cancellation(dag):
    InverseCancellation().run(dag)
 
def _run_commutative(dag):
    CommutativeInverseCancellation().run(dag)
 
def _run_consolidate(dag):
    from qiskit.transpiler import PropertySet
    prop = PropertySet()
    p1, p2, p3 = Collect1qRuns(), Collect2qBlocks(), ConsolidateBlocks(force_consolidate=True)
    p1.property_set = p2.property_set = p3.property_set = prop
    p1.run(dag); p2.run(dag); p3.run(dag)
 
def _run_all(dag):
    from qiskit.transpiler import PropertySet
    RemoveIdentityEquivalent().run(dag)
    InverseCancellation().run(dag)
    CommutativeInverseCancellation().run(dag)
    prop = PropertySet()
    p1, p2, p3 = Collect1qRuns(), Collect2qBlocks(), ConsolidateBlocks(force_consolidate=True)
    p1.property_set = p2.property_set = p3.property_set = prop
    p1.run(dag); p2.run(dag); p3.run(dag)

PASS_RUNNERS = {
    "RemoveIdentityEquivalent":        _run_remove_identity,
    "RemoveDiagonalGatesBeforeMeasure":_run_remove_diagonal,
    "InverseCancellation":             _run_inverse_cancellation,
    "CommutativeInverseCancellation":  _run_commutative,
    "ConsolidateBlocks":               _run_consolidate,
    "AllOptimization":                 _run_all,
}

def parse_blocks(path: str) -> list[tuple[int, list[tuple[str, list[str]]]]]:
    blocks = []
    current_qubits = None
    current_gates  = []
    with open(path) as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("Qubits"):
                if current_qubits is not None:
                    blocks.append((current_qubits, current_gates))
                current_qubits = int(line.split()[1])
                current_gates  = []
            elif line.startswith("Gate"):
                tokens    = line.split()
                gate_name = tokens[1].upper()
                rest      = tokens[2:]
                current_gates.append((gate_name, rest))
    if current_qubits is not None:
        blocks.append((current_qubits, current_gates))
    return blocks

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
        qubit_indices, params = [], []
        for token in rest:
            try:
                qubit_indices.append(int(token))
            except ValueError:
                params.append(token)
        qc.append(GATE_MAP[gate_name](params), qubit_indices)
    return qc

def qc_to_mojo_str(qc: QuantumCircuit, num_q: int) -> str:
    lines = [f"Qubits {num_q}"]
    for inst in qc.data:
        gate      = inst.operation
        mojo_name = GATE_NAME_MAP.get(gate.name.lower())
        if mojo_name is None:
            continue
        qidx = [qc.find_bit(q).index for q in inst.qubits]
        if mojo_name == "MEASURE":
            lines.append(f"Gate MEASURE {qidx[0]}")
        elif mojo_name == "CX":
            lines.append(f"Gate CX {qidx[0]} {qidx[1]}")
        elif mojo_name in ("RX", "RY", "RZ", "P"):
            lines.append(f"Gate {mojo_name} {qidx[0]} {gate.params[0]}")
        else:
            lines.append(f"Gate {mojo_name} {qidx[0]}")
    return "\n".join(lines) + "\n"

def time_pass_list(run_fn, circuits: list[QuantumCircuit]) -> int:
    total = 0
    for qc in circuits:
        dt = 0
        for _ in range(N_ITER):
            dag = circuit_to_dag(qc)
            t0  = time.perf_counter_ns()
            run_fn(dag)
            t1  = time.perf_counter_ns()
            dt += t1 - t0
        dts = dt // N_ITER
        total += dts
    return round(total / len(circuits))
 
def time_optimization_pass_run(circuit_path: str):
    all_blocks = parse_blocks(circuit_path)
    qubit_sizes = []
    seen_order  = {}
    for num_q, gates in all_blocks:
        if num_q not in seen_order:
            seen_order[num_q] = []
            qubit_sizes.append(num_q)
        seen_order[num_q].append(gates)
    with open(CIRCUIT_VERIFY, "w"):
        pass
    for num_q in qubit_sizes:
        gate_lists = seen_order[num_q]
        n_passes   = len(PASS_DEFS)
        if len(gate_lists) < n_passes * N_RUNS:
            print(f"[WARN] Qubits {num_q}: has {len(gate_lists)} blocks, "
                  f"need {n_passes * N_RUNS}")
        with open(OUTPUT_FILE, "a") as f:
            f.write(f"Qubits {num_q}\n")
        for i, (pass_name, circuit_type) in enumerate(PASS_DEFS):
            include_measure = (circuit_type == "with_measure")
            chunk = gate_lists[i * N_RUNS : (i + 1) * N_RUNS]
            circuits = [build_circuit(num_q, gl, include_measure) for gl in chunk]
            with open(CIRCUIT_VERIFY, "a") as f:
                for circ in circuits:
                    f.write(qc_to_mojo_str(circ, num_q))
            run_fn  = PASS_RUNNERS[pass_name]
            elapsed = time_pass_list(run_fn, circuits)
            with open(OUTPUT_FILE, "a") as f:
                f.write(f"{pass_name} {elapsed}\n")

def main():
    with open(OUTPUT_FILE, "w"):
        pass
    time_optimization_pass_run("results/optimization_transpiler/data/circuit_data.txt")

if __name__ == '__main__':
    main()