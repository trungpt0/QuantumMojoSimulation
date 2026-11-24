import sys, time, math
from collections import defaultdict, Counter
import numpy as np

PI, PI2 = math.pi, 2 * math.pi
N_RAND = 200
TOL = 1e-8
LINE = "=" * 100
SPECIALS = ["id", "local", "cx", "cz", "swap", "iswap", "cnotlike",
            "two", "bgate", "sqrtswap", "generic", "near"]
EXPECTED = {"id": 0, "local": 0, "cx": 1, "cz": 1, "cnotlike": 1, "iswap": 2,
            "two": 2, "bgate": 2, "swap": 3, "sqrtswap": 3, "generic": 3, "near": None}

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

def can_matrix(a, b, c):
    lp, lm, sp, sm = a - b + c, -a + b + c, a + b - c, -a - b - c
    M = np.zeros((4, 4), dtype=complex)
    ep, em, eP, eM = (np.exp(1j * x) for x in (lp, lm, sp, sm))
    M[0, 0] = M[3, 3] = (ep + em) / 2; M[0, 3] = M[3, 0] = (ep - em) / 2
    M[1, 1] = M[2, 2] = (eP + eM) / 2; M[1, 2] = M[2, 1] = (eP - eM) / 2
    return M

def rz(a):
    return np.diag([np.exp(-0.5j * a), np.exp(0.5j * a)])

def ry(a):
    c, s = math.cos(a / 2), math.sin(a / 2); return np.array([[c, -s], [s, c]], dtype=complex)

def rx(a):
    c, s = math.cos(a / 2), math.sin(a / 2); return np.array([[c, -1j * s], [-1j * s, c]])

def perm4(p):
    M = np.zeros((4, 4), dtype=complex)
    for i, r in enumerate(p): M[r, i] = 1
    return M

def special(name):
    if name == "id": return np.eye(4, dtype=complex)
    if name == "local": return np.kron(ry(0.3) @ rz(1.1), rx(0.7))
    if name == "cx": return perm4([0, 1, 3, 2])
    if name == "cz": return np.diag([1, 1, 1, -1]).astype(complex)
    if name == "swap": return perm4([0, 2, 1, 3])
    if name == "iswap":
        M = np.zeros((4, 4), dtype=complex); M[0, 0] = M[3, 3] = 1; M[1, 2] = M[2, 1] = 1j
        return M
    return {"cnotlike": can_matrix(PI / 4, 0, 0), "two": can_matrix(0.3, 0, 0.2),
            "bgate": can_matrix(PI / 4, PI / 8, 0), "sqrtswap": can_matrix(PI / 8, PI / 8, PI / 8),
            "generic": can_matrix(0.4, 0.3, 0.1), "near": can_matrix(0.4, 0.3, 1e-9)}[name]

def dressed(M, seed):
    L = np.kron(random_unitary(1, seed), random_unitary(1, seed + 1))
    R = np.kron(random_unitary(1, seed + 2), random_unitary(1, seed + 3))
    return L @ M @ R

def matrix_for(label):
    if label.startswith("rand"): return random_unitary(2, 11000 + int(label[4:]))
    name = label[:-2] if label.endswith("-d") else label
    M = special(name)
    return dressed(M, 500 + 10 * SPECIALS.index(name)) if label.endswith("-d") else M

ALL_LABELS = [x for n in SPECIALS for x in (n, n + "-d")] + [f"rand{k}" for k in range(N_RAND)]

def phase_error(A, B):
    ov = np.vdot(A, B)
    ph = ov / abs(ov) if abs(ov) > 0 else 1.0
    return float(np.max(np.abs(B - ph * A)))

def unitary_from_gates(gates, n=2):
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

def layer_depth(gates):
    d = {}
    for _, qs, _ in gates:
        m = max(d.get(q, 0) for q in qs) + 1
        for q in qs: d[q] = m
    return max(d.values()) if d else 0

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
    for label, r in res.items():
        r["depth"] = layer_depth(gates[label])
    return res, gates

def run_qiskit():
    try:
        from qiskit.synthesis import TwoQubitBasisDecomposer, TwoQubitWeylDecomposition
        from qiskit.circuit.library import CXGate
        from qiskit.quantum_info import Operator
    except Exception as e:
        print(f"# Could not load Qiskit: {e}"); return {}
    try:
        dec = TwoQubitBasisDecomposer(CXGate(), euler_basis="ZYZ")
    except TypeError:
        dec = TwoQubitBasisDecomposer(CXGate())
    out = {}
    for label in ALL_LABELS:
        U = matrix_for(label)
        qc = dec(U)
        ts = []
        for _ in range(10):
            t0 = time.monotonic_ns(); dec(U); ts.append(time.monotonic_ns() - t0)
        ops = qc.count_ops()
        r = dict(cx=ops.get("cx", 0), gates=len(qc.data), depth=qc.depth(),
                 err=phase_error(U, Operator(qc).data), ns=sorted(ts)[len(ts) // 2])
        try:
            w = TwoQubitWeylDecomposition(U); r["weyl"] = (w.a, w.b, w.c)
        except Exception:
            r["weyl"] = None
        out[label] = r
    return out

def mark(m, q):
    if m is None or q is None: return "  "
    return "✅" if m <= q else "❌"

def okmark(cond):
    return "✅ ok  " if cond else "❌ FAIL"

def main():
    if len(sys.argv) < 2: print(__doc__); sys.exit(1)
    M, G = parse_mojo(sys.argv[1])
    Q = {} if "--no-qiskit" in sys.argv else run_qiskit()
    self_bad = [l for l, r in M.items() if r["err"] > TOL]
    redo_bad = [l for l in M if phase_error(matrix_for(l), unitary_from_gates(G[l])) > TOL]
    name_bad = [l for l in M if any(n not in ("RZ", "RY", "CX") for n, _, _ in G[l])]
    over_bad = [l for l, r in M.items() if r["cx"] > 3]
    print(LINE); print("CORRECTNESS")
    print(f"  {okmark(len(M) == len(ALL_LABELS))}  rows from Mojo              : {len(M)}/{len(ALL_LABELS)}")
    print(f"  {okmark(not self_bad)}  Mojo self-check err <= {TOL:g} : {len(self_bad)} wrong")
    print(f"  {okmark(not redo_bad)}  Python re-check (numpy)     : {len(redo_bad)} wrong")
    print(f"  {okmark(not name_bad)}  only RZ / RY / CX           : {len(name_bad)} wrong")
    print(f"  {okmark(not over_bad)}  CX <= 3                     : {len(over_bad)} over "
          f"(4 = fell back to exact 4-CX template)")
    if Q:
        qbad = [l for l, r in Q.items() if r["err"] > TOL]
        print(f"  {okmark(not qbad)}  Qiskit err <= {TOL:g}         : {len(qbad)} wrong")
    for l in (self_bad + redo_bad + name_bad + over_bad)[:10]:
        print("      FAIL:", l, M.get(l, {}))
    print("\n" + LINE); print("SPECIAL GATES - CX count   (plain / dressed with random local gates)")
    print(f"{'case':>9} | {'Weyl (a, b, c)':>24} | {'exp':>3} | {'Mojo':>7} | {'Qiskit':>7} | "
          f"{'M gates':>7} {'Q gates':>7} | cx")
    for name in SPECIALS:
        m0, m1 = M.get(name, {}).get("cx"), M.get(name + "-d", {}).get("cx")
        q0, q1 = Q.get(name, {}).get("cx"), Q.get(name + "-d", {}).get("cx")
        w = Q.get(name, {}).get("weyl")
        ws = f"({w[0]:.3f}, {w[1]:.3f}, {w[2]:.3f})" if w else "-"
        exp = EXPECTED[name]
        ref = exp if exp is not None else q0
        ok = all(x is not None and ref is not None and x <= ref for x in (m0, m1))
        mg = f"{M.get(name, {}).get('gates', '-')}/{M.get(name + '-d', {}).get('gates', '-')}"
        qg = f"{Q.get(name, {}).get('gates', '-')}/{Q.get(name + '-d', {}).get('gates', '-')}"
        print(f"{name:>9} | {ws:>24} | {exp if exp is not None else '-':>3} | {m0}/{m1:<5} | "
              f"{q0}/{q1:<5} | {mg:>7} {qg:>7} | {'✅' if ok else '❌'}")
    print("\n" + LINE); print(f"RANDOM ({N_RAND} unitaries)")
    rl = [f"rand{k}" for k in range(N_RAND)]
    def mean(D, f):
        v = [D[l][f] for l in rl if l in D]; return sum(v) / len(v) if v else float("nan")
    print(f"{'':>8} | {'cx':>6} {'gates':>7} {'depth':>7} | {'max err':>9}")
    for nm, D in (("Mojo", M), ("Qiskit", Q)):
        if not D: continue
        me = max((D[l]["err"] for l in rl if l in D), default=float("nan"))
        print(f"{nm:>8} | {mean(D, 'cx'):6.2f} {mean(D, 'gates'):7.2f} {mean(D, 'depth'):7.2f} | {me:9.1e}")
    print(f"  CX histogram Mojo  : {dict(sorted(Counter(M[l]['cx'] for l in rl if l in M).items()))}")
    if Q:
        print(f"  CX histogram Qiskit: {dict(sorted(Counter(Q[l]['cx'] for l in rl if l in Q).items()))}")
        for f in ("cx", "gates", "depth"):
            w = t = lo = 0
            for l in rl:
                if l not in M or l not in Q: continue
                a, b = M[l][f], Q[l][f]
                if a < b: w += 1
                elif a == b: t += 1
                else: lo += 1
            sym = "✅" if lo == 0 else ("⚠️" if w + t >= lo else "❌")
            print(f"  {sym} {f:<6}: win {w:>3} | tie {t:>3} | loss {lo:>3}")
    print("\n" + LINE); print("TIME (µs per decomposition, median)")
    def med(D, labels):
        v = sorted(D[l]["ns"] for l in labels if l in D); return v[len(v) // 2] if v else None
    groups = (("special", [x for n in SPECIALS for x in (n, n + "-d")]), ("random", rl))
    print(f"{'group':>8} | {'Mojo':>9} {'Qiskit':>9} {'x':>7}")
    for gname, labels in groups:
        a, b = med(M, labels), med(Q, labels)
        sp = f"{b / a:6.1f}x" if a and b else f"{'-':>7}"
        print(f"{gname:>8} | {a / 1000 if a else float('nan'):9.1f} "
              f"{b / 1000 if b else float('nan'):9.1f} {sp} {mark(a, b)}")
    print(LINE)

if __name__ == "__main__":
    main()