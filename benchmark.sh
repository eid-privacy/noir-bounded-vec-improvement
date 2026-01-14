#!/bin/bash

# Store the root directory
ROOT_DIR="$(pwd)"
TARGET_DIR="target"

# Run command and extract running time (returns seconds as float)
run_and_time() {
    local cmd="$1"
    local output=$( (time eval "$cmd") 2>&1 )
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        # Check for OOM errors (including killed by system due to memory limit)
        if echo "$output" | grep -qiE "out of memory|OOM|killed|signal 9|SIGKILL|memory limit"; then
            echo "OOM error"
        else
            echo "error"
        fi
        return
    fi
    
    # Extract real time and convert to seconds
    local time_str=$(echo "$output" | grep -E "^real" | awk '{print $2}')
    if [[ "$time_str" =~ ^[0-9]+m ]]; then
        # Format: 1m23.456s
        echo "$time_str" | sed 's/m/ /; s/s$//' | awk '{printf "%.3f", $1*60 + $2}'
    else
        # Format: 23.456s or 23.456
        echo "$time_str" | sed 's/s$//'
    fi
}

# Run benchmark for a given project directory
# Arguments: $1 = project_dir, $2 = label
run_benchmark() {
    local project_dir="$1"
    local label="$2"
    
    cd "$ROOT_DIR/$project_dir" || {
        echo "❌ ERROR: Could not find directory $project_dir"
        return 1
    }
    
    echo ""
    echo "=========================================="
    echo "  Benchmarking: $label"
    echo "  Directory: $project_dir"
    echo "=========================================="
    echo ""
    
    rm -rf "$TARGET_DIR"
    
    echo "Running tests..."
    if ! nargo test > /dev/null 2>&1; then
        echo "  ❌ ERROR: nargo test failed"
        return 1
    fi
    echo "  ✓ Tests passed"
    echo ""
    
    echo "Running benchmarks..."
    echo "  [1/5] Compiling..."
    local build_time=$(run_and_time "nargo compile")
    echo "  [2/5] Executing..."
    local execute_time=$(run_and_time "nargo execute")
    echo "  [3/5] Writing verification key..."
    local write_vk_time=$(run_and_time "bb write_vk -b target/boundedVecOptimized.json -o target")
    echo "  [4/5] Generating proof..."
    local prove_time=$(run_and_time "bb prove -b target/boundedVecOptimized.json -w target/boundedVecOptimized.gz -k target/vk -o target")
    echo "  [5/5] Verifying proof..."
    local verify_time=$(run_and_time "bb verify -k target/vk -p target/proof")
    echo ""
    
    # Store results in global variables for comparison
    eval "${label}_build_time='${build_time:-error}'"
    eval "${label}_execute_time='${execute_time:-error}'"
    eval "${label}_write_vk_time='${write_vk_time:-error}'"
    eval "${label}_prove_time='${prove_time:-error}'"
    eval "${label}_verify_time='${verify_time:-error}'"
    
    echo "=== nargo info ($label) ==="
    nargo info
    echo ""
    
    cd "$ROOT_DIR"
}

# Print header
echo "=========================================="
echo "  BoundedVec Benchmark Comparison"
echo "=========================================="

# Run benchmarks for both experiments
run_benchmark "original_experiment" "original"
run_benchmark "optimized_experiment" "optimized"

# Print comparative results in markdown format
echo ""
echo "## Benchmark Results"
echo ""
echo "| Metric | Original | Optimized |"
echo "|--------|----------|-----------|"
echo "| nargo_build | ${original_build_time:-error} | ${optimized_build_time:-error} |"
echo "| nargo_execute | ${original_execute_time:-error} | ${optimized_execute_time:-error} |"
echo "| bb_write_vk | ${original_write_vk_time:-error} | ${optimized_write_vk_time:-error} |"
echo "| bb_prove | ${original_prove_time:-error} | ${optimized_prove_time:-error} |"
echo "| bb_verify | ${original_verify_time:-error} | ${optimized_verify_time:-error} |"
echo ""
echo "*All times in seconds*"
echo ""
