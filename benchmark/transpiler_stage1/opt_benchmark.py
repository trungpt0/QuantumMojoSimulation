import sys
import math
import numpy as np
from dataclasses import dataclass, field
from typing import Optional

from qiskit import QuantumCircuit
from qiskit.quantum_info import Operator, process_fidelity
from qiskit.transpiler import PassManager
from qiskit.transpiler.passes import RemoveIdentityEquivalent

@dataclass
class Gate:
    name: str
    qubits: list[int]
    params: list[float] = field(default_factory=list)

@dataclass
class TestCase:
    index: int
    num_qubits: int
    gates_before: list[Gate]
    gates_after: list[Gate]

def parse_gate_line(line: str) -> Optional[Gate]:
    import re
    line = re.sub(r'Gate(Before|After)\s+', '', line.strip())
    parts = line.split()
    if not parts:
        return None
    name = parts[0].upper()
    rest = parts[1:]
    if name in ('RX', 'RY', 'RZ', 'P', 'IP'):
        return Gate(name, [int(rest[0])], [float(rest[1])])
    elif name == 'CX':
        return Gate(name, [int(rest[0]), int(rest[1])])
    else:
        return Gate(name, [int(rest[0])])

def parse_file(path: str) -> list[TestCase]:
    test_cases = []
    current_qubits = None
    gates_before: list[Gate] = []
    gates_after: list[Gate] = []
    idx = 0
    with open(path) as f:
        lines = [l.strip() for l in f if l.strip()]
    def flush():
        nonlocal current_qubits, gates_before, gates_after, idx
        if current_qubits is not None:
            test_cases.append(TestCase(idx, current_qubits, gates_before, gates_after))
            idx += 1
    for line in lines:
        if line.startswith('Qubits'):
            flush()
            current_qubits = int(line.split()[1])
            gates_before = []
            gates_after = []
        elif line.startswith('GateBefore'):
            e = parse_gate_line(line)
            if e: gates_before.append(e)
        elif line.startswith('GateAfter'):
            e = parse_gate_line(line)
            if e: gates_after.append(e)
    flush()
    return test_cases

def add_gate(qc: QuantumCircuit, gate: Gate) -> bool:
    n = gate.name
    q = gate.qubits
    p = gate.params
    try:
        match n:
            case 'I': qc.id(q[0])
            case 'X': qc.x(q[0])
            case 'Y': qc.y(q[0])
            case 'Z': qc.z(q[0])
            case 'H': qc.h(q[0])
            case 'S': qc.s(q[0])
            case 'SDG': qc.sdg(q[0])
            case 'T': qc.t(q[0])
            case 'TDG': qc.tdg(q[0])
            case 'RX': qc.rx(p[0], q[0])
            case 'RY': qc.ry(p[0], q[0])
            case 'RZ': qc.rz(p[0], q[0])
            case 'p': qc.p(p[0], q[0])
            case 'IP': qc.p(-p[0], q[0])
            case 'CX':
                if q[0] == q[1]:
                    return False
                qc.cx(q[0], q[1])
            case _:
                print(f"    [WARN] Unknown gate '{n}', skipping")
                return True
    except Exception as e:
        print(f"    [WARN] Failed to add {gate}: {e}")
        return False
    return True

def build_circuit(num_qubits: int, gates: list[Gate]) -> tuple[QuantumCircuit, list[str]]:
    qc = QuantumCircuit(num_qubits)
    warnings = []
    for g in gates:
        if not add_gate(qc, g):
            warnings.append(f"Invalid gate skipped: {g}")
    return qc, warnings

def unitary_equivalent(qc1: QuantumCircuit, qc2: QuantumCircuit, tol: float = 1e-6) -> tuple[bool, float]:
    try:
        fid = abs(process_fidelity(Operator(qc1), Operator(qc2)))
        return fid >= 1.0 - tol, fid
    except Exception as e:
        return False, 0.0

def gate_list(qc: QuantumCircuit) -> list[str]:
    result = []
    for instr in qc.data:
        name = instr.operation.name.upper()
        qubits = [qc.find_bit(q).index for q in instr.qubits]
        params = [round(float(p), 8) for p in instr.operation.params]
        s = name
        if params:
            s += f"({params})"
        s += f" {qubits}"
        result.append(s)
    return result

def compare_gate_lists(mojo: list[str], qiskit: list[str]) -> tuple[bool, list[str]]:
    if mojo == qiskit:
        return True, []
    diffs = []
    max_len = max(len(mojo), len(qiskit))
    for i in range(max_len):
        m = mojo[i] if i < len(mojo) else "<missing>"
        q = qiskit[i] if i < len(qiskit) else "<missing>"
        if m != q:
            diffs.append(f"    [{i:02d}] Mojo: {m}")
            diffs.append(f"         Qiskit: {q}")
    return False, diffs

def instruction_key(instr, qc: QuantumCircuit) -> str:
    name = instr.operation.name.upper()
    qubits = sorted(qc.find_bit(q).index for q in instr.qubits)
    params = [round(float(p), 6) for p in instr.operation.params]
    return f"{name}|{qubits}|{params}"

def circuit_to_dag_layers(qc: QuantumCircuit) -> list[list[str]]:
    last_layer: dict[int, int] = {}
    layers: list[list[str]] = []
    for instr in qc.data:
        used_qubits = [qc.find_bit(q).index for q in instr.qubits]
        min_layer = max((last_layer.get(q, -1) for q in used_qubits), default=-1) + 1
        while len(layers) <= min_layer:
            layers.append([])
        key = instruction_key(instr, qc)
        layers[min_layer].append(key)
        for q in used_qubits:
            last_layer[q] = min_layer
    return [sorted(layer) for layer in layers]

def compare_dag_layers(layers_mojo: list[list[str]], layers_qiskit: list[list[str]]) -> tuple[bool, list[str]]:
    if layers_mojo == layers_qiskit:
        return True, []
    diffs = []
    n = max(len(layers_mojo), len(layers_qiskit))
    for i in range(n):
        lm = layers_mojo[i] if i < len(layers_mojo) else []
        lq = layers_qiskit[i] if i < len(layers_qiskit) else []
        if lm != lq:
            diffs.append(f"    Layer {i}:")
            only_m = sorted(set(lm) - set(lq))
            only_q = sorted(set(lq) - set(lm))
            if only_m:
                diffs.append(f"      Mojo only  : {only_m}")
            if only_q:
                diffs.append(f"      Qiskit only: {only_q}")
    return False, diffs

def run_qiskit_pass(qc: QuantumCircuit) -> QuantumCircuit:
    pm = PassManager([RemoveIdentityEquivalent()])
    return pm.run(qc)

P = "✓"
F = "✗"
W = "⚠"

def verify(tc: TestCase) -> dict():
    r = dict(
        index = tc.index,
        num_qubits = tc.num_qubits,
        n_before = len(tc.gates_before),
        n_mojo = len(tc.gates_after),
        n_qiskit = 0,
        equiv_layers = False,
        equiv_uniraty = False,
        fidelity = 0.0,
        equiv_gates = False,
        layer_diffs = [],
        skipped = False,
        skip_reason = "",
    )
    print(f"\n{'='*62}")
    print(f"  Test #{tc.index+1}  |  Qubits: {tc.num_qubits}  |  "
          f"GateBefore: {len(tc.gates_before)}  GateAfter(Mojo): {len(tc.gates_after)}")
    qc_before, warns = build_circuit(tc.num_qubits, tc.gates_before)
    for w in warns:
        print(f"  {w} {w}")
        if "Invalid" in w:
            r['skipped'] = True
            r['skip_reason'] = w
    if r['skipped']:
        print(f"  {w} Skipped (invalid gate in input)")
        return r
    qc_qiskit = run_qiskit_pass(qc_before)
    r['n_qiskit'] = len(qc_qiskit.data)
    print(f"  Gate count → Qiskit: {r['n_qiskit']} | Mojo: {r['n_mojo']}")
    qc_mojo, _ = build_circuit(tc.num_qubits, tc.gates_after)
    layers_qiskit = circuit_to_dag_layers(qc_qiskit)
    layers_mojo = circuit_to_dag_layers(qc_mojo)
    match, diffs = compare_dag_layers(layers_mojo, layers_qiskit)
    r['equiv_layers'] = match
    r['layer_diffs']  = diffs
    print(f"  {P if match else F} DAG layer match (Mojo == Qiskit pass) : {'YES' if match else 'NO'}")
    if diffs:
        print(f"     Differing layers:")
        for d in diffs[:30]:
            print(d)
        if len(diffs) > 30:
            print(f"     ... ({len(diffs)//2} more differences)")
    equiv, fid = unitary_equivalent(qc_before, qc_mojo)
    r['equiv_unitary'] = equiv
    r['fidelity']      = fid
    sym2 = P if equiv else F
    print(f"  {sym2} Unitary equivalence (before ≡ mojo_after) : "
          f"{'YES' if equiv else 'NO'}  fidelity={fid:.8f}")
    # if tc.num_qubits <= 3 and r['n_before'] <= 10:
    for label, circ in [("BEFORE", qc_before), ("QISKIT", qc_qiskit), ("MOJO", qc_mojo)]:
        print(f"\n  [{label}]")
        print(circ.draw(output='text', fold=-1))
    return r

def main():
    path = sys.argv[1]
    test_cases = parse_file(path)
    print(f"Parsed {len(test_cases)} test case(s)\n")
    results = [verify(tc) for tc in test_cases]
    print(f"\n{'═'*72}")
    print(f"{'#':>3}  {'Q':>2}  {'Before':>7}  {'Mojo':>5}  {'Qiskit':>7}  "
          f"{'LayerMatch':>11}  {'Unitary':>8}  {'Fidelity':>10}")
    print('─' * 72)
    total = len(results)
    n_layer = n_unitary = n_skip = 0
    for r in results:
        if r['skipped']:
            n_skip += 1
            print(f"{r['index']+1:>3}  {r['num_qubits']:>2}  {r['n_before']:>7}  "
                  f"{r['n_mojo']:>5}  {'?':>7}  {'⚠ skip':>11}  {'⚠ skip':>8}  {'—':>10}")
            continue
        lm = P if r['equiv_layers'] else F
        un = P if r['equiv_unitary'] else F
        if r['equiv_layers']:   n_layer   += 1
        if r['equiv_unitary']:  n_unitary += 1
        print(f"{r['index']+1:>3}  {r['num_qubits']:>2}  {r['n_before']:>7}  "
              f"{r['n_mojo']:>5}  {r['n_qiskit']:>7}  "
              f"{lm:>11}  {un:>8}  {r['fidelity']:>10.6f}")
    valid = total - n_skip
    print(f"\n  DAG layer match : {n_layer}/{valid}")
    print(f"  Unitary correct : {n_unitary}/{valid}")
    if n_skip:
        print(f"  Skipped         : {n_skip} (invalid gate in input)")
    all_ok = (n_layer == valid) and (n_unitary == valid)
    print(f"\n{'✓ ALL TESTS PASSED' if all_ok else '✗ SOME TESTS FAILED'}")
    if not all_ok:
        sys.exit(1)

if __name__ == "__main__":
    main()