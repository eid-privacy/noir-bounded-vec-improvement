#!/bin/bash

# Store the root directory
ROOT_DIR="$(pwd)"
TARGET_DIR="target"
NUM_RUNS=1

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

# Add two floating point numbers
add_float() {
    echo "$1 $2" | awk '{printf "%.3f", $1 + $2}'
}

# Calculate average
calc_avg() {
    local sum="$1"
    local count="$2"
    echo "$sum $count" | awk '{printf "%.3f", $1 / $2}'
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
    echo "  Runs: $NUM_RUNS"
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
    
    # Initialize accumulators
    local build_sum=0
    local execute_sum=0
    local write_vk_sum=0
    local prove_sum=0
    local verify_sum=0
    local valid_runs=0
    
    echo "Running $NUM_RUNS iterations..."
    for i in $(seq 1 $NUM_RUNS); do
        printf "  Run %2d/$NUM_RUNS: " "$i"
        
        # Clean target for fresh compile each run
        rm -rf "$TARGET_DIR"
        
        # Compile
        local build_time=$(run_and_time "nargo compile")
        if [[ "$build_time" == "error" || "$build_time" == "OOM error" ]]; then
            echo "❌ compile failed"
            continue
        fi
        printf "compile "
        
        # Execute
        local execute_time=$(run_and_time "nargo execute")
        if [[ "$execute_time" == "error" || "$execute_time" == "OOM error" ]]; then
            echo "❌ execute failed"
            continue
        fi
        printf "execute "
        
        # Write VK
        local write_vk_time=$(run_and_time "bb write_vk -b target/boundedVecOptimized.json -o target")
        if [[ "$write_vk_time" == "error" || "$write_vk_time" == "OOM error" ]]; then
            echo "❌ write_vk failed"
            continue
        fi
        printf "write_vk "
        
        # Prove
        local prove_time=$(run_and_time "bb prove -b target/boundedVecOptimized.json -w target/boundedVecOptimized.gz -k target/vk -o target")
        if [[ "$prove_time" == "error" || "$prove_time" == "OOM error" ]]; then
            echo "❌ prove failed"
            continue
        fi
        printf "prove "
        
        # Verify
        local verify_time=$(run_and_time "bb verify -k target/vk -p target/proof")
        if [[ "$verify_time" == "error" || "$verify_time" == "OOM error" ]]; then
            echo "❌ verify failed"
            continue
        fi
        printf "verify "
        
        # Accumulate times
        build_sum=$(add_float "$build_sum" "$build_time")
        execute_sum=$(add_float "$execute_sum" "$execute_time")
        write_vk_sum=$(add_float "$write_vk_sum" "$write_vk_time")
        prove_sum=$(add_float "$prove_sum" "$prove_time")
        verify_sum=$(add_float "$verify_sum" "$verify_time")
        valid_runs=$((valid_runs + 1))
        
        echo "✓"
    done
    echo ""
    
    if [ $valid_runs -eq 0 ]; then
        echo "  ❌ ERROR: All runs failed"
        return 1
    fi
    
    echo "  ✓ Completed $valid_runs/$NUM_RUNS successful runs"
    echo ""
    
    # Calculate averages
    local build_avg=$(calc_avg "$build_sum" "$valid_runs")
    local execute_avg=$(calc_avg "$execute_sum" "$valid_runs")
    local write_vk_avg=$(calc_avg "$write_vk_sum" "$valid_runs")
    local prove_avg=$(calc_avg "$prove_sum" "$valid_runs")
    local verify_avg=$(calc_avg "$verify_sum" "$valid_runs")
    
    # Store results in global variables for comparison
    eval "${label}_build_time='$build_avg'"
    eval "${label}_execute_time='$execute_avg'"
    eval "${label}_write_vk_time='$write_vk_avg'"
    eval "${label}_prove_time='$prove_avg'"
    eval "${label}_verify_time='$verify_avg'"
    eval "${label}_valid_runs='$valid_runs'"
    
    echo "=== nargo info ($label) ==="
    nargo info
    echo ""
    
    cd "$ROOT_DIR"
}

# Print header
echo "=========================================="
echo "  BoundedVec Benchmark Comparison"
echo "  Iterations per experiment: $NUM_RUNS"
echo "=========================================="

# Run benchmarks for both experiments
run_benchmark "optimized_experiment" "optimized"
run_benchmark "original_experiment" "original"

# Print comparative results in markdown format
echo ""
echo "## Benchmark Results (Average of $NUM_RUNS runs)"
echo ""
echo "| Metric | Original | Optimized |"
echo "|--------|----------|-----------|"
echo "| nargo_build | ${original_build_time:-error} | ${optimized_build_time:-error} |"
echo "| nargo_execute | ${original_execute_time:-error} | ${optimized_execute_time:-error} |"
echo "| bb_write_vk | ${original_write_vk_time:-error} | ${optimized_write_vk_time:-error} |"
echo "| bb_prove | ${original_prove_time:-error} | ${optimized_prove_time:-error} |"
echo "| bb_verify | ${original_verify_time:-error} | ${optimized_verify_time:-error} |"
echo ""
echo "*All times in seconds (averaged over $NUM_RUNS runs)*"
echo ""
echo "Successful runs: original=${original_valid_runs:-0}/$NUM_RUNS, optimized=${optimized_valid_runs:-0}/$NUM_RUNS"
echo ""
