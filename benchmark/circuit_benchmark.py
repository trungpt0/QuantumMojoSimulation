import matplotlib.pyplot as plt

n = []
state = []
time = []
memory = []

with open("benchmark/circuit_benchmark.txt", "r") as f:
    for line in f:
        a, b, c, d = line.split()
        a = int(a)
        b = int(b)
        c = float(c)
        d = float(d)
        n.append(int(a))
        state.append(int(b))
        time.append(c)
        memory.append(d)
    
plt.figure(figsize=(10, 10))
plt.subplot(3, 1, 1)
plt.plot(n, state)
plt.xticks(n)
plt.xlabel("Number of Qubits")
plt.ylabel("State Size")
plt.title("State Size vs Number of Qubits")
plt.grid()
plt.yscale("log")

plt.subplot(3, 1, 2)
plt.plot(n, time)
plt.xticks(n)
plt.xlabel("Number of Qubits")
plt.ylabel("Time (ms)")
plt.title("Time vs Number of Qubits")
plt.grid()
plt.yscale("log")

plt.subplot(3, 1, 3)
plt.plot(n, memory)
plt.xticks(n)
plt.xlabel("Number of Qubits")
plt.ylabel("Memory (MB)")
plt.title("Memory vs Number of Qubits")
plt.grid()
plt.yscale("log")

plt.tight_layout()
plt.show()