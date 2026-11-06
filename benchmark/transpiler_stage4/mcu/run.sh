#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler mcu synthesize mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage4/mcu/mcu_benchmark.mojo" > "$PROJECT_ROOT/benchmark/transpiler_stage4/mcu/results_mojo_mcu.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler mcu synthesize mojo benchmark failed"
    exit 1
fi
echo "Transpiler mcu synthesize mojo benchmark completed successfully"
echo "results_mojo_mcu.txt has created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/mcu/mcu_benchmark.py" > "$PROJECT_ROOT/benchmark/transpiler_stage4/mcu/results_qiskit_mcu.txt"
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/mcu/mcu_compare.py" "$PROJECT_ROOT/benchmark/transpiler_stage4/mcu/results_mojo_mcu.txt" "$PROJECT_ROOT/benchmark/transpiler_stage4/mcu/results_qiskit_mcu.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler mcu synthesize python benchmark failed"
    exit 1
fi
echo "Transpiler mcu synthesize python benchmark completed successfully"
echo "Transpiler mcu synthesize benchmark done"