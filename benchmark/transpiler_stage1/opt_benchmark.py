import re
import sys
import argparse
import numpy as np
from dataclasses import dataclass, field
from typing import Optional

from qiskit import QuantumCircuit
from qiskit.quantum_info import Operator, process_fidelity
from qiskit.transpiler import PassManager
from qiskit.circuit.library import UnitaryGate

def _import(name):
    for mod in ['qiskit.transpiler.passes',
                'qiskit.transpiler.passes.optimization']:
        try:
            return getattr(__import__(mod, fromlist=[name]), name)
        except (ImportError, AttributeError):
            pass
    raise ImportError(f"Cannot import {name}")

RemoveIdentityEquivalent          = _import('RemoveIdentityEquivalent')
RemoveDiagonalGatesBeforeMeasure  = _import('RemoveDiagonalGatesBeforeMeasure')
Collect1qRuns                     = _import('Collect1qRuns')
Collect2qBlocks                   = _import('Collect2qBlocks')
ConsolidateBlocks                 = _import('ConsolidateBlocks')

try:
    Split2QUnitaries = _import('Split2QUnitaries')
except ImportError:
    Split2QUnitaries = None

try:
    _IC = _import('InverseCancellation')
    try:
        _IC()
        def _make_IC(): return _IC()
    except TypeError:
        from qiskit.circuit.library import (XGate, YGate, ZGate, HGate,
            SGate, SdgGate, TGate, TdgGate, CXGate)
        _gates = [XGate(), YGate(), ZGate(), HGate(),
                  SGate(), SdgGate(), TGate(), TdgGate(), CXGate()]
        def _make_IC(): return _IC(_gates)
except ImportError:
    _make_IC = None

try:
    _CIC = _import('CommutativeInverseCancellation')
    def _make_CIC(): return _CIC()
except ImportError:
    _make_CIC = None

STRUCTURAL_PASSES = {
    'RemoveIdentityEquivalent',
    'RemoveDiagonalGatesBeforeMeasure',
    'InverseCancellation',
}

UNITARY_PASSES = {
    'CommutativeInverseCancellation',
    'Collect1qRuns',
    'Collect2qBlocks',
    'ConsolidateBlocks',
    'Split2QUnitaries',
}

UNITARY_OUTPUT_PASSES = {
    'Collect1qRuns', 'Collect2qBlocks', 'ConsolidateBlocks', 'Split2QUnitaries'
}

@dataclass
class Gate:
    name: str
    qubits: list[int]
    params: list[float] = field(default_factory=list)
    matrix: Optional[np.ndarray] = None 

    def __str__(self):
        if self.name == 'UNITARY':
            return f"UNITARY({self.n_qubits}q) q{self.qubits}"
        s = self.name
        if self.params:
            s += f"({','.join(f'{p:.4f}' for p in self.params)})"
        return s + f" q{self.qubits}"

    @property
    def n_qubits(self):
        return len(self.qubits)

@dataclass
class TestCase:
    index: int
    num_qubits: int
    gates_before: list[Gate]
    gates_after:  list[Gate]

def parse_flat_matrix(nums: list[float], dim: int) -> np.ndarray:
    expected = dim * dim * 2
    assert len(nums) == expected, \
        f"Expected {expected} numbers for {dim}x{dim} matrix, got {len(nums)}"
    c = [complex(nums[i*2], nums[i*2+1]) for i in range(dim*dim)]
    return np.array(c, dtype=complex).reshape(dim, dim)

def parse_gate_line(line: str) -> Optional[Gate]:
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
    test_cases: list[TestCase] = []
    num_qubits = None
    gates_before: list[Gate] = []
    gates_after:  list[Gate] = []
    idx = 0
    in_matrix = False
    pending_unitary: Optional[Gate] = None
    matrix_nums: list[float] = []
    def flush_matrix():
        nonlocal in_matrix, pending_unitary, matrix_nums
        if pending_unitary is not None and matrix_nums:
            dim = 2 ** pending_unitary.n_qubits
            pending_unitary.matrix = parse_flat_matrix(matrix_nums, dim)
            gates_after.append(pending_unitary)
        pending_unitary = None
        in_matrix = False
        matrix_nums = []
    def flush_case():
        nonlocal num_qubits, gates_before, gates_after, idx
        flush_matrix()
        if num_qubits is not None:
            test_cases.append(TestCase(idx, num_qubits, gates_before, gates_after))
            idx += 1
        num_qubits = None
        gates_before = []
        gates_after  = []
    with open(path) as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            if in_matrix:
                if line.startswith('MatrixEnd'):
                    flush_matrix()
                    continue
                elif (line.startswith('GateAfter') or line.startswith('GateBefore')
                      or line.startswith('Qubits')):
                    flush_matrix()
                else:
                    matrix_nums.extend(float(x) for x in line.split())
                    continue
            if line.startswith('Qubits'):
                flush_case()
                num_qubits = int(line.split()[1])
            elif line.startswith('GateBefore'):
                e = parse_gate_line(line)
                if e: gates_before.append(e)
            elif line.startswith('GateAfter'):
                parts = line.split()
                if len(parts) >= 3 and parts[1].upper() == 'UNITARY':
                    nq     = int(parts[2])
                    qubits = [int(parts[3+i]) for i in range(nq)]
                    pending_unitary = Gate('UNITARY', qubits)
                else:
                    e = parse_gate_line(line)
                    if e: gates_after.append(e)
            elif line.startswith('MatrixBegin'):
                in_matrix = True
                matrix_nums = []
                rest = line[len('MatrixBegin'):].strip()
                if rest:
                    matrix_nums.extend(float(x) for x in rest.split())
    flush_case()
    return test_cases

def add_gate(qc: QuantumCircuit, gate: Gate) -> bool:
    n, q, p = gate.name, gate.qubits, gate.params
    try:
        match n:
            case 'I':       qc.id(q[0])
            case 'X':       qc.x(q[0])
            case 'Y':       qc.y(q[0])
            case 'Z':       qc.z(q[0])
            case 'H':       qc.h(q[0])
            case 'S':       qc.s(q[0])
            case 'SDG':     qc.sdg(q[0])
            case 'T':       qc.t(q[0])
            case 'TDG':     qc.tdg(q[0])
            case 'RX':      qc.rx(p[0], q[0])
            case 'RY':      qc.ry(p[0], q[0])
            case 'RZ':      qc.rz(p[0], q[0])
            case 'P':       qc.p(p[0], q[0])
            case 'IP':      qc.p(-p[0], q[0])
            case 'CX':
                if q[0] == q[1]: return False
                qc.cx(q[0], q[1])
            case 'MEASURE':
                qc.measure(q[0], q[0])
            case 'UNITARY':
                qc.append(UnitaryGate(gate.matrix), q[::-1])
            case _:
                print(f"    [WARN] Unknown gate '{n}'")
    except Exception as e:
        print(f"    [WARN] add_gate {gate}: {e}")
        return False
    return True

def has_measure(gates: list[Gate]) -> bool:
    return any(g.name == 'MEASURE' for g in gates)

def build_circuit(num_qubits: int, gates: list[Gate],
                  with_measure: bool = True) -> QuantumCircuit:
    need_classical = with_measure and has_measure(gates)
    qc = QuantumCircuit(num_qubits, num_qubits if need_classical else 0)
    for g in gates:
        add_gate(qc, g)
    return qc

def build_no_measure(num_qubits: int, gates: list[Gate]) -> QuantumCircuit:
    qc = QuantumCircuit(num_qubits)
    for g in gates:
        if g.name != 'MEASURE':
            add_gate(qc, g)
    return qc

def count_gates(gates_or_qc, exclude_measure=True) -> tuple[int, int]:
    total = 0
    two_q = 0
    if isinstance(gates_or_qc, QuantumCircuit):
        items = gates_or_qc.data
        for instr in items:
            name = instr.operation.name.upper()
            if exclude_measure and name == 'MEASURE':
                continue
            total += 1
            if instr.operation.num_qubits >= 2:
                two_q += 1
    else:
        for g in gates_or_qc:
            if exclude_measure and g.name == 'MEASURE':
                continue
            total += 1
            if g.n_qubits >= 2:
                two_q += 1
    return total, two_q

def _param_key(p) -> str:
    import hashlib
    if isinstance(p, np.ndarray):
        rounded = np.round(p.astype(complex), 6)
        return 'U:' + hashlib.md5(rounded.tobytes()).hexdigest()[:12]
    try:
        return str(round(float(p), 6))
    except (TypeError, ValueError):
        return str(p)

def instr_key(instr, qc: QuantumCircuit) -> str:
    name   = instr.operation.name.upper()
    qubits = sorted(qc.find_bit(q).index for q in instr.qubits)
    params = [_param_key(p) for p in instr.operation.params]
    return f"{name}|{qubits}|{params}"

def to_dag_layers(qc: QuantumCircuit, skip_measure=True) -> list[list[str]]:
    last: dict[int, int] = {}
    layers: list[list[str]] = []
    for instr in qc.data:
        if skip_measure and instr.operation.name.upper() == 'MEASURE':
            continue
        used = [qc.find_bit(q).index for q in instr.qubits]
        layer_idx = max((last.get(q, -1) for q in used), default=-1) + 1
        while len(layers) <= layer_idx:
            layers.append([])
        layers[layer_idx].append(instr_key(instr, qc))
        for q in used:
            last[q] = layer_idx
    return [sorted(l) for l in layers if l]

def diff_layers(mojo: list[list[str]],
               qiskit: list[list[str]]) -> tuple[bool, list[str]]:
    if mojo == qiskit:
        return True, []
    diffs = []
    for i in range(max(len(mojo), len(qiskit))):
        lm = mojo[i]   if i < len(mojo)   else []
        lq = qiskit[i] if i < len(qiskit) else []
        if lm != lq:
            only_m = sorted(set(lm) - set(lq))
            only_q = sorted(set(lq) - set(lm))
            diffs.append(f"    Layer {i}:")
            if only_m: diffs.append(f"      Mojo only  : {only_m}")
            if only_q: diffs.append(f"      Qiskit only: {only_q}")
    return False, diffs

def unitary_equiv(qc1: QuantumCircuit, qc2: QuantumCircuit,
                  tol: float = 1e-6) -> tuple[bool, float]:
    try:
        fid = abs(process_fidelity(Operator(qc1), Operator(qc2)))
        return fid >= 1.0 - tol, fid
    except Exception:
        return False, 0.0

def build_pass_manager(pass_name: str) -> PassManager:
    match pass_name:
        case 'RemoveIdentityEquivalent':
            return PassManager([RemoveIdentityEquivalent()])
        case 'RemoveDiagonalGatesBeforeMeasure':
            return PassManager([RemoveDiagonalGatesBeforeMeasure()])
        case 'InverseCancellation':
            if _make_IC is None: raise ImportError("InverseCancellation unavailable")
            return PassManager([_make_IC()])
        case 'CommutativeCancellation' | 'CommutativeInverseCancellation':
            if _make_CC is None: raise ImportError("CommutativeCancellation unavailable")
            return PassManager([_make_CC()])
        case 'Collect1qRuns':
            return PassManager([Collect1qRuns(),
                                ConsolidateBlocks(force_consolidate=True)])
        case 'Collect2qBlocks':
            return PassManager([Collect2qBlocks(),
                                ConsolidateBlocks(force_consolidate=True)])
        case 'ConsolidateBlocks':
            return PassManager([Collect1qRuns(), Collect2qBlocks(),
                                ConsolidateBlocks(force_consolidate=True)])
        case 'Split2QUnitaries':
            if Split2QUnitaries is None: raise ImportError("Split2QUnitaries unavailable")
            return PassManager([Collect2qBlocks(),
                                ConsolidateBlocks(force_consolidate=True),
                                Split2QUnitaries()])
        case 'FullOptimize':
            passes = []
            passes.append(RemoveIdentityEquivalent())
            if _make_IC is not None:
                passes.append(_make_IC())
            if _make_CIC is not None:
                passes.append(_make_CIC())
            # passes.append(RemoveDiagonalGatesBeforeMeasure())
            passes.append(Collect1qRuns())
            passes.append(Collect2qBlocks())
            passes.append(ConsolidateBlocks(force_consolidate=True))
            return PassManager(passes)
        case _:
            raise ValueError(f"Unknown pass: {pass_name}")

P = '✓'; F = '✗'; W = '⚠'

def verify(tc: TestCase, pass_name: str) -> dict:
    r = dict(
        index=tc.index, num_qubits=tc.num_qubits,
        n_before=0, n_mojo=0, n_qiskit=0,
        n_before_2q=0, n_mojo_2q=0, n_qiskit_2q=0,
        ub_mojo=False, fid_ub_mojo=0.0,    
        ub_qiskit=False, fid_ub_qiskit=0.0,   
        umq=False, fid_umq=0.0,                
        layer_match=None,                   
        skipped=False, skip_reason='',
    )
    n_meas = sum(1 for g in tc.gates_before if g.name == 'MEASURE')
    print(f"\n{'═'*64}")
    print(f"  Test #{tc.index+1}  |  Qubits: {tc.num_qubits}  |  "
          f"Before: {len(tc.gates_before)-n_meas}+{n_meas}m  |  "
          f"Mojo after: {len(tc.gates_after)}")
    invalid = [g for g in tc.gates_before
               if g.name == 'CX' and g.qubits[0] == g.qubits[1]]
    if invalid:
        msg = f"Invalid CX same qubit: {invalid[0]}"
        print(f"  {W} {msg}")
        r['skipped'] = True; r['skip_reason'] = msg
        return r
    qc_before      = build_circuit(tc.num_qubits, tc.gates_before)
    qc_mojo        = build_circuit(tc.num_qubits, tc.gates_after)
    qc_before_pure = build_no_measure(tc.num_qubits, tc.gates_before)
    qc_mojo_pure   = build_no_measure(tc.num_qubits, tc.gates_after)
    try:
        pm = build_pass_manager(pass_name)
        qc_qiskit = pm.run(qc_before)
    except Exception as e:
        print(f"  {W} Qiskit pass failed: {e}")
        r['skipped'] = True; r['skip_reason'] = str(e)
        return r
    qc_qiskit_pure = build_no_measure(
        tc.num_qubits,
        [Gate(i.operation.name.upper(),
              [qc_qiskit.find_bit(q).index for q in i.qubits])
         for i in qc_qiskit.data if i.operation.name.upper() != 'MEASURE']
    ) if False else None
    qc_qiskit_pure = QuantumCircuit(tc.num_qubits)
    for instr in qc_qiskit.data:
        if instr.operation.name.upper() != 'MEASURE':
            qc_qiskit_pure.append(instr.operation,
                [qc_qiskit.find_bit(q).index for q in instr.qubits])
    r['n_before'], r['n_before_2q'] = count_gates(qc_before_pure)
    r['n_mojo'],   r['n_mojo_2q']   = count_gates(qc_mojo_pure)
    r['n_qiskit'], r['n_qiskit_2q'] = count_gates(qc_qiskit_pure)
    print(f"  Gate count   → Before: {r['n_before']:3d}  "
          f"Mojo: {r['n_mojo']:3d}  Qiskit: {r['n_qiskit']:3d}")
    print(f"  2q gate count→ Before: {r['n_before_2q']:3d}  "
          f"Mojo: {r['n_mojo_2q']:3d}  Qiskit: {r['n_qiskit_2q']:3d}")
    r['ub_mojo'],   r['fid_ub_mojo']   = unitary_equiv(qc_before_pure, qc_mojo_pure)
    r['ub_qiskit'], r['fid_ub_qiskit'] = unitary_equiv(qc_before_pure, qc_qiskit_pure)
    r['umq'],       r['fid_umq']       = unitary_equiv(qc_mojo_pure,   qc_qiskit_pure)
    print(f"  {P if r['ub_mojo']   else F} U(before) ≈ U(mojo)   "
          f"fidelity={r['fid_ub_mojo']:.8f}")
    print(f"  {P if r['ub_qiskit'] else F} U(before) ≈ U(qiskit) "
          f"fidelity={r['fid_ub_qiskit']:.8f}")
    print(f"  {P if r['umq']       else F} U(mojo)   ≈ U(qiskit) "
          f"fidelity={r['fid_umq']:.8f}")
    if pass_name in STRUCTURAL_PASSES:
        layers_mojo   = to_dag_layers(qc_mojo,   skip_measure=True)
        layers_qiskit = to_dag_layers(qc_qiskit, skip_measure=True)
        match, diffs  = diff_layers(layers_mojo, layers_qiskit)
        r['layer_match'] = match
        print(f"  {P if match else F} DAG layer match (Mojo == Qiskit) : "
              f"{'YES' if match else 'NO'}")
        if diffs:
            for d in diffs[:20]: print(d)
            if len(diffs) > 20: print(f"    ... (truncated)")
    if tc.num_qubits <= 5:
        for label, circ in [('BEFORE', qc_before),
                             ('QISKIT', qc_qiskit),
                             ('MOJO',   qc_mojo)]:
            print(f"\n  [{label}]")
            print(circ.draw(output='text', fold=-1))
    return r

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('file')
    ap.add_argument('--pass', dest='pass_name', required=True,
                    help='RemoveIdentityEquivalent | RemoveDiagonalGatesBeforeMeasure | '
                         'InverseCancellation | CommutativeCancellation | '
                         'Collect1qRuns | Collect2qBlocks | ConsolidateBlocks | '
                         'Split2QUnitaries')
    args = ap.parse_args()

    test_cases = parse_file(args.file)
    print(f"Parsed {len(test_cases)} test case(s)")
    print(f"Pass: {args.pass_name}")
    print(f"Mode: {'UNITARY (3-way fidelity)' if args.pass_name in UNITARY_PASSES else 'STRUCTURAL (gate list + unitary)'}")

    results = [verify(tc, args.pass_name) for tc in test_cases]
    print(f"\n{'═'*92}")
    print("SUMMARY")
    print(f"{'═'*92}")

    structural = args.pass_name in STRUCTURAL_PASSES
    if structural:
        print(f"{'#':>3}  {'Q':>2}  {'Bef':>4}  {'Mojo':>4}  {'Qis':>4}  "
              f"{'Bef2q':>5}  {'Mj2q':>5}  {'Qs2q':>5}  "
              f"{'U(b≈m)':>8}  {'U(b≈q)':>8}  {'Layer':>6}")
    else:
        print(f"{'#':>3}  {'Q':>2}  {'Bef':>4}  {'Mojo':>4}  {'Qis':>4}  "
              f"{'Bef2q':>5}  {'Mj2q':>5}  {'Qs2q':>5}  "
              f"{'U(b≈m)':>8}  {'U(b≈q)':>8}  {'U(m≈q)':>8}")
    print('─' * 92)

    total = len(results)
    n_skip = 0
    n_ub_mojo_ok = n_ub_qiskit_ok = n_umq_ok = n_layer_ok = 0

    for r in results:
        if r['skipped']:
            n_skip += 1
            print(f"{r['index']+1:>3}  {r['num_qubits']:>2}  "
                  f"{'?':>4}  {'?':>4}  {'?':>4}  "
                  f"{'?':>5}  {'?':>5}  {'?':>5}  "
                  f"{'⚠ skip':>8}  {'⚠ skip':>8}  {'—':>8}")
            continue

        if r['ub_mojo']:   n_ub_mojo_ok += 1
        if r['ub_qiskit']: n_ub_qiskit_ok += 1
        if r['umq']:       n_umq_ok += 1

        ubm = P if r['ub_mojo']   else F
        ubq = P if r['ub_qiskit'] else F

        if structural:
            lm = (P if r['layer_match'] else F) if r['layer_match'] is not None else '—'
            if r['layer_match']: n_layer_ok += 1
            print(f"{r['index']+1:>3}  {r['num_qubits']:>2}  "
                  f"{r['n_before']:>4}  {r['n_mojo']:>4}  {r['n_qiskit']:>4}  "
                  f"{r['n_before_2q']:>5}  {r['n_mojo_2q']:>5}  {r['n_qiskit_2q']:>5}  "
                  f"{ubm:>8}  {ubq:>8}  {lm:>6}")
        else:
            umq = P if r['umq'] else F
            print(f"{r['index']+1:>3}  {r['num_qubits']:>2}  "
                  f"{r['n_before']:>4}  {r['n_mojo']:>4}  {r['n_qiskit']:>4}  "
                  f"{r['n_before_2q']:>5}  {r['n_mojo_2q']:>5}  {r['n_qiskit_2q']:>5}  "
                  f"{ubm:>8}  {ubq:>8}  {umq:>8}")

    valid = total - n_skip
    print(f"\n  U(before) ≈ U(mojo)   : {n_ub_mojo_ok}/{valid}")
    print(f"  U(before) ≈ U(qiskit) : {n_ub_qiskit_ok}/{valid}")
    if structural:
        print(f"  DAG layer match       : {n_layer_ok}/{valid}")
    else:
        print(f"  U(mojo) ≈ U(qiskit)   : {n_umq_ok}/{valid}")
    if n_skip:
        print(f"  Skipped               : {n_skip}")
    all_ok = (n_ub_mojo_ok == valid)
    print(f"\n{'✓ ALL TESTS PASSED (correctness)' if all_ok else '✗ SOME TESTS FAILED'}")
    if not all_ok:
        sys.exit(1)

if __name__ == '__main__':
    main()