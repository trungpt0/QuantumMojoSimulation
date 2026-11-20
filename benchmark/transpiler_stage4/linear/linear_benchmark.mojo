from qmath import BitMatrix, bm_identity, bm_is_invertible, ops_apply, ops_depth, ops_is_adjacent
from transpiler import linear_ops
from std.time import monotonic

struct LCG(Copyable, Movable):
    var s: Int
    def __init__(out self, seed: Int):
        self.s = seed & 0x7FFFFFFF
    def next(mut self) -> Int:
        self.s = (self.s * 1664525 + 1013904223) & 0x7FFFFFFF
        return self.s
    def below(mut self, n: Int) -> Int:
        return (self.next() >> 8) % n

def rand_perm(n: Int, seed: Int) -> List[Int]:
    var rng = LCG(seed)
    var p = List[Int]()
    for i in range(n):
        p.append(i)
    for i in range(n - 1, 0, -1):
        var j = rng.below(i + 1)
        var tmp = p[i]
        p[i] = p[j]
        p[j] = tmp
    return p^

def rand_invertible(n: Int, seed: Int) -> BitMatrix:
    var rng = LCG(seed)
    for _ in range(10000):
        var a = BitMatrix(n)
        for r in range(n):
            for c in range(n):
                if ((rng.next() >> 16) & 1) == 1:
                    a.set_one(r, c)
        if bm_is_invertible(a):
            return a^
    return bm_identity(n)

def structured(kind: String, n: Int) -> BitMatrix:
    var a = BitMatrix(n)
    if kind == "prefix":
        for i in range(n):
            for j in range(i + 1):
                a.set_one(i, j)
    elif kind == "upper":
        for i in range(n):
            for j in range(i, n):
                a.set_one(i, j)
    elif kind == "chain":
        for i in range(n):
            a.set_one(i, i)
            if i > 0:
                a.set_one(i, i - 1)
    elif kind == "rperm":
        var p = rand_perm(n, 200 + n)
        for i in range(n):
            a.set_one(i, p[i])
    else:
        for i in range(n):
            a.set_one(i, i)
    return a^

def samples_for(n: Int) -> Int:
    if n <= 16:
        return 20
    if n <= 32:
        return 12
    if n <= 64:
        return 6
    return 3

def median(mut ts: List[Int]) -> Int:
    for i in range(1, len(ts)):
        var key = ts[i]
        var j = i - 1
        while j >= 0 and ts[j] > key:
            ts[j + 1] = ts[j]
            j -= 1
        ts[j + 1] = key
    return ts[len(ts) // 2]

def synth(a: BitMatrix, method: String) raises -> List[Int]:
    if method == "gauss":
        return linear_ops(a, "gauss", 0, False)
    if method == "pmh2":
        return linear_ops(a, "pmh", 2, False)
    if method == "pmhauto":
        return linear_ops(a, "pmh", 0, False)
    if method == "pmhbest":
        return linear_ops(a, "pmh_best", 0, True)
    if method == "auto":
        return linear_ops(a, "auto", 0, True)
    if method == "lnn":
        return linear_ops(a, "lnn", 0, False)
    if method == "kms":
        return linear_ops(a, "kms", 0, False)
    if method == "kmsbest":
        return linear_ops(a, "kms_best", 0, True)
    return linear_ops(a, "lnn_best", 0, True)

def run_one(label: String, a: BitMatrix, method: String, dump: Bool) raises:
    var n = a.n
    try:
        var ops = synth(a, method)
        var reps = 5
        if n >= 64:
            reps = 1 if (method == "pmhbest" or method == "auto" or method == "lnnbest") else 3
        var ts = List[Int]()
        for _ in range(reps):
            var t0 = monotonic()
            var w = synth(a, method)
            ts.append(Int(monotonic() - t0))
            _ = len(w)
        var ok = 1 if ops_apply(ops, n).equals(a) else 0
        var adj = 1 if ops_is_adjacent(ops) else 0
        print("RESULT", label,
              "cx=" + String(len(ops) // 2),
              "depth=" + String(ops_depth(ops, n)),
              "ns=" + String(median(ts)),
              "ok=" + String(ok),
              "adj=" + String(adj))
        if dump:
            for i in range(len(ops) // 2):
                print("GATE", label, ops[2 * i], ops[2 * i + 1])
    except e:
        print("# ERROR", label, ":", e)

def run_all(tag: String, a: BitMatrix, dump: Bool) raises:
     for m in ["gauss", "pmh2", "pmhauto", "pmhbest", "auto", "lnn", "lnnbest", "kms", "kmsbest"]:
        run_one(tag + "_" + String(m), a, String(m), dump)

def main() raises:
    print("# Mojo linear synthesis benchmark")
    for n in [1, 2, 3, 5, 7, 9]:
        for s in range(3):
            run_all("tiny_" + String(n) + "_" + String(s), rand_invertible(n, 1000 * n + s), True)
    for n in [4, 6, 8, 10, 12, 16, 20, 24, 32, 48, 64, 96, 128]:
        for s in range(samples_for(n)):
            run_all("random_" + String(n) + "_" + String(s),
                    rand_invertible(n, 1000 * n + s), s == 0 and n <= 32)
    for kind in ["prefix", "upper", "chain", "rperm"]:
        for n in [8, 16, 32]:
            run_all(String(kind) + "_" + String(n) + "_0", structured(String(kind), n), True)
    print("# DONE")