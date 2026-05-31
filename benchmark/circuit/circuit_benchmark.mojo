from std.time import monotonic
from qmath import PI, random_int
from circuit import QuantumCircuit
from qrandom import apply_random_single_qubit_gate, apply_random_cx_gate

def random_circuit(mut qc: QuantumCircuit, n: Int) -> None:
    var steps = n * n
    for _ in range(steps):
        var choice = random_int(0, 2)
        if choice == 0:
            apply_random_single_qubit_gate(qc, n)
        else:
            apply_random_cx_gate(qc, n)

def main() raises:
    for n in range(2, 21):
        var qc = QuantumCircuit(n)
        var t0 = monotonic()
        random_circuit(qc, n)
        var t1 = monotonic()
        var dt = t1 - t0
        var dt_ms = Float64(dt) / 1000000.0
        var mem = Float64(len(qc.psi) * 16) / (1024.0 * 1024.0)
        # print(
        #     "n =", n,
        #     "| state =", len(qc.psi),
        #     "| time =", dt_ms, "ms",
        #     "| memory =", mem, "MB"
        # )
        print(n, len(qc.psi), dt_ms, mem)