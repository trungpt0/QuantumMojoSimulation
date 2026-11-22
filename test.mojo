import sys, time, math
from collections import defaultdict
import numpy as np

PI, PI2 = math.pi, 2 * math.pi
N_RAND = 200
BASES = ["ZYZ", "ZXZ", "ZSX", "U"]
QISKIT_BASIS = {"ZYZ": "ZYZ", "ZXZ": "ZXZ", "ZSX": "ZSX", "U": "U"}
MAX_GATES = {"ZYZ": 3, "ZXZ": 3, "ZSX": 5, "U": 1}
SPECIALS = ["id", "phase", "x", "y", "z", "h", "s", "t", "sx", "rztiny", "rytiny", "rypieps", "rypi", "rxhalf", "u3"]
TOL = 1e-9
LINE = "=" * 96

def rz(a):
    return np.diag([np.exp(-0.5j * a), np.exp(0.5j * a)])

def ry(a):
    c, s = math.cos(a / 2), math.sin(a / 2); return np.array([[c, -s], [s, c]], dtype=complex)

def rx(a):
    c, s = math.cos(a / 2), math.sin(a / 2); return np.array([[c, -1j * s], [-1j * s, c]])

H = np.array([[1, 1], [1, -1]], dtype=complex) / math.sqrt(2)
SX = 0.5 * np.array([[1 + 1j, 1 - 1j], [1 - 1j, 1 + 1j]])

def u3(t, p, l):
    c, s = math.cos(t / 2), math.sin(t / 2)
    return np.array([[c, -np.exp(1j * l) * s], [np.exp(1j * p) * s, np.exp(1j * (p + l)) * c]])

def special(name):
    return {
        "id": np.eye(2, dtype=complex),
        "phase": np.exp(0.3j) * np.eye(2),
        "x": np.array([[0, 1], [1, 0]], dtype=complex),
        "y": np.array([[0, -1j], [1j, 0]]),
        "z": np.diag([1, -1]).astype(complex),
        "h": H, "s": np.diag([1, 1j]), "t": np.diag([1, np.exp(0.25j * PI)]), "sx": SX,
        "rztiny": rz(1e-14), "rytiny": ry(1e-9), "rypieps": ry(PI - 1e-12),
        "rypi": ry(PI), "rxhalf": rx(PI / 2), "u3": u3(1.1, -2.3, 0.7),
    }[name]

class LCG:
    def __init__(self, seed): self.s = seed & 0x7FFFFFFF
    def next(self):
        self.s = (self.s * 1664525 + 1013904223) & 0x7FFFFFFF
        return self.s
    def below(self, n): return (self.next() >> 8) % n
    def unit(self): return (self.next() >> 7) / 16777216.0

def random_u2(seed):
    d = 2; U = np.eye(d, dtype=complex); rng = LCG(seed)
    for _ in range(4 * d * d):
        i = rng.below(d); j = rng.below(d - 1)
        if j >= i: j += 1
        th = rng.unit() * PI2; ph = rng.unit() * PI2
        c, s, e = math.cos(th), math.sin(th), complex(math.cos(ph), math.sin(ph))
        x, y = U[i].copy(), U[j].copy()
        U[i] = c * x - s * e * y
        U[j] = s * e.conjugate() * x + c * y
    for k in range(d):
        ph = rng.unit() * PI2
        U[k] *= complex(math.cos(ph), math.sin(ph))
    return U

def matrix_for(case):
    return random_u2(9000 + int(case[4:])) if case.startswith("rand") else special(case)

def phase_error(A, B):
    ov = np.vdot(A, B)
    ph = ov / abs(ov) if abs(ov) > 0 else 1.0
    return float(np.max(np.abs(B - ph * A)))

GATE_MAT = {
    "RZ": lambda p: rz(p[0]), 
    "RY": lambda p: ry(p[0]), 
    "RX": lambda p: rx(p[0]),
    "SX": lambda p: SX, 
    "H": lambda p: H, 
    "U": lambda p: u3(*p)
}

def unitary_from(gates):
    M = np.eye(2, dtype=complex)
    for name, ps in gates: M = GATE_MAT[name](ps) @ M
    return M

def parse_mojo(path):
    res, gates = {}, defaultdict(list)
    for line in open(path):
        p = line.split()
        if line.startswith("RESULT"):
            d = {}
            for kv in p[2:]:
                k, v = kv.split("=", 1)
                d[k] = float(v) if k == "err" else int(v)
            res[p[1]] = d
        elif line.startswith("GATE"):
            gates[p[1]].append((p[2], [float(x[2:]) for x in p[4:] if x.startswith("p=")]))
    return res, gates

def split(label):
    case, basis = label.rsplit("_", 1); return case, basis

def run_qiskit(cases):
    try:
        from qiskit.synthesis import OneQubitEulerDecomposer
        from qiskit.quantum_info import Operator
    except Exception as e:
        print(f"# Could not load Qiskit: {e}"); return {}
    out = {}
    for b in BASES:
        dec = OneQubitEulerDecomposer(basis=QISKIT_BASIS[b])
        for case in cases:
            U = matrix_for(case)
            qc = dec(U)
            ts = []
            for _ in range(50):
                t0 = time.monotonic_ns(); dec(U); ts.append(time.monotonic_ns() - t0)
            out[f"{case}_{b}"] = dict(gates=len(qc.data), err=phase_error(U, Operator(qc).data),
                                      ns=sorted(ts)[len(ts) // 2])
    return out

def mark(m, q):
    if m is None or q is None: return "  "
    return "✅" if m <= q else "❌"

def main():
    if len(sys.argv) < 2: print(__doc__); sys.exit(1)
    M, G = parse_mojo(sys.argv[1])
    cases = SPECIALS + [f"rand{k}" for k in range(N_RAND)]
    Q = {} if "--no-qiskit" in sys.argv else run_qiskit(cases)
    expected = len(cases) * len(BASES)
    self_bad = [l for l, r in M.items() if r["err"] > TOL]
    redo_bad, over_bad, ang_bad, name_bad = [], [], [], []
    allowed = {"ZYZ": {"RZ", "RY"}, "ZXZ": {"RZ", "RX"}, "ZSX": {"RZ", "SX"}, "U": {"U"}}
    for label in M:
        case, b = split(label)
        gl = G.get(label, [])
        if phase_error(matrix_for(case), unitary_from(gl)) > TOL: redo_bad.append(label)
        if len(gl) > MAX_GATES[b]: over_bad.append(label)
        if any(n not in allowed[b] for n, _ in gl): name_bad.append(label)
        for n, ps in gl:
            if any(not (-PI - 1e-12 < p <= PI + 1e-12) for p in ps):
                if not (n == "U" and ps is gl[0][1] and 0 <= ps[0] <= PI + 1e-12 and
                        all(-PI - 1e-12 < p <= PI + 1e-12 for p in ps[1:])):
                    ang_bad.append(label); break
    def ok(x): return "✅ ok  " if not x else "❌ FAIL"
    print(LINE); print("CORRECTNESS")
    print(f"  {ok(len(M) != expected)}  rows from Mojo                : {len(M)}/{expected}")
    print(f"  {ok(self_bad)}  Mojo self-check err <= {TOL:g}  : {len(self_bad)} wrong")
    print(f"  {ok(redo_bad)}  Python re-check (numpy)       : {len(redo_bad)} wrong")
    print(f"  {ok(name_bad)}  only gates of the basis       : {len(name_bad)} wrong")
    print(f"  {ok(over_bad)}  gate count <= bound           : {len(over_bad)} over "
          f"(ZYZ/ZXZ 3, ZSX 5, U 1)")
    print(f"  {ok(ang_bad)}  angles in (-pi, pi]           : {len(ang_bad)} out of range")
    if Q:
        qbad = [l for l, r in Q.items() if r["err"] > TOL]
        print(f"  {ok(qbad)}  Qiskit err <= {TOL:g}          : {len(qbad)} wrong")
    for l in (self_bad + redo_bad + name_bad + over_bad + ang_bad)[:10]:
        print("      FAIL:", l, M.get(l, {}).get("err"))
    print("\n" + LINE); print("SPECIAL MATRICES - gate count  (Mojo / Qiskit)")
    print(f"{'case':>9} | " + " | ".join(f"{b:>10}" for b in BASES))
    for case in SPECIALS:
        cells = []
        for b in BASES:
            m = M.get(f"{case}_{b}", {}).get("gates"); q = Q.get(f"{case}_{b}", {}).get("gates")
            cells.append(f"{m if m is not None else '-':>3}/{q if q is not None else '-':<3} {mark(m, q)}")
        print(f"{case:>9} | " + " | ".join(f"{c:>10}" for c in cells))
    print("\n" + LINE); print(f"RANDOM ({N_RAND} unitaries) - per basis")
    print(f"{'basis':>6} | {'M gates':>8} {'Q gates':>8} | {'M max err':>10} {'Q max err':>10} | "
          f"{'win':>4} {'tie':>4} {'loss':>4}")
    for b in BASES:
        rm = [M[f"rand{k}_{b}"] for k in range(N_RAND) if f"rand{k}_{b}" in M]
        rq = [Q[f"rand{k}_{b}"] for k in range(N_RAND) if f"rand{k}_{b}" in Q]
        w = t = l = 0
        for k in range(N_RAND):
            m, q = M.get(f"rand{k}_{b}"), Q.get(f"rand{k}_{b}")
            if not m or not q: continue
            if m["gates"] < q["gates"]: w += 1
            elif m["gates"] == q["gates"]: t += 1
            else: l += 1
        mg = sum(r["gates"] for r in rm) / len(rm) if rm else float("nan")
        qg = sum(r["gates"] for r in rq) / len(rq) if rq else float("nan")
        me = max((r["err"] for r in rm), default=float("nan"))
        qe = max((r["err"] for r in rq), default=float("nan"))
        print(f"{b:>6} | {mg:8.2f} {qg:8.2f} | {me:10.1e} {qe:10.1e} | {w:>4} {t:>4} {l:>4}")
    print("\n" + LINE); print("TIME (ns per decomposition, median over random cases)")
    print(f"{'basis':>6} | {'Mojo':>9} {'Qiskit':>9} {'x':>7}")
    for b in BASES:
        a = sorted(M[f"rand{k}_{b}"]["ns"] for k in range(N_RAND) if f"rand{k}_{b}" in M)
        q = sorted(Q[f"rand{k}_{b}"]["ns"] for k in range(N_RAND) if f"rand{k}_{b}" in Q)
        ma = a[len(a) // 2] if a else None
        qa = q[len(q) // 2] if q else None
        sp = f"{qa / ma:6.1f}x" if ma and qa else f"{'-':>7}"
        print(f"{b:>6} | {ma if ma is not None else '-':>9} {qa if qa is not None else '-':>9} {sp} {mark(ma, qa)}")
    print(LINE)

if __name__ == "__main__":
    main()