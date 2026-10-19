#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler mcx synthesize mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage4/mcx/mcx_benchmark.mojo" > "$PROJECT_ROOT/benchmark/transpiler_stage4/mcx/results_mojo_mcx.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler mcx synthesize mojo benchmark failed"
    exit 1
fi
echo "Transpiler mcx synthesize mojo benchmark completed successfully"
echo "results_mojo_mcx.txt has created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/mcx/mcx_benchmark.py" > "$PROJECT_ROOT/benchmark/transpiler_stage4/mcx/results_qiskit_mcx.txt"
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/mcx/mcx_compare.py" "$PROJECT_ROOT/benchmark/transpiler_stage4/mcx/results_mojo_mcx.txt" "$PROJECT_ROOT/benchmark/transpiler_stage4/mcx/results_qiskit_mcx.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler mcx synthesize python benchmark failed"
    exit 1
fi
echo "Transpiler mcx synthesize python benchmark completed successfully"
echo "Transpiler mcx synthesize benchmark done"