#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler layout mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage2/layout_benchmark.mojo"
if [ $? -ne 0 ]; then
    echo "Transpiler layout mojo benchmark failed"
    exit 1
fi
echo "Transpiler layout mojo benchmark completed successfully"
echo "layout_benchmark.txt has created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage2/layout_benchmark.py"
if [ $? -ne 0 ]; then
    echo "Transpiler layout python benchmark failed"
    exit 1
fi
echo "Transpiler layout python benchmark completed successfully"
echo "Transpiler layout benchmark done"