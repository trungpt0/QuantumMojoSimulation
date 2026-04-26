from std.time import monotonic
from qmath import PI, random_int
from circuit import QuantumCircuit

def apply_random_single_qubit_gate(mut qc: QuantumCircuit, n: Int):
    var gate_random = random_int(0, 11)
    var w_random = random_int(0, n)
    var theta_random = PI * Float64(random_int(0, 1000)) / 1000.0
    if gate_random == 0:
        qc.X(w_random)
    elif gate_random == 1:
        qc.Y(w_random)
    elif gate_random == 2:
        qc.Z(w_random)
    elif gate_random == 3:
        qc.H(w_random)
    elif gate_random == 4:
        qc.S(w_random)
    elif gate_random == 5:
        qc.T(w_random)
    elif gate_random == 6:
        qc.RX(w_random, theta_random)
    elif gate_random == 7:
        qc.RY(w_random, theta_random)
    elif gate_random == 8:
        qc.RZ(w_random, theta_random)
    elif gate_random == 9:
        qc.P(w_random, theta_random)
    else:
        qc.IP(w_random, theta_random)

def apply_random_cx_gate(mut qc: QuantumCircuit, n: Int):
    var c_random = random_int(0, n)
    var t_random = random_int(0, n)
    if c_random == t_random:
        t_random = (t_random + 1) % n
    qc.CX(c_random, t_random)

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