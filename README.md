# WaveFunctionPk — Mojo Quantum Computing Framework

A high-performance quantum computing framework written in **Mojo**, designed for wavefunction-based quantum simulation, quantum circuit optimization, and hardware-aware transpilation.

WaveFunctionPk provides a complete workflow from quantum circuit construction and wavefunction simulation to circuit optimization, qubit layout, SWAP routing, and transpiler benchmarking.

---

## Overview

**WaveFunctionPk** is a Mojo-based quantum computing framework focused on efficient wavefunction simulation and quantum circuit transpilation.

The framework provides:

* Wavefunction-based quantum circuit simulation
* Standard and parametric quantum gates
* Quantum primitives such as Estimator and Sampler
* DAG-based circuit representation
* Circuit optimization passes
* Basis-gate decomposition
* Hardware coupling-map representation
* Trivial, VF2, and SABRE qubit layout
* SABRE-based SWAP routing
* Circuit equivalence and fidelity validation
* Dedicated benchmarking for simulation and transpilation

The project is designed to explore high-performance quantum computing implementations in **Mojo**, while providing a transpilation workflow conceptually comparable to modern quantum software frameworks such as **Qiskit**.

---

# Features

## Quantum Circuit Simulation

* Wavefunction-based quantum circuit simulation
* State-vector representation of quantum states
* Single-qubit and multi-qubit gate application
* Parametric quantum gates
* Direct wavefunction gate application
* Quantum state access through `QuantumCircuit`
* Support for custom unitary operations

## Quantum Gates

WaveFunctionPk supports common quantum gates including:

### Single-Qubit Gates

* `X`
* `Y`
* `Z`
* `H`
* `S`
* `T`

### Parametric Gates

* `RX`
* `RY`
* `RZ`

### Multi-Qubit Gates

* `CNOT`
* `SWAP`

The framework also provides matrix-level utilities for constructing and manipulating gate representations.

---

## Quantum Circuit Representation

The core `QuantumCircuit` abstraction provides:

* Quantum register management
* Wavefunction storage
* Gate application
* Gate recording
* Circuit operation tracking
* Logical qubit representation

Individual circuit operations are represented using `GateRecord`.

A DAG-based representation is provided through the `dagcircuit` package for circuit analysis and transpilation.

---

# Quantum Primitives

WaveFunctionPk provides high-level primitives for executing quantum computations.

## Estimator

The `Estimator` computes expectation values of observables with respect to the simulated quantum state.

Example:

```mojo
from circuit import QuantumCircuit
from primitives import SparsePauliOp, Estimator

var qc = QuantumCircuit(2)

qc.H(0)
qc.CNOT(0, 1)

var obs = SparsePauliOp("ZZ", 1.0)

var estimator = Estimator()

var result = estimator.run(qc, obs)
```

## Sampler

The `Sampler` generates measurement samples from the probability distribution represented by the quantum wavefunction.

Example:

```mojo
from circuit import QuantumCircuit
from primitives import Sampler

var qc = QuantumCircuit(2)

qc.H(0)
qc.CNOT(0, 1)

var sampler = Sampler()

var counts = sampler.sample(qc, shots=1024)
```

---

# DAG Circuit Representation

WaveFunctionPk provides a Directed Acyclic Graph representation of quantum circuits.

The DAG representation enables circuit-level analysis and supports transpilation passes that operate on circuit structure rather than only on sequential gate lists.

The DAG circuit infrastructure includes:

* DAG nodes
* Gate dependencies
* Circuit connectivity
* Operation analysis
* Support for optimization and transpilation passes

---

# Transpiler

WaveFunctionPk includes a hardware-aware quantum circuit transpilation pipeline.

The transpiler is divided into several functional stages:

```text
Input Quantum Circuit
        │
        ▼
┌─────────────────────────┐
│ Circuit Optimization    │
│                         │
│ - 1Q collection         │
│ - 2Q block collection   │
│ - Block consolidation   │
│ - Inverse cancellation  │
│ - Identity removal      │
│ - Diagonal removal      │
│ - Unitary splitting     │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ Basis Decomposition     │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ Qubit Layout            │
│                         │
│ - Trivial               │
│ - VF2                   │
│ - SABRE                 │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ SABRE Routing           │
│                         │
│ - Coupling constraints  │
│ - SWAP insertion        │
│ - Mapping updates       │
└────────────┬────────────┘
             │
             ▼
      Transpiled Circuit
```

---

# Transpiler Stage 1 — Circuit Optimization

The first transpilation stage reduces unnecessary operations and simplifies circuit structure before hardware mapping.

## Optimization Passes

### Collect 1-Q Runs

Collects consecutive single-qubit operations that can be analyzed or processed as a group.

```text
1Q Gate → 1Q Gate → 1Q Gate
              ↓
          1Q Run
```

### Collect 2-Q Blocks

Collects groups of two-qubit operations for block-level analysis and optimization.

### Consolidate Blocks

Combines compatible gate blocks into consolidated unitary representations.

### Split 2-Q Unitaries

Decomposes two-qubit unitary blocks when required by the target gate basis.

### Inverse Cancellation

Removes adjacent inverse operations.

Example:

```text
H → H
```

can be reduced to:

```text
I
```

Similarly:

```text
X → X
```

can be removed because:

```text
X² = I
```

### Commutative Inverse Cancellation

Extends inverse cancellation to operations that can be reordered because they commute.

### Remove Identity-Equivalent Gates

Removes gates or gate sequences that are mathematically equivalent to the identity operation.

### Remove Diagonal Gates Before Measurement

Removes diagonal operations that do not affect computational-basis measurement probabilities when applicable.

---

# Transpiler Stage 2 — Layout and Routing

The second stage maps logical qubits onto physical qubits according to a target hardware coupling graph.

This stage includes:

* Hardware coupling maps
* Logical-to-physical qubit mapping
* Trivial layout
* VF2 layout
* SABRE layout
* SABRE SWAP routing
* Mapping validation

---

# Hardware Coupling Map

The `coupling.mojo` module represents hardware connectivity.

A coupling graph defines which physical qubits can directly interact.

For example:

```text
q0 ─── q1 ─── q2 ─── q3
```

allows direct two-qubit interactions between:

```text
(q0, q1)
(q1, q2)
(q2, q3)
```

but not directly between:

```text
(q0, q3)
```

Hardware-aware transpilation must therefore map logical interactions onto physically connected qubits.

---

# Qubit Layout

WaveFunctionPk provides multiple layout strategies.

## Trivial Layout

The trivial layout assigns logical qubits sequentially to physical qubits.

For example:

```text
Logical qubits:

q0 → q1 → q2 → q3

Physical qubits:

p0 → p1 → p2 → p3
```

This provides a simple baseline for evaluating more advanced layout algorithms.

---

## VF2 Layout

The VF2 layout implementation uses a graph-subgraph matching approach to search for compatible mappings between:

```text
Circuit Interaction Graph
            │
            ▼
       VF2 Matching
            │
            ▼
Hardware Coupling Graph
```

VF2 can identify mappings where the circuit's interaction structure fits directly into the available hardware connectivity.

The implementation also supports validation of candidate layouts.

---

## SABRE Layout

The SABRE layout implementation uses the SABRE heuristic to search for hardware-aware logical-to-physical qubit mappings.

SABRE considers circuit interactions and hardware connectivity when selecting mappings.

The layout stage can therefore provide a better starting point for subsequent routing.

---

# SABRE Routing

When a logical two-qubit operation cannot be directly executed on the target hardware, the router inserts SWAP operations.

For example, suppose the hardware connectivity is:

```text
p0 ─── p1 ─── p2
```

and the circuit requires:

```text
q0 ───────── q2
```

A direct interaction between the corresponding physical qubits may not be available.

The router can insert a SWAP:

```text
p0 ─── p1 ─── p2
       SWAP
```

to move the required logical qubits closer together.

The SABRE routing implementation evaluates candidate SWAP operations using heuristic cost functions and updates the logical-to-physical mapping during routing.

---

# Basis Decomposition

The transpiler also provides basis-gate decomposition.

The decomposition stage converts supported operations into gates compatible with a target basis.

This enables the circuit to be transformed from higher-level operations into a lower-level gate representation suitable for hardware execution or further optimization.

---

# Transpilation Validation

WaveFunctionPk provides multiple mechanisms for validating transpilation results.

## Mapping Validation

Checks whether logical-to-physical mappings satisfy the target hardware coupling constraints.

## Circuit Equivalence

Transpiled circuits can be compared against the original circuit to verify functional equivalence.

## Wavefunction Fidelity

Wavefunction fidelity can be used to evaluate whether two quantum circuits produce equivalent quantum states.

This is particularly useful when optimization and decomposition passes transform the original circuit.

## Two-Qubit Fidelity Tests

Dedicated tests are provided for evaluating two-qubit transformations and circuit equivalence.

## Block Fidelity Tests

Block-level transformations can also be validated using fidelity calculations.

---

# Project Structure

```text
WaveFunctionPk/
│
├── apply_gate.mojo              # Quantum gate application logic
├── circuit.mojo                 # Main QuantumCircuit class
├── gate_record.mojo             # Gate record / circuit operation representation
├── gates.mojo                   # Standard and parametric quantum gates
├── main.mojo                    # Main entry point
├── qrandom.mojo                 # Quantum random number generation
│
├── qmath/                       # Quantum mathematics utilities
│   ├── gate_matrix.mojo         # Gate matrix construction and utilities
│   ├── qmath.mojo               # Complex numbers and mathematical operations
│   └── __init__.mojo
│
├── qutils/                      # General quantum utilities
│   ├── qutils.mojo              # Assertions and utility functions
│   └── __init__.mojo
│
├── dagcircuit/                  # DAG-based quantum circuit representation
│   ├── dagcircuit.mojo          # DAG circuit implementation
│   ├── dagnode.mojo             # DAG node structure
│   └── __init__.mojo
│
├── primitives/                  # High-level quantum primitives
│   ├── estimator.mojo           # Expectation value estimation
│   ├── sampler.mojo             # Quantum circuit sampling
│   └── __init__.mojo
│
├── transpiler/                  # Quantum circuit transpilation
│   ├── coupling.mojo            # Hardware coupling map
│   ├── __init__.mojo
│   │
│   └── passes/
│       ├── __init__.mojo
│       │
│       ├── basis/               # Basis-gate decomposition
│       │   ├── decompose.mojo
│       │   └── __init__.mojo
│       │
│       ├── layout/              # Logical-to-physical qubit mapping
│       │   ├── __init__.mojo
│       │   ├── trivial_layout.mojo
│       │   ├── vf2_layout.mojo
│       │   └── sabre_layout.mojo
│       │
│       ├── optimization/        # Circuit optimization passes
│       │   ├── __init__.mojo
│       │   ├── collect_1q_runs.mojo
│       │   ├── collect_2q_blocks.mojo
│       │   ├── consolidate_blocks.mojo
│       │   ├── split_2q_unitaries.mojo
│       │   ├── inverse_cancellation.mojo
│       │   ├── commutative_inverse_cancellation.mojo
│       │   ├── remove_diagonal_gates_before_measure.mojo
│       │   └── remove_identity_equivalent.mojo
│       │
│       └── routing/             # Qubit routing
│           ├── __init__.mojo
│           └── sabre_swap.mojo
│
├── benchmark/                   # Performance and transpiler benchmarks
│   │
│   ├── circuit/
│   │   ├── circuit_benchmark.mojo
│   │   ├── circuit_benchmark.py
│   │   ├── circuit_benchmark.sh
│   │   └── circuit_benchmark.txt
│   │
│   ├── estimator/
│   │   ├── estimator_benchmark.mojo
│   │   ├── estimator_benchmark.py
│   │   ├── estimator_benchmark.sh
│   │   └── estimator_benchmark.txt
│   │
│   ├── transpiler_stage1/
│   │   ├── opt_benchmark.mojo
│   │   ├── opt_benchmark.py
│   │   ├── opt_benchmark.sh
│   │   └── opt_benchmark.txt
│   │
│   └── transpiler_stage2/
│       ├── layout_benchmark.mojo
│       ├── layout_benchmark.py
│       ├── layout_benchmark.sh
│       ├── layout_benchmark.txt
│       └── layout_bm_plot.py
│
├── test/
│   ├── fidelity2q_test.mojo
│   ├── fidelity_block_test.mojo
│   ├── gates_test.mojo
│   └── tpar_test.ipynb
│
├── pixi.toml                    # Pixi project configuration
├── pixi.lock                    # Locked dependency versions
└── README.md
```

---

# Requirements

* **Mojo**: `>= 0.26.3.0.dev2026040105, < 0.27`
* **Pixi** or Conda for environment management

---

# Installation

## Prerequisites

Install Mojo and Pixi before building the project.

* Mojo: https://docs.modular.com/mojo/manual/get-started/
* Pixi: https://pixi.sh/

## Setup with Pixi

Clone the repository:

```bash
git clone <repository-url>
cd WaveFunctionPk
```

Install dependencies:

```bash
pixi install
```

Activate the environment:

```bash
pixi shell
```

---

# Usage

## Basic Quantum Circuit

```mojo
from circuit import QuantumCircuit

# Create a 2-qubit quantum circuit
var qc = QuantumCircuit(2)

# Apply gates
qc.H(0)
qc.CNOT(0, 1)
qc.RZ(0.5, 1)

# Access the wavefunction
var psi = qc.psi
```

---

## Applying Parametric Gates

```mojo
from circuit import QuantumCircuit

var qc = QuantumCircuit(2)

qc.RX(0.5, 0)
qc.RY(1.0, 1)
qc.RZ(0.25, 0)
```

---

## Two-Qubit Circuit

```mojo
from circuit import QuantumCircuit

var qc = QuantumCircuit(3)

qc.H(0)
qc.CNOT(0, 1)
qc.CNOT(1, 2)
```

---

# Running Benchmarks

WaveFunctionPk provides separate benchmark suites for simulation, primitives, optimization, and hardware-aware transpilation.

---

## Circuit Benchmark

The circuit benchmark evaluates quantum circuit execution performance.

```bash
cd benchmark/circuit
bash circuit_benchmark.sh
```

Benchmark files:

```text
circuit_benchmark.mojo
circuit_benchmark.py
circuit_benchmark.sh
circuit_benchmark.txt
```

---

## Estimator Benchmark

The estimator benchmark evaluates expectation-value computation.

```bash
cd benchmark/estimator
bash estimator_benchmark.sh
```

---

## Transpiler Stage 1 Benchmark

The Stage 1 benchmark evaluates circuit optimization performance.

```bash
cd benchmark/transpiler_stage1
bash opt_benchmark.sh
```

The benchmark evaluates optimization behavior and produces text-based benchmark results.

---

## Transpiler Stage 2 Benchmark

The Stage 2 benchmark evaluates layout and routing algorithms.

```bash
cd benchmark/transpiler_stage2
bash layout_benchmark.sh
```

The benchmark includes:

* Trivial layout
* VF2 layout
* SABRE layout
* SABRE routing
* SWAP insertion
* Runtime comparison
* Mapping validation
* Circuit equivalence validation

Plot generation is provided by:

```bash
python layout_bm_plot.py
```

---

# Benchmark Methodology

The transpiler benchmarks are designed to compare different layout and routing strategies under the same circuit and hardware constraints.

Important metrics include:

## SWAP Count

Measures the number of additional SWAP operations introduced during routing.

Lower SWAP count generally indicates lower routing overhead.

## Runtime

Measures the execution time required by the layout and routing algorithms.

## Mapping Validity

Checks whether generated logical-to-physical mappings satisfy the hardware coupling constraints.

## Circuit Equivalence

Checks whether the transpiled circuit preserves the behavior of the original circuit.

## Wavefunction Fidelity

Measures similarity between quantum states generated by the original and transformed circuits.

---

# Testing

Run the gate tests:

```bash
mojo test/fidelity2q_test.mojo
```

Run the block fidelity tests:

```bash
mojo test/fidelity_block_test.mojo
```

Run the gate tests:

```bash
mojo test/gates_test.mojo
```

The project also contains a Jupyter notebook for T-par / transpilation experiments:

```text
test/tpar_test.ipynb
```

---

# Performance and Transpilation Evaluation

WaveFunctionPk is designed not only as a quantum simulator but also as an experimental quantum compiler/transpiler framework.

The benchmark infrastructure allows comparisons between:

```text
                    WaveFunctionPk
                         │
          ┌──────────────┴──────────────┐
          │                             │
     Simulation                    Transpilation
          │                             │
    ┌─────┴─────┐             ┌─────────┴─────────┐
    │           │             │                   │
  Circuit   Estimator       Layout             Routing
    │           │             │                   │
    │           │        ┌────┼────┐              │
    │           │        │    │    │              │
    │           │     Trivial VF2 SABRE       SABRE SWAP
    │           │
    └───────────┴─────────────────────────────────┘
```

This allows evaluation of both computational performance and compiler-level optimization.

---

# Design Goals

WaveFunctionPk is designed around several goals:

### 1. High-Performance Quantum Simulation

Use Mojo's performance-oriented execution model to implement efficient wavefunction-based quantum simulation.

### 2. Modular Architecture

Separate simulation, mathematical utilities, primitives, DAG representation, and transpilation into independent modules.

### 3. Hardware-Aware Transpilation

Support realistic hardware constraints through coupling maps, qubit layouts, and SWAP routing.

### 4. Compiler-Oriented Quantum Computing

Provide circuit analysis and optimization passes similar to those found in modern quantum compiler stacks.

### 5. Reproducible Benchmarking

Provide dedicated Mojo/Python benchmark programs and shell scripts for reproducible performance evaluation.

---

# Technology Stack

| Component              | Technology                    |
| ---------------------- | ----------------------------- |
| Programming Language   | Mojo                          |
| Environment Management | Pixi                          |
| Quantum Representation | Wavefunction / State Vector   |
| Circuit Representation | Gate List + DAG               |
| Layout Algorithms      | Trivial, VF2, SABRE           |
| Routing                | SABRE SWAP Routing            |
| Optimization           | Custom Mojo Transpiler Passes |
| Benchmarking           | Mojo + Python                 |
| Analysis               | Python / Jupyter              |
| Reference Framework    | Qiskit                        |

---

# Version

**Current Version:** `0.1.0`

---

# Author

**Tran Minh Trung (Trần Minh Trung)**

AISeQ-Lab

Email: `trungtrnminh368@gmail.com`

---

# License

GPL

---

# Contributing

Contributions are welcome.

If you find a bug, have an optimization idea, or want to add a new transpilation pass, please open an issue or submit a pull request.

Areas for potential contribution include:

* New quantum gates
* Additional optimization passes
* New layout algorithms
* Alternative routing algorithms
* Improved wavefunction simulation
* GPU acceleration
* Parallel simulation
* Additional benchmark circuits
* Additional hardware coupling topologies

---

# Related Resources

* Mojo Documentation: https://docs.modular.com/mojo/
* Mojo Getting Started: https://docs.modular.com/mojo/manual/get-started/
* Pixi: https://pixi.sh/
* Quantum Computing: https://en.wikipedia.org/wiki/Quantum_computing
* Qiskit: https://qiskit.org/

---

# Project Summary

WaveFunctionPk is a **Mojo-based quantum computing framework** combining wavefunction simulation with quantum circuit optimization and hardware-aware transpilation.

The framework currently covers the following workflow:

```text
Quantum Circuit
      │
      ▼
Wavefunction Simulation
      │
      ▼
DAG Circuit Representation
      │
      ▼
Circuit Optimization
      │
      ├── 1Q Collection
      ├── 2Q Block Collection
      ├── Block Consolidation
      ├── Inverse Cancellation
      ├── Commutative Cancellation
      ├── Identity Removal
      ├── Diagonal Gate Removal
      └── 2Q Unitary Splitting
      │
      ▼
Basis Decomposition
      │
      ▼
Qubit Layout
      │
      ├── Trivial
      ├── VF2
      └── SABRE
      │
      ▼
SABRE Routing
      │
      └── SWAP Insertion
      │
      ▼
Transpiled Quantum Circuit
      │
      ▼
Equivalence / Fidelity Validation
      │
      ▼
Benchmarking and Performance Analysis
```

The project aims to provide a high-performance and extensible foundation for exploring **quantum simulation, quantum circuit optimization, and quantum compiler technologies using Mojo**.
