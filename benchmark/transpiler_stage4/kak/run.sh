#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler kak decompose mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage4/kak/kak_benchmark.mojo" > "$PROJECT_ROOT/benchmark/transpiler_stage4/kak/mojo_kak.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler kak decompose mojo benchmark failed"
    exit 1
fi
echo "Transpiler kak decompose mojo benchmark completed successfully"
echo "mojo_kak.txt has created"
echo "Running Python benchmark..."
/usr/bin/python3 "$PROJECT_ROOT/benchmark/transpiler_stage4/kak/kak_benchmark.py" "$PROJECT_ROOT/benchmark/transpiler_stage4/kak/mojo_kak.txt"
if [ $? -ne 0 ]; then
    echo "Transpiler kak decompose python benchmark failed"
    exit 1
fi
echo "Transpiler kak decompose python benchmark completed successfully"
echo "Transpiler kak decompose benchmark done"