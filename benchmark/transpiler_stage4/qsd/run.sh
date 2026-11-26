#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler qsd decompose mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage4/qsd/qsd_benchmark.mojo" > "$PROJECT_ROOT/benchmark/transpiler_stage4/qsd/mojo_qsd.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler qsd decompose mojo benchmark failed"
    exit 1
fi
echo "Transpiler qsd decompose mojo benchmark completed successfully"
echo "mojo_qsd.txt has created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/qsd/qsd_benchmark.py" "$PROJECT_ROOT/benchmark/transpiler_stage4/qsd/mojo_qsd.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler qsd decompose python benchmark failed"
    exit 1
fi
echo "Transpiler qsd decompose python benchmark completed successfully"
echo "Transpiler qsd decompose benchmark done"