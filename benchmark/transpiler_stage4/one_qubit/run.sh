#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler one-qubit decompose mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage4/one_qubit/one_qubit_benchmark.mojo" > "$PROJECT_ROOT/benchmark/transpiler_stage4/one_qubit/mojo_1q.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler one-qubit decompose mojo benchmark failed"
    exit 1
fi
echo "Transpiler one-qubit decompose mojo benchmark completed successfully"
echo "mojo_1q.txt has created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/one_qubit/one_qubit_benchmark.py" "$PROJECT_ROOT/benchmark/transpiler_stage4/one_qubit/mojo_1q.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler one-qubit decompose python benchmark failed"
    exit 1
fi
echo "Transpiler one-qubit decompose python benchmark completed successfully"
echo "Transpiler one-qubit decompose benchmark done"