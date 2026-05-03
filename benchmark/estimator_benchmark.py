import sys, argparse
from dataclasses import dataclass, field
from collections import defaultdict

try:
    from qiskit import QuantumCircuit
    from qiskit.quantum_info import SparsePauliOp
    from qiskit.primitives import StatevectorEstimator
except ImportError:
    print("Qiskit is not installed. Please install qiskit to run this benchmark.")
    sys.exit(1)

@dataclass
class Gate:
    name: str
    q0: int
    q1: int = -1

@dataclass
class TestCase:
    n: int
    gates: list = field(default_factory=list)
    obs: list = field(default_factory=list)
    expected_value: float = 0.0

def parse(path: str) -> list:
    tests, cur = [], None
    with open(path) as f:
        for raw in f:
            line = raw.strip()
            if not line: continue
            p = line.split()
            if p[0] == "Qubits":
                if cur is not None:
                    tests.append(cur)
                cur = TestCase(n=int(p[1]))
            elif p[0] == "Gate" and cur is not None:
                if p[1] == "CX":
                    cur.gates.append(Gate("CX", int(p[2]), int(p[3])))
                else:
                    cur.gates.append(Gate(p[1], int(p[2])))
            elif p[0] == "Observable" and cur is not None:
                cur.obs.append((p[1], float(p[2])))
            elif p[0] == "Expected_value" and cur is not None:
                cur.expected_value = float(p[1])
    if cur is not None:
        tests.append(cur)
    return tests

GATE = {
    "X": lambda qc, q0, q1: qc.x(q0),
    "Y": lambda qc, q0, q1: qc.y(q0),
    "Z": lambda qc, q0, q1: qc.z(q0),
    "H": lambda qc, q0, q1: qc.h(q0),
    "CX": lambda qc, q0, q1: qc.cx(q0, q1),
}

def run_qiskit(tc: TestCase) -> float:
    qc = QuantumCircuit(tc.n)
    for g in tc.gates:
        if g.name == "CX" and g.q0 == g.q1:
            continue
        GATE[g.name](qc, g.q0, g.q1)
    cm = defaultdict(float)
    for p, c in tc.obs:
        cm[p] += c
    H = SparsePauliOp.from_list(list(cm.items()))
    return float(StatevectorEstimator().run([(qc, H)]).result()[0].data.evs)

G, R, RST = "\033[92m", "\033[91m", "\033[0m"

def estimator_evaluation(path: str, tol: float):
    tests = parse(path)
    if not tests:
        print("Test case not found"); return
    passed = failed = errors = 0
    W = 100
    print("-" * W)
    print(f"{'#':>4} {'QUBITS':>6} {'GATES':>6} {'OBSERVABLE':<32} {'MOJO':>12} {'QISKIT':>12} {'DIFF':>12} {'RESULT':>8}")
    print("-" * W)
    for i, tc in enumerate(tests):
        obs_str = "+".join(f"{c:+.1f}*{p}" for p, c in tc.obs)
        if len(obs_str) > 32:
            obs_str = obs_str[:29] + "..."
        try:
            qval = run_qiskit(tc)
        except Exception as e:
            errors += 1
            print(f"{i+1:>4} {tc.n:>6} {len(tc.gates):>6} ERROR: {e}")
            continue
        diff = abs(qval - tc.expected_value)
        ok = diff <= tol
        tag = f"{G}PASS{RST}" if ok else f"{R}FAIL{RST}"
        print(f"{i+1:>4} {tc.n:>6} {len(tc.gates):>6} {obs_str:<32} {tc.expected_value:>12.6f} {qval:>12.6f} {diff:>12.1e} {tag:>8}")
        if not ok:
            failed += 1
            gs = " ".join(f"{g.name}({g.q0},{g.q1})" if g.q1 >= 0 else f"{g.name}({g.q0})" for g in tc.gates)
            print(f"     Gates: {gs}")
        else:
            passed += 1
    total = passed + failed + errors
    print("-" * W)
    print(f"RESULT: {passed}/{total} {G}PASS{RST} | {failed}/{total} {R}FAIL{RST} | {errors}/{total} {R}ERROR{RST}")
    if failed == 0 and errors == 0:
        print(f"{G}All test cases passed!{RST}")
    else:
        print(f"{R} {failed + errors} test cases failed or had errors. Please review the results above.{RST}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default="benchmark/estimator_benchmark.txt")
    ap.add_argument("--tol", type=float, default=1e-6)
    args = ap.parse_args()
    estimator_evaluation(args.file, args.tol)