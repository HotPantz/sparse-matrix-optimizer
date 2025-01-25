#!/bin/bash

# Ensure MAQAO is installed
if ! command -v maqao &> /dev/null
then
    echo "MAQAO could not be found. Please install MAQAO and update MAQAO_HOME."
    exit 1
fi

# Define executables
EXECUTABLES=("spmxv-gcc-O3.exe" "spmxv-gcc-Ofast.exe" "spmxv-icpx-O3.exe" "spmxv-icpx-Fast.exe")

# Input parameters
INPUT_FILE="input-matrix/mat_dim_493039.txt"
NUM_REPEATS=20000

# Define thread counts for scalability tests
THREADS=(1 2 3 4 6)

# MAQAO profiling modes
MODES=("standard" "stability" "scalability" "compare")

# Directory to store MAQAO results
RESULTS_DIR="results/maqao_results"
mkdir -p "$RESULTS_DIR"

# Function to run MAQAO profiling
run_maqao() {
    local exe=$1
    local mode=$2
    local threads=$3

    case $mode in
        standard)
            MAQAO_CMD="maqao oneview -create-report=one"
            ;;
        stability)
            MAQAO_CMD="maqao oneview -mode stability"
            ;;
        scalability)
            MAQAO_CMD="maqao oneview --with-scalability=strong"
            ;;
        compare)
            MAQAO_CMD="maqao oneview --mode compare"
            ;;
        *)
            echo "Unknown MAQAO mode: $mode"
            return
            ;;
    esac

    local exe_name="${exe%.*}"
    local result_subdir="$RESULTS_DIR/${exe_name}/$mode"
    mkdir -p "$result_subdir"

    echo "Running $exe with mode: $mode"

    # Set environment variables for OpenMP
    export OMP_PLACES=cores
    export OMP_PROC_BIND=close

    if [ "$mode" == "scalability" ]; then
        # For scalability, iterate over thread counts
        for t in "${THREADS[@]}"; do
            echo "  Threads: $t"
            MAQAO_OUTPUT="$result_subdir/result_threads_${t}.html"
            maqao oneview --create-report=one --output="$MAQAO_OUTPUT" -- ./"$exe" -f "$INPUT_FILE" -t "$t" -r "$NUM_REPEATS"
        done
    elif [ "$mode" == "compare" ]; then
        # Comparison across all executables
        local compare_dir="$result_subdir"
        mkdir -p "$compare_dir"
        local compare_output="$compare_dir/compare.html"
        echo "  Running comparison for all executables"
        maqao oneview --mode compare --output="$compare_output" -- "${EXECUTABLES[@]/#./}" -f "$INPUT_FILE" -t "${THREADS[-1]}" -r "$NUM_REPEATS"
    else
        # For other modes, use maximum threads (6)
        local max_threads=6
        MAQAO_OUTPUT="$result_subdir/result.html"
        maqao oneview --create-report=one --output="$MAQAO_OUTPUT" -- ./"$exe" -f "$INPUT_FILE" -t "$max_threads" -r "$NUM_REPEATS"
    fi
}

# Iterate over each executable and run all profiling modes
for exe in "${EXECUTABLES[@]}"; do
    for mode in "${MODES[@]}"; do
        run_maqao "$exe" "$mode"
    done
done

echo "All profiling runs completed. Results are stored in the '$RESULTS_DIR' directory."