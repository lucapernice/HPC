#!/bin/bash
#SBATCH --job-name=HPC
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=24
#SBATCH --time=00:30:00
#SBATCH --partition THIN
#SBATCH --exclusive
#SBATCH --exclude fat[001-002]

module load openMPI/4.1.5/gnu/12.2.1

echo "Processes,Size,Algorithm,Latency" > bcast_algorithms_thin.csv

# Numero di ripetizioni per ottenere una media
repetitions=5

# Array of algorithm numbers to test
algorithms=(1 2 3 4)

# Ciclo esterno per il numero di processori
for processes in {2..48..2}
do
    # Ciclo interno per la dimensione del messaggio da 2^1 a 2^20
    for size_power in {1..20}
    do
        # Calcola la dimensione come 2 elevato alla potenza corrente
        size=$((2**size_power))

        # Ciclo per ogni algoritmo
        for alg in "${algorithms[@]}"
        do
            # Esegui osu_bcast con numero di processi, dimensione, algoritmo e numero di ripetizioni su due nodi
            result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm $alg osu_bcast -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}')
	    
            echo "$processes, $size, $alg, $result_bcast"
            # Scrivi i risultati nel file CSV
            echo "$processes,$size,$alg,$result_bcast" >> bcast_algorithms_thin.csv
        done
    done
done
