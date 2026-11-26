import sys, time, math
from collections import defaultdict
import numpy as np

PI2 = 2 * math.pi
NS = [1, 2, 3, 4, 5, 6]
MODES = ["kak", "plain"]
TOL = 1e-7
MAX_DUMP_N = 4
LINE = "=" * 104

class LCG:

    def __init__(self, seed):
        self.s = seed & 0x7FFFFFFF
    
    def next(self):
        self.s = (self.s * 1664525 + 1013904223) & 0x7FFFFFFF
        return self.s
    
    def below(self, n): 
        return (self.next() >> 8) % n
    
    def unit(self): 
        return (self.next() >> 7) / 16777216.0

def samples_for(n):
    return 5 if n <= 4 else 3 if n == 5 else 2

def random_unitary(n, seed):
    d = 1 << n; U = np.eye(d, dtype=complex); rng = LCG(seed)
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

def matrix_for(n, s):
    return random_unitary(n, 7000 + 100 * n + s)

def cx_plain(n):
    c = 0
    for k in range(2, n + 1): c = 4 * c + 3 * (1 << (k - 1))
    return c

def cx_kak(n):
    if n < 2: return 0
    c = 3
    for k in range(3, n + 1): c = 4 * c + 3 * (1 << (k - 1))
    return c

def cx_optimized(n):
    if n < 2: return 0
    return round(23 / 48 * 4 ** n - 1.5 * 2 ** n + 4 / 3)

def cx_lower(n):
    return math.ceil((4 ** n - 3 * n - 1) / 4)

def phase_error(A, B):
    ov = np.vdot(A, B)
    ph = ov / abs(ov) if abs(ov) > 0 else 1.0
    return float(np.max(np.abs(B - ph * A)))

def unitary_from_gates(gates, n):
    d = 1 << n; U = np.eye(d, dtype=complex); idx = np.arange(d)
    for name, qs, ps in gates:
        if name == "CX":
            bc, bt = 1 << (n - 1 - qs[0]), 1 << (n - 1 - qs[1])
            sel = idx[((idx & bc) != 0) & ((idx & bt) == 0)]
            tmp = U[sel].copy(); U[sel] = U[sel | bt]; U[sel | bt] = tmp
        elif name == "RZ":
            b = 1 << (n - 1 - qs[0]); one = (idx & b) != 0
            U[~one] *= np.exp(-0.5j * ps[0]); U[one] *= np.exp(0.5j * ps[0])
        elif name == "RY":
            b = 1 << (n - 1 - qs[0]); lo = idx[(idx & b) == 0]; hi = lo | b
            c, s = math.cos(ps[0] / 2), math.sin(ps[0] / 2)
            x, y = U[lo].copy(), U[hi].copy()
            U[lo] = c * x - s * y; U[hi] = s * x + c * y
        else:
            raise ValueError(name)
    return U

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
            qs = [int(x) for x in p[3:] if not x.startswith("p=")]
            ps = [float(x[2:]) for x in p[3:] if x.startswith("p=")]
            gates[p[1]].append((p[2], qs, ps))
    return res, gates

def split(label):
    _, n, s, mode = label.split("_"); return int(n), int(s), mode

def run_qiskit():
    try:
        from qiskit.synthesis import qs_decomposition
        from qiskit.transpiler import PassManager
        from qiskit.transpiler.passes import BasisTranslator, Optimize1qGatesDecomposition
        from qiskit.circuit.equivalence_library import SessionEquivalenceLibrary
        from qiskit.quantum_info import Operator
    except Exception as e:
        print(f"# Could not load Qiskit: {e}"); return {}
    pm = PassManager([
        BasisTranslator(SessionEquivalenceLibrary, ["cx", "u"]),
        Optimize1qGatesDecomposition(basis=["rz", "ry"]),
    ])
    out = {}
    for n in NS:
        for s in range(samples_for(n)):
            U = matrix_for(n, s)
            ts = []
            for _ in range(3 if n <= 4 else 1):
                t0 = time.monotonic_ns(); qc = qs_decomposition(U); ts.append(time.monotonic_ns() - t0)
            tq = pm.run(qc)
            ops = tq.count_ops()
            other = {k: v for k, v in ops.items() if k not in ("cx", "rz", "ry")}
            if other:
                print(f"# WARN Qiskit n={n} s={s}: cong ngoai basis {other}")
            out[(n, s)] = dict(cx=ops.get("cx", 0), gates=sum(ops.values()), depth=tq.depth(),
                               err=phase_error(U, Operator(tq).data), ns=sorted(ts)[len(ts) // 2])
    return out

def mean(vals): return sum(vals) / len(vals) if vals else None
def f(x, w=9, p=1): return f"{'-':>{w}}" if x is None else f"{x:>{w}.{p}f}"
def mark(m, q):
    if m is None or q is None: return "  "
    return "✅" if m <= q else ("⚠️" if m <= 1.05 * q else "❌")
def okmark(c): return "✅ ok  " if c else "❌ FAIL"

def main():
    if len(sys.argv) < 2: print(__doc__); sys.exit(1)
    M, G = parse_mojo(sys.argv[1])
    Q = {} if "--no-qiskit" in sys.argv else run_qiskit()
    by = defaultdict(list)                                  # (n, mode) -> rows
    for label, r in M.items():
        n, s, mode = split(label); by[(n, mode)].append(r)
    expected = sum(samples_for(n) for n in NS) * len(MODES)
    self_bad = [l for l, r in M.items() if r["err"] > TOL]
    redo_bad, name_bad = [], []
    for label, gl in G.items():
        n, s, _ = split(label)
        if phase_error(matrix_for(n, s), unitary_from_gates(gl, n)) > TOL: redo_bad.append(label)
        if any(name not in ("RZ", "RY", "CX") for name, _, _ in gl): name_bad.append(label)
    over = [l for l, r in M.items()
            if r["cx"] > (cx_kak if split(l)[2] == "kak" else cx_plain)(split(l)[0])]
    print(LINE); print("CORRECTNESS  (equal up to global phase)")
    print(f"  {okmark(len(M) == expected)}  rows from Mojo                    : {len(M)}/{expected}")
    print(f"  {okmark(not self_bad)}  Mojo self-check err <= {TOL:g}        : {len(self_bad)} wrong")
    print(f"  {okmark(not redo_bad)}  Python re-check ({len(G)} circuits, n<={MAX_DUMP_N}) : {len(redo_bad)} wrong")
    print(f"  {okmark(not name_bad)}  only RZ / RY / CX                 : {len(name_bad)} wrong")
    print(f"  {okmark(not over)}  CX <= theory for its mode         : {len(over)} over")
    if Q:
        qbad = [k for k, r in Q.items() if r["err"] > TOL]
        print(f"  {okmark(not qbad)}  Qiskit err <= {TOL:g}                : {len(qbad)}/{len(Q)} wrong")
    for l in (self_bad + redo_bad + name_bad + over)[:10]:
        print("      FAIL:", l, M.get(l))
    print("\n" + LINE); print("CX COUNT (mean)        theory: plain / +KAK / +A.1+A.2 (Qiskit) / lower bound")
    print(f"{'n':>2} | {'th plain':>8} {'th kak':>7} {'th opt':>7} {'lower':>6} | "
          f"{'M plain':>8} {'M kak':>8} {'Qiskit':>8} | {'kak/th':>6} | kak vs Q")
    for n in NS:
        mp = mean([r["cx"] for r in by[(n, "plain")]])
        mk = mean([r["cx"] for r in by[(n, "kak")]])
        qc = mean([Q[(n, s)]["cx"] for s in range(samples_for(n)) if (n, s) in Q])
        ratio = f"{mk / cx_kak(n):6.2f}" if mk is not None and cx_kak(n) else f"{'-':>6}"
        print(f"{n:>2} | {cx_plain(n):>8} {cx_kak(n):>7} {cx_optimized(n):>7} {cx_lower(n):>6} | "
              f"{f(mp, 8)} {f(mk, 8)} {f(qc, 8)} | {ratio} |    {mark(mk, qc)}")
    print("\n" + LINE); print("TOTAL GATES / DEPTH (mean)")
    print(f"{'n':>2} | {'M plain g':>9} {'M kak g':>9} {'Q g':>9} | "
          f"{'M plain d':>9} {'M kak d':>9} {'Q d':>9} | {'max err kak':>11} {'max err Q':>10}")
    for n in NS:
        rk, rp = by[(n, "kak")], by[(n, "plain")]
        rq = [Q[(n, s)] for s in range(samples_for(n)) if (n, s) in Q]
        ek = max((r["err"] for r in rk), default=float("nan"))
        eq = max((r["err"] for r in rq), default=float("nan"))
        print(f"{n:>2} | {f(mean([r['gates'] for r in rp]))} {f(mean([r['gates'] for r in rk]))} "
              f"{f(mean([r['gates'] for r in rq]))} | {f(mean([r['depth'] for r in rp]))} "
              f"{f(mean([r['depth'] for r in rk]))} {f(mean([r['depth'] for r in rq]))} | "
              f"{ek:11.1e} {eq:10.1e}")
    print("\n" + LINE); print("TIME (ms, median per sample, then mean)")
    print(f"{'n':>2} | {'M plain':>9} {'M kak':>9} {'Qiskit':>9} | {'Q/Mkak':>7}")
    for n in NS:
        a = mean([r["ns"] for r in by[(n, "plain")]])
        b = mean([r["ns"] for r in by[(n, "kak")]])
        c = mean([Q[(n, s)]["ns"] for s in range(samples_for(n)) if (n, s) in Q])
        sp = f"{c / b:6.1f}x" if b and c else f"{'-':>7}"
        ms = lambda x: f(x / 1e6 if x else None, 9, 3)
        print(f"{n:>2} | {ms(a)} {ms(b)} {ms(c)} | {sp} {mark(b, c)}")
    print(LINE)

if __name__ == "__main__":
    main()