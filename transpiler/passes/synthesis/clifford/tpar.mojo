from dagcircuit import DAGCircuit
from gates import GateOp
from qmath import nummojo

struct F2Vector(Copyable, Movable):
    var bits: Int
    var nq: Int

    def __init__(out self, bits: Int, nq: Int):
        self.bits = bits
        self.nq = nq

    def equals(self, other: F2Vector) -> Bool:
        return self.bits == other.bits

    def xor(self, other: F2Vector) -> F2Vector:
        return F2Vector(self.bits ^ other.bits, self.nq)

    def is_zero(self) -> Bool:
        return self.bits == 0

struct PhaseEntry(Copyable, Movable):
    var coeff: Int
    var func: F2Vector

    def __init__(out self, coeff: Int, func: F2Vector):
        self.coeff = ((coeff % 8) + 8) % 8
        self.func = func.copy()

    def equals(self, other: PhaseEntry) -> Bool:
        return self.coeff == other.coeff and self.func.equals(other.func)

struct HadamardContext(Copyable, Movable):
    var qubit: Int
    var QI: List[F2Vector]
    var QO: List[F2Vector]
    var nq: Int

    def __init__(out self, qubit: Int, QI: List[F2Vector], QO: List[F2Vector], nq: Int):
        self.qubit = qubit
        self.QI = List[F2Vector]()
        self.QO = List[F2Vector]()
        self.nq = nq
        for i in range(len(QI)):
            self.QI.append(QI[i].copy())
        for i in range(len(QO)):
            self.QO.append(QO[i].copy())

struct StateTracker:
    var n_orig: Int
    var n_total: Int
    var Q: List[F2Vector]

    def __init__(out self, nq: Int):
        self.n_orig = nq
        self.n_total = nq
        self.Q = List[F2Vector]()
        for i in range(nq):
            self.Q.append(F2Vector(1 << i, nq))

    def apply_cx(mut self, ctrl: Int, targ: Int):
        var new_bits = self.Q[targ].bits ^ self.Q[ctrl].bits
        self.Q[targ] = F2Vector(new_bits, self.n_total)

    def apply_h(mut self, q: Int) -> Tuple[List[F2Vector], List[F2Vector]]:
        var QI = List[F2Vector]()
        for i in range(self.n_orig):
            QI.append(self.Q[i].copy())
        var path_var = self.n_total
        self.n_total += 1
        self.Q[q] = F2Vector(1 << path_var, self.n_total)
        var QO = List[F2Vector]()
        for i in range(self.n_orig):
            QO.append(self.Q[i].copy())
        return (QI^, QO^)

    def apply_x(mut self, q: Int):
        pass

    def get_state_copy(self) -> List[F2Vector]:
        var state_copy = List[F2Vector]()
        for i in range(self.n_orig):
            state_copy.append(self.Q[i].copy())
        return state_copy^

struct PhasePoly(Copyable, Movable):
    var nq: Int

    def __init__(out self, nq: Int):
        self.nq = nq

    def _t_coeff(self, name: String) -> Int:
        if name == "T": return 1
        if name == "S": return 2
        if name == "Z": return 4
        if name == "Sdg": return 6
        if name == "Tdg": return 7
        return 0

    def _is_clifford_t(self, name: String) -> Bool:
        return (name == "X" or name == "Y" or name == "Z" or
                name == "S" or name == "Sdg" or
                name == "H" or name == "CX" or
                name == "T" or name == "Tdg")

    def compute(self, gates: List[GateOp]) -> Tuple[
        List[PhaseEntry],       # S: phase entries
        List[F2Vector],         # Q: linear Boolean functions
        List[HadamardContext],  # H: hadamard contexts
        List[GateOp],           # Non-Clifford gates
    ]:
        var tracker = StateTracker(self.nq)
        var entries = List[PhaseEntry]()
        var h_ctxs = List[HadamardContext]()
        var passthru = List[GateOp]()
        for gi in range(len(gates)):
            var gate = gates[gi].copy()
            var name = gate.name
            if name == "CX":
                tracker.apply_cx(gate.qubit[0], gate.qubit[1])
            elif name == "X":
                tracker.apply_x(gate.qubit[0])
            elif name == "Y":
                tracker.apply_x(gate.qubit[0])
                var q = gate.qubit[0]
                entries.append(PhaseEntry(4, tracker.Q[q]))
            elif name == "H":
                var q = gate.qubit[0]
                var qiqo = tracker.apply_h(q)
                var QI = qiqo[0].copy()
                var QO = qiqo[1].copy()
                h_ctxs.append(HadamardContext(q, QI, QO, self.nq))
            elif name == "T" or name == "S" or name == "Z" or name == "Sdg" or name == "Tdg":
                var q = gate.qubit[0]
                var coeff = self._t_coeff(name)
                entries.append(PhaseEntry(coeff, tracker.Q[q]))
            else:
                passthru.append(gate^)
        var Q = tracker.get_state_copy()
        return (entries^, Q^, h_ctxs^, passthru^)

struct RowReduce(Copyable, Movable):
    var vectors: List[F2Vector]
    var gates: List[GateOp]

    def __init__(out self, vectors: List[F2Vector], gates: List[GateOp]):
        self.vectors = vectors.copy()
        self.gates = gates.copy()

def in_span(f: F2Vector, vecs: List[F2Vector]) -> Bool:
    var basis = List[Int]()
    for i in range(len(vecs)):
        var v = vecs[i].bits
        for j in range(len(basis)):
            v = min(v, v ^ basis[j])
        if v != 0:
            basis.append(v)
    var v = f.bits
    for j in range(len(basis)):
        v = min(v, v ^ basis[j])
    return v == 0

def gaussian_rank(vecs: List[F2Vector]) -> Int:
    var basis = List[Int]()
    for i in range(len(vecs)):
        var v = vecs[i].bits
        for j in range(len(basis)):
            v = min(v, v ^ basis[j])
        if v != 0:
            basis.append(v)
    return len(basis)

def rank_of_subset(indices: List[Int], entries: List[PhaseEntry]) -> Int:
    var funcs = List[F2Vector]()
    for i in range(len(indices)):
        funcs.append(entries[indices[i]].func.copy())
    return gaussian_rank(funcs)

def independence_check(
    A_indices: List[Int],
    entries: List[PhaseEntry],
    QI: List[F2Vector],
    nq: Int
) -> Bool:
    var rank_QI = gaussian_rank(QI)
    var rank_A = rank_of_subset(A_indices, entries)
    var lhs = rank_QI - rank_A
    var rhs = nq - len(A_indices)
    return lhs <= rhs

def partition(
    s: Int,
    P: List[List[Int]],
    S_P: List[Int],
    entries: List[PhaseEntry],
    QI: List[F2Vector],
    nq: Int
) -> List[List[Int]]:
    var P_prime = List[List[Int]]()
    for pi in range(len(P)):
        var p = List[Int]()
        for j in range(len(p)): p.append(P[pi][j])
        P_prime.append(p.copy())
    var queue = List[Int]()
    var visited = List[Bool]()
    var MAX_ELEMS = len(entries) + 1
    var found_sink_block = -1
    var parent_elem = List[Int]()
    var parent_block = List[Int]()
    for _ in range(MAX_ELEMS):
        parent_elem.append(-1)
        parent_block.append(-1)
        visited.append(False)
    queue.append(s)
    visited[s] = True
    var head = 0
    while head < len(queue) and found_sink_block < 0:
        var curr = queue[head]
        head += 1
        for A in range(len(P_prime)):
            var A_prime = List[Int]()
            for ai in range(len(P_prime[A])):
                A_prime.append(P_prime[A][ai])
            A_prime.append(curr)
            if independence_check(A_prime, entries, QI, nq):
                found_sink_block = A
                parent_elem[curr] = parent_elem[curr]
                parent_block[curr] = A
                break
            for k in range(len(P_prime[A])):
                var u = P_prime[A][k]
                if visited[u]: continue
                var test_replace = List[Int]()
                for j in range(len(P_prime[A])):
                    if j != k: test_replace.append(P_prime[A][j])
                test_replace.append(curr)
                if independence_check(test_replace, entries, QI, nq):
                    visited[u] = True
                    parent_elem[u] = curr
                    parent_block[u] = A
                    queue.append(u)
        if found_sink_block >= 0: break
    if found_sink_block >= 0:
        var curr = queue[head - 1]
        var moves = List[Tuple[Int, Int]]()
        var c = curr
        while c != s:
            moves.append((c, parent_block[c]))
            c = parent_elem[c]
        moves.append((s, parent_block[curr]))
        for mi in range(len(moves)):
            var idx = moves[len(moves) - 1 - mi]
            var elem = idx[0]
            var dest = idx[1]
            for pi in range(len(P_prime)):
                var p = List[Int]()
                var removed = False
                for j in range(len(P_prime[pi])):
                    if P_prime[pi][j] == elem and not removed:
                        removed = True
                    else:
                        p.append(P_prime[pi][j])
                P_prime[pi] = p.copy()
            P_prime[dest].append(elem)
    else:
        var p = List[Int]()
        p.append(s)
        P_prime.append(p.copy())
    return P_prime^

def is_QI_eq_QO(QI: List[F2Vector], QO: List[F2Vector], nq: Int) -> Bool:
    for q in range(nq):
        if not QI[q].equals(QO[q]): return False
    return True

def infer_width(QI: List[F2Vector], QO: List[F2Vector], entries: List[PhaseEntry], nq: Int) -> Int:
    var maxbits = 1
    for i in range(len(QI)):
        var b = nummojo.bit_length(QI[i].bits)
        if b > maxbits: maxbits = b
    for i in range(len(QO)):
        var b = nummojo.bit_length(QO[i].bits)
        if b > maxbits: maxbits = b
    for i in range(len(entries)):
        var b = nummojo.bit_length(entries[i].func.bits)
        if b > maxbits: maxbits = b
    if maxbits < nq: maxbits = nq
    return maxbits

def emit_swap(mut gates: List[GateOp], mut rows: List[Int], a: Int, b: Int):
    var q1 = List[Int](); q1.append(a); q1.append(b)
    var q2 = List[Int](); q2.append(b); q2.append(a)
    gates.append(GateOp("CX", q1, List[Float64]()))
    rows[b] = rows[b] ^ rows[a]
    gates.append(GateOp("CX", q2, List[Float64]()))
    rows[a] = rows[a] ^ rows[b]
    gates.append(GateOp("CX", q1, List[Float64]()))
    rows[b] = rows[b] ^ rows[a]

def row_reduce(vecs: List[F2Vector], nq: Int, width: Int) -> RowReduce:
    var rows = List[Int]()
    for i in range(nq):
        rows.append(vecs[i].bits)
    var gates = List[GateOp]()
    var pivot = 0
    for col in range(width):
        if pivot >= nq: break
        var sel = -1
        for r in range(pivot, nq):
            if (rows[r] >> col) & 1 == 1:
                sel = r
                break
        if sel < 0:
            continue
        if sel != pivot:
            emit_swap(gates, rows, sel, pivot)
        for r in range(nq):
            if r == pivot: continue
            if (rows[r] >> col) & 1 == 1:
                rows[r] = rows[r] ^ rows[pivot]
                var ql = List[Int](); ql.append(pivot); ql.append(r)
                gates.append(GateOp("CX", ql, List[Float64]()))
        pivot += 1
    var out_vecs = List[F2Vector]()
    for i in range(nq):
        out_vecs.append(F2Vector(rows[i], width))
    return RowReduce(out_vecs, gates)

def linear_synth_same_basis(src: List[F2Vector], dst: List[F2Vector], nq: Int, width: Int) -> List[GateOp]:
    var red_src = row_reduce(src, nq, width)
    var red_dst = row_reduce(dst, nq, width)
    var gates = List[GateOp]()
    for i in range(len(red_src.gates)):
        gates.append(red_src.gates[i].copy())
    for i in range(len(red_dst.gates)):
        gates.append(red_dst.gates[len(red_dst.gates) - 1 - i].copy())
    return gates^

def synthesize(
    A: List[Int],
    entries: List[PhaseEntry],
    QI: List[F2Vector],
    QO: List[F2Vector],
    nq: Int
) -> List[GateOp]:
    var C = List[GateOp]()
    if len(A) == 0 and is_QI_eq_QO(QI, QO, nq):
        return C^
    var w = -1
    if w < 0:
        w = infer_width(QI, QO, entries, nq)
    # Compute A_prime ⊇ A s.t rank(A_prime) = rank(QI), |A_prime| = n
    var A_prime_vecs = List[F2Vector]()
    var A_prime_coeffs = List[Int]()
    for ai in range(len(A)):
        A_prime_vecs.append(entries[A[ai]].func.copy())
        A_prime_coeffs.append(entries[A[ai]].coeff)
    var rank_QI = gaussian_rank(QI)
    var qi_idx = 0
    while gaussian_rank(A_prime_vecs) < rank_QI and qi_idx < nq:
        var A_prime_vecs_test = List[F2Vector]()
        for j in range(len(A_prime_vecs)):
            A_prime_vecs_test.append(A_prime_vecs[j].copy())
        A_prime_vecs_test.append(QI[qi_idx].copy())
        if gaussian_rank(A_prime_vecs_test) > gaussian_rank(A_prime_vecs):
            A_prime_vecs.append(QI[qi_idx].copy())
            A_prime_coeffs.append(0)
        qi_idx += 1
    while len(A_prime_vecs) < nq:
        A_prime_vecs.append(F2Vector(0, w))
        A_prime_coeffs.append(0)
    # Synthesize {CNOT, X} circuit C1
    var C1 = linear_synth_same_basis(QI, A_prime_vecs, nq, w)
    # Synthesize {Z, P, T} circuit C2
    var C2 = List[GateOp]()
    for i in range(nq):
        var c = A_prime_coeffs[i]
        if c == 0:
            continue
        var ql = List[Int]()
        ql.append(i)
        if c == 1: 
            C2.append(GateOp("T", ql, List[Float64]()))
        elif c == 2: 
            C2.append(GateOp("S", ql, List[Float64]()))
        elif c == 3:
            C2.append(GateOp("S", ql, List[Float64]()))
            C2.append(GateOp("T", ql, List[Float64]()))
        elif c == 4:
            C2.append(GateOp("Z", ql, List[Float64]()))
        elif c == 5:
            C2.append(GateOp("Z", ql, List[Float64]()))
            C2.append(GateOp("T", ql, List[Float64]()))
        elif c == 6:
            C2.append(GateOp("Sdg", ql, List[Float64]()))
        elif c == 7:
            C2.append(GateOp("Tdg", ql, List[Float64]()))
    # Synthesize {CNOT, X, H} circuit C3
    var C3 = List[GateOp]()
    if is_QI_eq_QO(QI, QO, nq):
        for i in range(len(C1)):
            C3.append(C1[len(C1) - 1 - i].copy())
    else:
        var h_qubit = -1
        for q in range(nq):
            if not QI[q].equals(QO[q]):
                h_qubit = q
                break
        var target = List[F2Vector]()
        for q in range(nq):
            if q == h_qubit:
                target.append(A_prime_vecs[q].copy())
            else:
                target.append(QO[q].copy())
        var C3_linear = linear_synth_same_basis(A_prime_vecs, target, nq, w)
        for i in range(len(C3_linear)):
            C3.append(C3_linear[i].copy())
        if h_qubit >= 0:
            var qhl = List[Int]()
            qhl.append(h_qubit)
            C3.append(GateOp("H", qhl, List[Float64]()))
    # C = C1 + C2 + C3
    for i in range(len(C1)): C.append(C1[i].copy())
    for i in range(len(C2)): C.append(C2[i].copy())
    for i in range(len(C3)): C.append(C3[i].copy())
    return C^

def tpar_algorithm(gates: List[GateOp], nq: Int, passthrough: List[GateOp]) -> List[GateOp]:
    var SQH = PhasePoly(nq)
    var sqh_res = SQH.compute(gates)
    var S = sqh_res[0].copy()
    var Q = sqh_res[1].copy()
    var H = sqh_res[2].copy()
    if len(S) == 0:
        return gates.copy()
    var S_reduced = List[PhaseEntry]()
    var processed = List[Bool]()
    for _ in range(len(S)): processed.append(False)
    for i in range(len(S)):
        if processed[i]: continue
        var total = S[i].coeff
        processed[i] = True
        for j in range(i + 1, len(S)):
            if not processed[j] and S[i].func.equals(S[j].func):
                total = (total + S[j].coeff) % 8
                processed[j] = True
        if total % 8 != 0:
            S_reduced.append(PhaseEntry(total, S[i].func))
    if len(S_reduced) == 0:
        var structural = List[GateOp]()
        for i in range(len(gates)):
            var g = gates[i].copy()
            if g.name == "CX" or g.name == "H" or g.name == "X":
                structural.append(g^)
        return structural^
    var C_prime = List[GateOp]()
    var k = len(H)
    if k == 0:
        var final_ctx = HadamardContext(-1, Q, Q, nq)
        H.append(final_ctx^)
        k = 1
    var S_P = List[Int]()
    var S_nP = List[Int]()
    for i in range(len(S_reduced)):
        S_nP.append(i)
    P = List[List[Int]]()
    for hi_idx in range(k):
        var hi = H[hi_idx].copy()
        var QI = hi.QI.copy()
        var QO = hi.QO.copy()
        var still_nP = List[Int]()
        for nP_idx in range(len(S_nP)):
            var s_idx = S_nP[nP_idx]
            var f = S_reduced[s_idx].func.copy()
            if in_span(f, QI):
                P = partition(s_idx, P, S_P, S_reduced, QI, nq)
                S_P.append(s_idx)
            else:
                still_nP.append(s_idx)
        S_nP = still_nP^
        var P_keep = List[List[Int]]()
        for b in range(len(P)):
            var A = P[b].copy()
            var is_last_H = (hi_idx == k - 1)
            var must_synthesize = is_last_H
            if not must_synthesize:
                for ai in range(len(A)):
                    var f = S_reduced[A[ai]].func.copy()
                    if not in_span(f, QO):
                        must_synthesize = True; break
            if must_synthesize:
                var C = synthesize(A, S_reduced, QI, QI, nq)
                for cg in range(len(C)):
                    C_prime.append(C[cg].copy())
            else:
                var rank_QO = gaussian_rank(QO)
                var rank_A = rank_of_subset(A, S_reduced)
                if rank_QO - rank_A > nq - len(A):
                    var removed = False
                    for ai in range(len(A)):
                        var test = List[Int]()
                        for aj in range(len(A)):
                            if aj != ai: test.append(A[aj])
                        if rank_A == rank_of_subset(test, S_reduced):
                            var removed_idx = A[ai]
                            S_nP.append(removed_idx)
                            var new_SP = List[Int]()
                            for si in range(len(S_P)):
                                if S_P[si] != removed_idx:
                                    new_SP.append(S_P[si])
                            S_P = new_SP^
                            var A_new = List[Int]()
                            for aj in range(len(A)):
                                if aj != ai: A_new.append(A[aj])
                            P_keep.append(A_new^)
                            removed = True; break
                    if not removed:
                        P_keep.append(A.copy())
                else:
                    P_keep.append(A.copy())
        P = P_keep^
        if hi.qubit >= 0:
            var h_ql = List[Int]()
            h_ql.append(hi.qubit)
            C_prime.append(GateOp("H", h_ql, List[Float64]()))
    return C_prime^