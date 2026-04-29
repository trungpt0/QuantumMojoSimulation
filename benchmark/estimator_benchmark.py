import sys, argparse
from dataclasses import dataclass, field
from collections import defaultdict

try:
    from qiskit import QuantumCircuit
    from qiskit.quantum_info import Statevector
    from qiskit.primitives import StatevectorEstimator
except ImportError:
    print("Qiskit is not installed. Please install qiskit to run this benchmark.")
    sys.exit(1)
    
if __name__ == "__main__":
    ap = argparse.ArgumentParser()