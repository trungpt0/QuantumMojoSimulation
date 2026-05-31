#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking estimator mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/estimator/estimator_benchmark.mojo"
if [ $? -ne 0 ]; then
    echo "Estimator mojo benchmark failed"
    exit 1
fi
echo "Estimator mojo benchmark completed successfully"
echo "Estimator_benchmark.txt created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/estimator/estimator_benchmark.py"
if [ $? -ne 0 ]; then
    echo "Estimator python benchmark failed"
    exit 1
fi
echo "Estimator python benchmark completed successfully"
echo "Estimator benchmark done"