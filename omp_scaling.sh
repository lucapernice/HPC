#!/bin/bash
#SBATCH --partition=THIN
#SBATCH --job-name=omp_scaling
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --time=00:30:00
#SBATCH --output=mandelbrot_omp_scaling_%j.out
#SBATCH --error=mandelbrot_omp_scaling_%j.err

# Load required modules 
module load openMPI/4.1.5/gnu/12.2.1

# Compile your program
mpicc -o merged merged.c -fopenmp -lm

# Function to run OMP weak scaling tests
function run_omp_weak_scaling {
    local executable=$1
    local sizes=(200 400 600 800 1000)  # Adjust the problem sizes as needed
    local max_threads=32  # Maximum number of OMP threads
    local repetitions=3  # Number of repetitions for each test
    for size in "${sizes[@]}"; do
        #echo "Running OMP weak scaling test for problem size $size"
        for ((threads=1; threads<=$max_threads; threads*=2)); do
            export OMP_NUM_THREADS=$threads
            #echo "OMP_NUM_THREADS=$threads"
            total_time=0
            for ((rep=1; rep<=$repetitions; rep++)); do
                start_time=$(date +%s.%N)
                ./$executable $size $size -2 -2 2 2 1000 > /dev/null
                end_time=$(date +%s.%N)
                runtime=$(echo "$end_time - $start_time" | bc -l)
                total_time=$(echo "$total_time + $runtime" | bc -l)
            done
            avg_time=$(echo "$total_time / $repetitions" | bc -l)
            echo "$size,$threads,$avg_time" >> omp_weak_scaling_results.csv  # Adjust output file as needed
        done
        #echo "OMP weak scaling test for problem size $size completed"
    done
}

# Function to run OMP strong scaling tests
function run_omp_strong_scaling {
    local executable=$1
    local size=1000  # Problem size remains constant
    local max_threads=32  # Maximum number of OMP threads
    local repetitions=3  # Number of repetitions for each test
    for ((threads=1; threads<=$max_threads; threads*=2)); do
        #echo "Running OMP strong scaling test with $threads threads"
        export OMP_NUM_THREADS=$threads
        #echo "OMP_NUM_THREADS=$threads"
        total_time=0
        for ((rep=1; rep<=$repetitions; rep++)); do
            start_time=$(date +%s.%N)
            ./$executable $size $size -2 -2 2 2 1000 > /dev/null
            end_time=$(date +%s.%N)
            runtime=$(echo "$end_time - $start_time" | bc -l)
            total_time=$(echo "$total_time + $runtime" | bc -l)
        done
        avg_time=$(echo "$total_time / $repetitions" | bc -l)
        echo "$threads,$avg_time" >> omp_strong_scaling_results.csv  # Adjust output file as needed
        #echo "OMP strong scaling test with $threads threads completed"
    done
}

# Run OMP scaling tests

run_omp_weak_scaling ./merged
run_omp_strong_scaling ./merged
