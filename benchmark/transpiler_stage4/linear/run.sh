#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler linear synthesize mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage4/linear/linear_benchmark.mojo" > "$PROJECT_ROOT/benchmark/transpiler_stage4/linear/mojo_linear.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler linear synthesize mojo benchmark failed"
    exit 1
fi
echo "Transpiler linear synthesize mojo benchmark completed successfully"
echo "mojo_linear.txt has created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/linear/linear_benchmark.py" "$PROJECT_ROOT/benchmark/transpiler_stage4/linear/mojo_linear.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler linear synthesize python benchmark failed"
    exit 1
fi
echo "Transpiler linear synthesize python benchmark completed successfully"
echo "Transpiler linear synthesize benchmark done"