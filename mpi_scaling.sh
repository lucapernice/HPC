#!/bin/bash
#SBATCH --partition=THIN
#SBATCH --job-name=mpi_scaling
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --time=00:50:00
#SBATCH --output=mandelbrot_mpi_scaling_%j.out
#SBATCH --error=mandelbrot_mpi_scaling_%j.err

# Load required modules 
module load openMPI/4.1.5/gnu/12.2.1

# Compile your program
# mpicc -o merged merged.c -fopenmp

# Function to run MPI weak scaling tests
function run_mpi_weak_scaling {
    local executable=$1
    local sizes=(1000 2000 3000 4000 5000 6000 7000 8000 9000 10000)  # Adjust the problem sizes as needed
    local max_tasks=32  # Maximum number of MPI tasks
    local repetitions=5  # Number of repetitions for each test
    for size in "${sizes[@]}"; do
        #echo "Running MPI weak scaling test for problem size $size"
        for ((tasks=1; tasks<=$max_tasks; tasks++)); do
            total_time=0
            for ((rep=1; rep<=$repetitions; rep++)); do
                start_time=$(date +%s.%N)
                mpirun -n $tasks ./$executable $size $size -2 -2 2 2 1000 > /dev/null
                end_time=$(date +%s.%N)
                runtime=$(echo "$end_time - $start_time" | bc -l)
                total_time=$(echo "$total_time + $runtime" | bc -l)
            done
            avg_time=$(echo "$total_time / $repetitions" | bc -l)
            echo "$size,$tasks,$avg_time" >> mpi_weak_scaling_results.csv  # Adjust output file as needed
        done
        #echo "MPI weak scaling test for problem size $size completed"
    done
}

# Function to run MPI strong scaling tests
function run_mpi_strong_scaling {
    local executable=$1
    local size=1000  # Problem size remains constant
    local max_tasks=8  # Maximum number of MPI tasks
    local repetitions=3  # Number of repetitions for each test
    for ((tasks=1; tasks<=$max_tasks; tasks++)); do
        #echo "Running MPI strong scaling test for $tasks MPI tasks"
        total_time=0
        for ((rep=1; rep<=$repetitions; rep++)); do
            start_time=$(date +%s.%N)
            mpirun -n $tasks ./$executable $size $size -2 -2 2 2 1000 > /dev/null
            end_time=$(date +%s.%N)
            runtime=$(echo "$end_time - $start_time" | bc -l)
            total_time=$(echo "$total_time + $runtime" | bc -l)
        done
        avg_time=$(echo "$total_time / $repetitions" | bc -l)
        echo "$tasks,$avg_time" >> mpi_strong_scaling_results.csv  # Adjust output file as needed
        #echo "MPI strong scaling test for $tasks MPI tasks completed"
    done
}

# Run MPI scaling tests
#echo "Running MPI scaling tests..."
run_mpi_weak_scaling ./your_executable_name
run_mpi_strong_scaling ./your_executable_name

