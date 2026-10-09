#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler routing mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage3/routing_benchmark.mojo"
if [ $? -ne 0 ]; then
    echo "Transpiler routing mojo benchmark failed"
    exit 1
fi
echo "Transpiler routing mojo benchmark completed successfully"
echo "routing_benchmark.txt has created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage3/routing_benchmark.py"
if [ $? -ne 0 ]; then
    echo "Transpiler routing python benchmark failed"
    exit 1
fi
echo "Transpiler routing python benchmark completed successfully"
echo "Transpiler routing benchmark done"