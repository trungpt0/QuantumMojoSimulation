# Mojo Quantum Computing Framework

A high-performance quantum computing framework written in **Mojo**, designed to simulate and analyze quantum circuits with optimizations for wavefunction-based quantum computation.

## Overview

WaveFunctionPk provides a comprehensive toolkit for quantum circuit design, execution, and analysis. Built on the Mojo programming language, it leverages modern compiler optimizations and memory management to deliver efficient quantum simulations while maintaining an intuitive and Pythonic API.

## Features

- **Quantum Circuit Simulation**: Full wavefunction-based quantum circuit simulator
- **Quantum Gates**: Support for standard quantum gates (X, Y, Z, H, CNOT, RX, RY, RZ, S, T, etc.)
- **Parametric Gates**: Gates with adjustable rotation angles
- **DAG Circuit Representation**: Directed Acyclic Graph-based circuit representation for optimized analysis
- **Quantum Primitives**: 
  - **Estimator**: Compute expectation values of observables
  - **Sampler**: Sample measurements from quantum circuits
- **Transpilation & Optimization**: 
  - Inverse cancellation optimization
  - Commutative inverse cancellation
  - Identity equivalent gate removal
  - Diagonal gate removal before measurement
  - 2-qubit block collection
- **Quantum Utilities**: Random number generation, assertions, and mathematical utilities
- **Benchmarking**: Performance benchmarking tools for circuits and estimators

## Project Structure

```
WaveFunctionPk/
├── circuit.mojo              # Main QuantumCircuit class
├── gates.mojo                # Gate definitions and implementations
├── apply_gate.mojo           # Gate application logic
├── qrandom.mojo              # Quantum random number generation
├── main.mojo                 # Entry point
│
├── qmath/                    # Quantum mathematics utilities
│   ├── qmath.mojo           # Complex numbers and math operations
│   └── __init__.mojo
│
├── qutils/                   # Quantum utilities
│   ├── qutils.mojo          # Assertion and utility functions
│   └── __init__.mojo
│
├── dagcircuit/              # DAG circuit representation
│   ├── dagcircuit.mojo      # DAG circuit implementation
│   ├── dagnode.mojo         # DAG node structure
│   └── __init__.mojo
│
├── primitives/              # Quantum primitives
│   ├── estimator.mojo       # Expectation value estimator
│   ├── sampler.mojo         # Measurement sampler
│   └── __init__.mojo
│
├── transpiler/              # Circuit transpilation and optimization
│   ├── passes/              # Transpilation passes
│   │   ├── optimization/    # Optimization passes
│   │   │   ├── collect_2q_blocks.mojo
│   │   │   ├── commutative_inverse_cancellation.mojo
│   │   │   ├── inverse_cancellation.mojo
│   │   │   ├── remove_diagonal_gates_before_measure.mojo
│   │   │   └── remove_identity_equivalent.mojo
│   │   └── __init__.mojo
│   └── __init__.mojo
│
├── test/                    # Unit tests
│   ├── test_gates.mojo
│   └── test_estimator.mojo
│
└── benchmark/               # Performance benchmarks
    ├── circuit_benchmark.mojo/.py/.sh
    └── estimator_benchmark.mojo/.py/.sh
```

## Requirements

- **Mojo**: >= 0.26.3.0.dev2026040105, < 0.27
- **Conda/Pixi**: For environment management

## Installation

### Prerequisites

Install [Mojo](https://docs.modular.com/mojo/manual/get-started/) and [Pixi](https://pixi.sh/) (or Conda).

### Setup with Pixi

```bash
# Clone the repository
git clone <repository-url>
cd WaveFunctionPk

# Install dependencies with Pixi
pixi install

# Activate the environment
pixi shell
```

## Usage

### Basic Quantum Circuit

```mojo
from circuit import QuantumCircuit

# Create a 2-qubit quantum circuit
var qc = QuantumCircuit(2)

# Apply gates
qc.H(0)              # Hadamard on qubit 0
qc.CNOT(0, 1)        # CNOT with control=0, target=1
qc.RZ(0.5, 1)        # RZ rotation on qubit 1

# Get the state
var psi = qc.psi     # Wavefunction
```

### Expectation Value Estimation

```mojo
from primitives import SparsePauliOp, Estimator

# Define an observable (Pauli operator)
var obs = SparsePauliOp("ZZ", 1.0)

# Create an estimator
var estimator = Estimator()

# Run estimation
var result = estimator.run(qc, obs)
```

### Circuit Sampling

```mojo
from primitives import Sampler

# Create a sampler
var sampler = Sampler()

# Sample measurement outcomes
var counts = sampler.sample(qc, shots=1024)
```

## Key Components

### QuantumCircuit
The core class for building and simulating quantum circuits. Stores the quantum state as a wavefunction and maintains a list of applied gates.

### Gates
Standard quantum gate implementations including:
- Single-qubit gates: X, Y, Z, H, S, T, Rx, Ry, Rz
- Multi-qubit gates: CNOT (CX)
- Custom parametric gates

### Primitives
High-level quantum operations:
- **Estimator**: Computes expectation values of observables on quantum states
- **Sampler**: Samples from measurement distributions

### Transpiler
Optimizes quantum circuits through various transpilation passes:
- Removes redundant gates
- Cancels inverse gate pairs
- Simplifies circuit structure

## Running Benchmarks

### Circuit Benchmark

```bash
cd benchmark
bash circuit_benchmark.sh
```

### Estimator Benchmark

```bash
cd benchmark
bash estimator_benchmark.sh
```

## Testing

Run unit tests:

```bash
mojo test/test_gates.mojo
mojo test/test_estimator.mojo
```

## Version

- **Current Version**: 0.1.0
- **Author**: trungpt0 (AISeQ-Lab) <trungtrnminh368@gmail.com>

## License

GPL

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Related Resources

- [Mojo Documentation](https://docs.modular.com/mojo/)
- [Quantum Computing Basics](https://en.wikipedia.org/wiki/Quantum_computing)
- [Qiskit Documentation](https://qiskit.org/) (conceptual inspiration)
