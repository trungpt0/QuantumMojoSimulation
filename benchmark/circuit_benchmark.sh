#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking random quantum circuit generation..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/circuit_benchmark.mojo" > "$PROJECT_ROOT/benchmark/circuit_benchmark.txt"
if [ $? -ne 0 ]; then
    echo "Mojo benchmark failed"
    exit 1
fi
echo "Mojo done → circuit_benchmark.txt created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/circuit_benchmark.py"
if [ $? -ne 0 ]; then
    echo "Python benchmark plot failed"
    exit 1
fi
echo "Plot done"