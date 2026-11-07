#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler toffoli synthesize mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage4/toffoli/toffoli_benchmark.mojo" > "$PROJECT_ROOT/benchmark/transpiler_stage4/toffoli/results_mojo_toffoli.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler toffoli synthesize mojo benchmark failed"
    exit 1
fi
echo "Transpiler toffoli synthesize mojo benchmark completed successfully"
echo "results_mojo_toffoli.txt has created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/toffoli/toffoli_benchmark.py" > "$PROJECT_ROOT/benchmark/transpiler_stage4/toffoli/results_qiskit_toffoli.txt"
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/toffoli/toffoli_compare.py" "$PROJECT_ROOT/benchmark/transpiler_stage4/toffoli/results_mojo_toffoli.txt" "$PROJECT_ROOT/benchmark/transpiler_stage4/toffoli/results_qiskit_toffoli.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler toffoli synthesize python benchmark failed"
    exit 1
fi
echo "Transpiler toffoli synthesize python benchmark completed successfully"
echo "Transpiler toffoli synthesize benchmark done"