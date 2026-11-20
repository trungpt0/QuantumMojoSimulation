import sys, time
from collections import defaultdict
import numpy as np

RNG_SHIFT = 16

class LCG:

    def __init__(self, seed): self.s = seed & 0x7FFFFFFF

    def next(self):
        self.s = (self.s * 1664525 + 1013904223) & 0x7FFFFFFF
        return self.s

    def below(self, n):
        return (self.next() >> 8) % n

def rand_perm(n, seed):
    rng = LCG(seed); p = list(range(n))
    for i in range(n - 1, 0, -1):
        j = rng.below(i + 1); p[i], p[j] = p[j], p[i]
    return p

def invertible(rows, n):
    a = rows[:]
    for c in range(n):
        p = next((r for r in range(c, n) if (a[r] >> c) & 1), None)
        if p is None: return False
        a[c], a[p] = a[p], a[c]
        for r in range(c + 1, n):
            if (a[r] >> c) & 1: a[r] ^= a[c]
    return True

def rand_invertible(n, seed):
    rng = LCG(seed)
    for _ in range(10000):
        rows = []
        for r in range(n):
            v = 0
            for c in range(n):
                if (rng.next() >> RNG_SHIFT) & 1: v |= 1 << c
            rows.append(v)
        if invertible(rows, n): return rows
    return [1 << i for i in range(n)]

def structured(kind, n):
    if kind == "prefix": return [(1 << (i + 1)) - 1 for i in range(n)]
    if kind == "upper":  return [((1 << n) - 1) & ~((1 << i) - 1) for i in range(n)]
    if kind == "chain":  return [(1 << i) | ((1 << (i - 1)) if i > 0 else 0) for i in range(n)]
    if kind == "rperm":
        p = rand_perm(n, 200 + n); return [1 << p[i] for i in range(n)]
    return [1 << i for i in range(n)]

def matrix_for(kind, n, s):
    return rand_invertible(n, 1000 * n + s) if kind in ("random", "tiny") else structured(kind, n)

TINY_N = [1, 2, 3, 5, 7, 9]
RAND_N = [4, 6, 8, 10, 12, 16, 20, 24, 32, 48, 64, 96, 128]
STRUCT_KINDS = ["prefix", "upper", "chain", "rperm"]
STRUCT_N = [8, 16, 32]

def samples_for(n):
    return 20 if n <= 16 else 12 if n <= 32 else 6 if n <= 64 else 3

def auto_section(n):
    lg = 0
    while (1 << (lg + 1)) <= n: lg += 1
    return min(8, max(1, (lg + 1) // 2))

def apply_cx(pairs, n):
    rows = [1 << i for i in range(n)]
    for c, t in pairs: rows[t] ^= rows[c]
    return rows

def transpose(rows, n):
    return [sum(((rows[i] >> j) & 1) << i for i in range(n)) for j in range(n)]

def gf2_inv(rows, n):
    a = rows[:]; inv = [1 << i for i in range(n)]
    for c in range(n):
        p = next(r for r in range(c, n) if (a[r] >> c) & 1)
        a[c], a[p] = a[p], a[c]; inv[c], inv[p] = inv[p], inv[c]
        for r in range(n):
            if r != c and (a[r] >> c) & 1: a[r] ^= a[c]; inv[r] ^= inv[c]
    return inv

def layer_depth(pairs):
    d = {}
    for a, b in pairs:
        m = max(d.get(a, 0), d.get(b, 0)) + 1; d[a] = d[b] = m
    return max(d.values()) if d else 0

def adjacent(pairs): 
    return all(abs(c - t) == 1 for c, t in pairs)

POST = {
    "id": lambda p: p, 
    "rev": lambda p: p[::-1],
    "swap": lambda p: [(t, c) for c, t in p],
    "revswap": lambda p: [(t, c) for c, t in p[::-1]]
}

def variant_matrix(rows, n, k):
    if k == 0: return rows
    if k == 1: return transpose(rows, n)
    inv = gf2_inv(rows, n)
    return inv if k == 2 else transpose(inv, n)

VARIANT_BACK = [POST["id"], POST["revswap"], POST["rev"], POST["swap"]]

def med(xs):
    xs = sorted(xs); return xs[len(xs) // 2]

class QiskitRunner:

    def __init__(self):
        from qiskit.synthesis.linear import synth_cnot_count_full_pmh, synth_cnot_depth_line_kms
        self.pmh = synth_cnot_count_full_pmh
        self.kms = synth_cnot_depth_line_kms
        self.conv = {}

    @staticmethod
    def pairs(qc):
        return [(qc.find_bit(i.qubits[0]).index, qc.find_bit(i.qubits[1]).index)
                for i in qc.data if len(i.qubits) == 2]

    @staticmethod
    def to_np(rows, n):
        return np.array([[(rows[i] >> j) & 1 for j in range(n)] for i in range(n)], dtype=bool)

    def call(self, which, rows, n, m):
        mat = self.to_np(rows, n)
        if which == "pmh":
            try: return self.pmh(mat, section_size=m)
            except TypeError: return self.pmh(mat.astype(int), section_size=m)
        return self.kms(mat)

    def detect(self, which):
        n = 6; rows = rand_invertible(n, 4242)
        for k in range(4):
            try: p = self.pairs(self.call(which, variant_matrix(rows, n, k), n, 2))
            except Exception: continue
            for name, fn in POST.items():
                if apply_cx(fn(p), n) == rows:
                    self.conv[which] = (k, name); return
        self.conv[which] = None

    def circuit_for(self, which, rows, n, m):
        if self.conv.get(which) is None: return None
        k, post = self.conv[which]
        try: qc = self.call(which, variant_matrix(rows, n, k), n, m)
        except Exception: return None
        p = POST[post](self.pairs(qc))
        return p if apply_cx(p, n) == rows else None

    def timed(self, which, rows, n, m, reps=3):
        k, _ = self.conv[which]; v = variant_matrix(rows, n, k); ts = []
        for _ in range(reps):
            t0 = time.monotonic_ns(); self.call(which, v, n, m); ts.append(time.monotonic_ns() - t0)
        return med(ts)

    def best(self, which, rows, n, sections):
        best, total = None, 0
        for k in range(4):
            v = variant_matrix(rows, n, k)
            for m in sections:
                t0 = time.monotonic_ns()
                p = self.circuit_for(which, v, n, m)
                total += time.monotonic_ns() - t0
                if p is None: continue
                p = VARIANT_BACK[k](p)
                if apply_cx(p, n) == rows and (best is None or len(p) < len(best)): best = p
        return best, total

def run_qiskit():
    try:
        q = QiskitRunner()
    except Exception as e:
        print(f"# Could not load Qiskit: {e}"); return {}
    q.detect("pmh"); q.detect("kms")
    print(f"# Qiskit convention: {q.conv}")
    res = {}
    def put(label, p, ns):
        res[label] = None if p is None else dict(cx=len(p), depth=layer_depth(p), ns=ns, adj=int(adjacent(p)))
    cases = [("tiny", n, s) for n in TINY_N for s in range(3)]
    cases += [("random", n, s) for n in RAND_N for s in range(samples_for(n))]
    cases += [(k, n, 0) for k in STRUCT_KINDS for n in STRUCT_N]
    for kind, n, s in cases:
        rows = matrix_for(kind, n, s); tag = f"{kind}_{n}_{s}"
        for lab, m in (("qpmh2", 2), ("qpmhauto", auto_section(n))):
            p = q.circuit_for("pmh", rows, n, m)
            put(f"{tag}_{lab}", p, q.timed("pmh", rows, n, m) if p else 0)
        if n <= 64:
            p, ns = q.best("pmh", rows, n, range(1, min(8, n) + 1))
            put(f"{tag}_qpmhbest", p, ns)
        p = q.circuit_for("kms", rows, n, 0)
        put(f"{tag}_qkms", p, q.timed("kms", rows, n, 0) if p else 0)
    return res

def parse_mojo(path):
    res, gates = {}, defaultdict(list)
    for line in open(path):
        p = line.split()
        if line.startswith("RESULT"):
            res[p[1]] = {k: int(v) for k, v in (x.split("=", 1) for x in p[2:])}
        elif line.startswith("GATE"):
            gates[p[1]].append((int(p[2]), int(p[3])))
    return res, gates

def split(label):
    kind, n, s, method = label.split("_", 3); return kind, int(n), int(s), method

TOL = 0.05
LINE = "=" * 100

def mean(d, kind, n, method, field="cx"):
    v = [r[field] for (k, nn, s, m), r in d.items()
         if k == kind and nn == n and m == method and r is not None]
    return sum(v) / len(v) if v else None

def f(x, w=7, p=1): 
    return f"{'-':>{w}}" if x is None else f"{x:>{w}.{p}f}"

def mark(m, q, tol=TOL):
    if m is None or q is None: return "  "
    if m <= q: return "✅"
    if m <= q * (1 + tol): return "⚠️"
    return "❌"

def okmark(cond): 
    return "✅ ok  " if cond else "❌ FAIL"

def is_line(method): 
    return method.startswith("lnn") or method.startswith("kms")

def has(M, method): 
    return any(k[3] == method for k in M)

def report_correctness(mres, mgates, M, Q, summary):
    bad = [l for l, r in mres.items() if r.get("ok") != 1]
    badadj = [l for l, r in mres.items() if is_line(split(l)[3]) and r.get("adj") != 1]
    over5n = [l for l, r in mres.items() if split(l)[3].startswith("kms") and r.get("depth", 0) > 5 * split(l)[1]]
    redo = 0
    for label, pairs in mgates.items():
        kind, n, s, method = split(label)
        good = apply_cx(pairs, n) == matrix_for(kind, n, s)
        if is_line(method): good = good and adjacent(pairs)
        if method.startswith("kms"): good = good and layer_depth(pairs) <= 5 * n
        redo += 0 if good else 1
    qbad = [k for k, r in Q.items() if r is None]
    qkms_over = [k for k, r in Q.items()
                 if r is not None and k[3] == "qkms" and r["depth"] > 5 * k[1]]
    print(LINE)
    print("CORRECTNESS")
    print(f"  {okmark(not bad)}  Mojo self-check (ok=1)          : {len(mres) - len(bad)}/{len(mres)}")
    print(f"  {okmark(not badadj)}  LNN/KMS adjacent CX only        : {len(badadj)} wrong")
    print(f"  {okmark(redo == 0)}  Python re-check {len(mgates):>4} dumped      : {redo} wrong")
    if has(M, "kms"):
        print(f"  {okmark(not over5n)}  Mojo KMS depth <= 5n            : {len(over5n)} exceeded")
    if Q:
        print(f"  {okmark(not qkms_over)}  Qiskit KMS depth <= 5n          : {len(qkms_over)} exceeded")
    if qbad:
        print(f"  ⚠️       Qiskit could not build {len(qbad)} rows (section size does not divide n?)")
    for l in (bad + badadj + over5n)[:10]:
        print("        FAIL:", l)
    summary.append(("Mojo correctness", not bad and not badadj and redo == 0 and not over5n))

def report_all_to_all(M, Q, summary):
    print("\n" + LINE)
    print("RANDOM all-to-all - mean CX (lower is better)   [pmh2 vs Qpmh2 | auto vs QpmhB]")
    print(f"{'n':>4} | {'gauss':>7} {'pmh2':>7} {'pmhA':>7} {'pmhB':>7} {'auto':>7} | "
          f"{'Qpmh2':>7} {'QpmhA':>7} {'QpmhB':>7} | {'auto/QB':>7} | pmh2 auto")
    w_pmh2, w_auto = [], []
    for n in RAND_N:
        mv = [mean(M, "random", n, m) for m in ("gauss", "pmh2", "pmhauto", "pmhbest", "auto")]
        qv = [mean(Q, "random", n, m) for m in ("qpmh2", "qpmhauto", "qpmhbest")]
        qb = qv[2] if qv[2] is not None else qv[1]
        ratio = f"{mv[4] / qb:7.3f}" if mv[4] and qb else f"{'-':>7}"
        if mv[1] is not None and qv[0] is not None: w_pmh2.append(mv[1] <= qv[0])
        if mv[4] is not None and qb is not None: w_auto.append(mv[4] <= qb)
        print(f"{n:>4} | " + " ".join(f(x) for x in mv) + " | " + " ".join(f(x) for x in qv) +
              f" | {ratio} |  {mark(mv[1], qv[0])}   {mark(mv[4], qb)}")
    if w_pmh2: summary.append((f"All-to-all pmh2 <= Qiskit pmh2 ({sum(w_pmh2)}/{len(w_pmh2)} n)", all(w_pmh2)))
    if w_auto: summary.append((f"All-to-all auto <= Qiskit best ({sum(w_auto)}/{len(w_auto)} n)", all(w_auto)))

def report_lnn(M, Q, summary):
    show_kms = has(M, "kms")
    print("\n" + LINE)
    print("LNN (adjacent CX only) - mean CX / depth   [marks: vs Qiskit KMS]")
    hdr = f"{'n':>4} | {'lnnB':>8}"
    if show_kms: hdr += f" {'kms':>8} {'kmsB':>8}"
    hdr += f" {'Qkms':>8} | {'lnnB d':>7}"
    if show_kms: hdr += f" {'kms d':>7} {'kmsB d':>7}"
    hdr += f" {'Qkms d':>7} | {'5n':>4} | lnnB:cx  d"
    if show_kms: hdr += " | kms:cx  d | kmsB:cx  d"
    print(hdr)
    acc = defaultdict(list)
    for n in RAND_N:
        qc, qd = mean(Q, "random", n, "qkms"), mean(Q, "random", n, "qkms", "depth")
        lc, ld = mean(M, "random", n, "lnnbest"), mean(M, "random", n, "lnnbest", "depth")
        row = f"{n:>4} | {f(lc, 8)}"
        if show_kms:
            kc, kbc = mean(M, "random", n, "kms"), mean(M, "random", n, "kmsbest")
            kd, kbd = mean(M, "random", n, "kms", "depth"), mean(M, "random", n, "kmsbest", "depth")
            row += f" {f(kc, 8)} {f(kbc, 8)}"
        row += f" {f(qc, 8)} | {f(ld)}"
        if show_kms: row += f" {f(kd)} {f(kbd)}"
        row += f" {f(qd)} | {5 * n:>4} |    {mark(lc, qc)}   {mark(ld, qd)}"
        for key, mval, qval in (("lnnB cx", lc, qc), ("lnnB depth", ld, qd)):
            if mval is not None and qval is not None: acc[key].append(mval <= qval)
        if show_kms:
            row += f" |   {mark(kc, qc)}   {mark(kd, qd)} |    {mark(kbc, qc)}   {mark(kbd, qd)}"
            for key, mval, qval in (("kms cx", kc, qc), ("kms depth", kd, qd),
                                    ("kmsB cx", kbc, qc), ("kmsB depth", kbd, qd)):
                if mval is not None and qval is not None: acc[key].append(mval <= qval)
        print(row)
    INFO = {"lnnB depth", "kms cx", "kms depth"}       # reference only, not a target
    for key in ("lnnB cx", "lnnB depth", "kms cx", "kms depth", "kmsB cx", "kmsB depth"):
        if acc[key]:
            text = f"LNN {key} <= Qiskit KMS ({sum(acc[key])}/{len(acc[key])} n)"
            if key in INFO:
                print(f"  ℹ️  {text}  (reference only)")
            else:
                summary.append((text, all(acc[key])))

def report_structured(M, Q):
    show_kms = has(M, "kms")
    print("\n" + LINE)
    print("STRUCTURED - CX   [all: auto vs QpmhB | lnn: lnnB vs Qkms" + (" | kms: kmsB vs Qkms]" if show_kms else "]"))
    cols = ["gauss", "pmh2", "pmhbest", "auto", "lnnbest"] + (["kmsbest"] if show_kms else [])
    qcols = ["qpmh2", "qpmhbest", "qkms"]
    print(f"{'case':>10} | " + " ".join(f"{c:>7}" for c in cols) + " | " +
          " ".join(f"{c:>8}" for c in qcols) + " | all  lnn" + ("  kms" if show_kms else ""))
    for kind in STRUCT_KINDS:
        for n in STRUCT_N:
            mv = {c: mean(M, kind, n, c) for c in cols}
            qv = {c: mean(Q, kind, n, c) for c in qcols}
            row = (f"{kind + '_' + str(n):>10} | " + " ".join(f(mv[c], 7, 0) for c in cols) + " | " +
                   " ".join(f(qv[c], 8, 0) for c in qcols) +
                   f" |  {mark(mv['auto'], qv['qpmhbest'])}   {mark(mv['lnnbest'], qv['qkms'])}")
            if show_kms: row += f"   {mark(mv['kmsbest'], qv['qkms'])}"
            print(row)

def report_duels(M, Q, summary):
    print("\n" + LINE)
    print("WIN / TIE / LOSS per sample")
    def duel(mm, qm, field):
        w = t = l = 0
        for key, r in M.items():
            if key[3] != mm or r is None: continue
            q = Q.get((key[0], key[1], key[2], qm))
            if not q: continue
            if r[field] < q[field]: w += 1
            elif r[field] == q[field]: t += 1
            else: l += 1
        return w, t, l
    duels = [("pmh2", "qpmh2", "cx"), ("pmhbest", "qpmhbest", "cx"), ("auto", "qpmhbest", "cx"),
             ("lnnbest", "qkms", "cx"), ("lnnbest", "qkms", "depth")]
    if has(M, "kms"):
        duels += [("kms", "qkms", "cx"), ("kms", "qkms", "depth"),
                  ("kmsbest", "qkms", "cx"), ("kmsbest", "qkms", "depth")]
    for mm, qm, fld in duels:
        w, t, l = duel(mm, qm, fld)
        tot = w + t + l
        if tot == 0: continue
        sym = "✅" if l == 0 else ("⚠️" if w + t >= l else "❌")
        print(f"  {sym} Mojo {mm:<8} vs Qiskit {qm:<9} ({fld:<5}): "
              f"win {w:>3} | tie {t:>3} | loss {l:>3}   ({100 * (w + t) / tot:5.1f}% not worse)")

def report_timing(M, Q, summary):
    print("\n" + LINE)
    print("TIME (µs, median; Qiskit includes QuantumCircuit construction)")
    show_kms = has(M, "kms")
    hdr = (f"{'n':>4} | {'pmh2':>9} {'Qpmh2':>9} {'x':>6}   | {'auto':>9} {'QpmhB':>9} {'x':>6}   | "
           f"{'lnnB':>9} {'Qkms':>9} {'x':>6}  ")
    if show_kms:
        hdr += f" | {'kms':>9} {'Qkms':>9} {'x':>6}"
    print(hdr)
    def us(x): return f(x / 1000 if x else None, 9)
    def sp(a, b): return f"{b / a:5.1f}x" if a and b else f"{'-':>6}"
    faster = []
    for n in RAND_N:
        pairs = [(mean(M, "random", n, "pmh2", "ns"), mean(Q, "random", n, "qpmh2", "ns")),
                 (mean(M, "random", n, "auto", "ns"), mean(Q, "random", n, "qpmhbest", "ns")),
                 (mean(M, "random", n, "lnnbest", "ns"), mean(Q, "random", n, "qkms", "ns"))]
        if show_kms:
            pairs.append((mean(M, "random", n, "kms", "ns"), mean(Q, "random", n, "qkms", "ns")))
        cells = []
        for a, b in pairs:
            if a and b:
                faster.append(a <= b)
            cells.append(f"{us(a)} {us(b)} {sp(a, b)} {mark(a, b)}")
        print(f"{n:>4} | " + " | ".join(cells))
    if faster:
        summary.append((f"Mojo faster than Qiskit ({sum(faster)}/{len(faster)} cells)", all(faster)))

def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    mres, mgates = parse_mojo(sys.argv[1])
    M = {split(l): r for l, r in mres.items()}
    Q = {} if "--no-qiskit" in sys.argv else {split(l): r for l, r in run_qiskit().items()}
    summary = []
    report_correctness(mres, mgates, M, Q, summary)
    report_all_to_all(M, Q, summary)
    report_lnn(M, Q, summary)
    report_structured(M, Q)
    report_duels(M, Q, summary)
    report_timing(M, Q, summary)
    print("\n" + LINE)
    print("SUMMARY")
    for text, good in summary:
        print(f"  {'✅' if good else '❌'}  {text}")
    print(LINE)

if __name__ == "__main__":
    main()