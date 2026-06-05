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
class GateEntry:
    name: str
    qubits: list[int]
    params: list[float] = field(default_factory=list)

    def __str__(self):
        s = self.name
        if self.params:
            s += f"({', '.join(f'{p:.6f}' for p in self.params)})"
        s += f" q{self.qubits}"
        return s

@dataclass
class TestCase:
    index: int
    num_qubits: int
    gates_before: list[GateEntry]
    gates_after: list[GateEntry]

def parse_gate_line(line: str) -> Optional[GateEntry]:
    import re
    line = re.sub(r'^Gate(Before|After)\s+', '', line.strip())
    parts = line.split()
    if not parts:
        return None
 
    name = parts[0].upper()
    rest = parts[1:]
 
    if name in ('RX', 'RY', 'RZ', 'P', 'IP'):
        return GateEntry(name, [int(rest[0])], [float(rest[1])])
    elif name == 'CX':
        return GateEntry(name, [int(rest[0]), int(rest[1])])
    else:
        return GateEntry(name, [int(rest[0])])

def parse_file(path: str) -> list[TestCase]:
    test_cases = []
    current_qubits = None
    gates_before: list[GateEntry] = []
    gates_after:  list[GateEntry] = []
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
            gates_after  = []
        elif line.startswith('GateBefore'):
            e = parse_gate_line(line)
            if e: gates_before.append(e)
        elif line.startswith('GateAfter'):
            e = parse_gate_line(line)
            if e: gates_after.append(e)
    flush()
    return test_cases

def add_gate(qc: QuantumCircuit, gate: GateEntry) -> bool:
    n = gate.name
    q = gate.qubits
    p = gate.params
    try:
        match n:
            case 'I':   qc.id(q[0])
            case 'X':   qc.x(q[0])
            case 'Y':   qc.y(q[0])
            case 'Z':   qc.z(q[0])
            case 'H':   qc.h(q[0])
            case 'S':   qc.s(q[0])
            case 'SDG': qc.sdg(q[0])
            case 'T':   qc.t(q[0])
            case 'TDG': qc.tdg(q[0])
            case 'CX':
                if q[0] == q[1]:
                    return False
                qc.cx(q[0], q[1])
            case 'RX':  qc.rx(p[0], q[0])
            case 'RY':  qc.ry(p[0], q[0])
            case 'RZ':  qc.rz(p[0], q[0])
            case 'P':  qc.p(p[0], q[0])
            case 'IP':  qc.p(-p[0], q[0])
            case _:
                print(f"    [WARN] Unknown gate '{n}', skipping")
                return True
    except Exception as e:
        print(f"    [WARN] Failed to add {gate}: {e}")
        return False
    return True

def build_circuit(num_qubits: int, gates: list[GateEntry]) -> tuple[QuantumCircuit, list[str]]:
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
    """Compact string representation of each instruction in a circuit."""
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
    """Return (match, diff_lines)."""
    if mojo == qiskit:
        return True, []
    diffs = []
    max_len = max(len(mojo), len(qiskit))
    for i in range(max_len):
        m = mojo[i]   if i < len(mojo)   else "<missing>"
        q = qiskit[i] if i < len(qiskit) else "<missing>"
        if m != q:
            diffs.append(f"    [{i:02d}] Mojo: {m}")
            diffs.append(f"         Qiskit: {q}")
    return False, diffs

def run_qiskit_pass(qc: QuantumCircuit) -> QuantumCircuit:
    pm = PassManager([RemoveIdentityEquivalent()])
    return pm.run(qc)

P = "✓"
F = "✗"
W = "⚠"

def verify(tc: TestCase) -> dict:
    r = dict(
        index=tc.index,
        num_qubits=tc.num_qubits,
        n_before=len(tc.gates_before),
        n_mojo=len(tc.gates_after),
        n_qiskit=0,
        equiv_unitary=False,
        fidelity=0.0,
        equiv_gates=False,
        gate_diffs=[],
        skipped=False,
        skip_reason="",
    )
    print(f"\n{'═'*62}")
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
    print(f"  Qiskit pass result gate count : {r['n_qiskit']}")
    qc_mojo, _ = build_circuit(tc.num_qubits, tc.gates_after)
    mojo_gates   = gate_list(qc_mojo)
    qiskit_gates = gate_list(qc_qiskit)
    match, diffs = compare_gate_lists(mojo_gates, qiskit_gates)
    r['equiv_gates'] = match
    r['gate_diffs']  = diffs
 
    sym = P if match else F
    print(f"  {sym} Gate-by-gate match with Qiskit pass : {'YES' if match else 'NO'}")
    if diffs:
        print(f"     Differences (Mojo vs Qiskit):")
        for d in diffs[:20]:   # cap at 20 lines
            print(d)
        if len(diffs) > 20:
            print(f"     ... ({len(diffs)//2} more differences)")
    equiv, fid = unitary_equivalent(qc_before, qc_mojo)
    r['equiv_unitary'] = equiv
    r['fidelity']      = fid
    sym2 = P if equiv else F
    print(f"  {sym2} Unitary equivalence (before ≡ mojo_after) : "
          f"{'YES' if equiv else 'NO'}  fidelity={fid:.8f}")
    if tc.num_qubits <= 3 and r['n_before'] <= 10:
        for label, circ in [("BEFORE", qc_before), ("QISKIT", qc_qiskit), ("MOJO", qc_mojo)]:
            print(f"\n  [{label}]")
            print(circ.draw(output='text', fold=-1))
 
    return r

def main():
    path = sys.argv[1]
    test_cases = parse_file(path)
    print(f"Parsed {len(test_cases)} test case(s)\n")
    results = [verify(tc) for tc in test_cases]

if __name__ == "__main__":
    main()