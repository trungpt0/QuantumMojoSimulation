#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export MOJO_IMPORT_PATH="$PROJECT_ROOT"

echo "Benchmarking transpiler optimization mojo..."
mojo -I "$PROJECT_ROOT" "$PROJECT_ROOT/benchmark/transpiler_stage1/opt_benchmark.mojo"
if [ $? -ne 0 ]; then
    echo "Transpiler optimization mojo benchmark failed"
    exit 1
fi
echo "Transpiler optimization mojo benchmark completed successfully"
echo "Transpiler optimization mojo benchmark done"