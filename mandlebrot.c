#include "write_pgm_image.h"
#include <math.h>
#include <mpi.h>
#include <omp.h>


int main(int argc, char *argv[]) {
    int mpi_provided_thread_level;
    MPI_Init_thread(&argc, &argv, MPI_THREAD_FUNNELED, &mpi_provided_thread_level);
    if (mpi_provided_thread_level < MPI_THREAD_FUNNELED) {
        printf("Error: MPI_THREAD_FUNNELED level not provided.\n");
        MPI_Finalize();
        exit(1);
    }

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    // Parse command-line arguments
    if (argc != 8) {
        if (rank == 0) {
            printf("Usage: %s n_x n_y x_L y_L x_R y_R I_max\n", argv[0]);
        }
        MPI_Finalize();
        return 1;
    }

    int n_x = atoi(argv[1]);
    int n_y = atoi(argv[2]);
    double x_L = atof(argv[3]);
    double y_L = atof(argv[4]);
    double x_R = atof(argv[5]);
    double y_R = atof(argv[6]);
    int I_max = atoi(argv[7]);

    // Allocate memory for the Mandelbrot set matrix
    int matrix_type = sizeof(short int) <= 2 ? sizeof(short int) : sizeof(char);
    int local_n_x = n_x / size;
    int local_n_y = n_y;
    if (rank < n_x % size) {
        local_n_x++;
    }
    void *M = calloc(local_n_x * local_n_y, matrix_type);

    // Compute the Mandelbrot set
    double dx = (x_R - x_L) / n_x;
    double dy = (y_R - y_L) / n_y;
    double local_x_L = x_L + rank * (x_R - x_L) / size;
    double local_y_L = y_L;

    #pragma omp parallel for collapse(2)
    for (int j = 0; j < local_n_y; j++) {
        for (int i = 0; i < local_n_x; i++) {
            double c_r = local_x_L + i * dx;
            double c_i = local_y_L + j * dy;
            double z_r = 0.0, z_i = 0.0;
            int iter = 0;
            while (iter < I_max && (z_r * z_r + z_i * z_i) < 4.0) {
                double tmp = z_r;
                z_r = z_r * z_r - z_i * z_i + c_r;
                z_i = 2 * tmp * z_i + c_i;
                iter++;
            }
            if (matrix_type == sizeof(short int)) {
                ((short int *)M)[j * local_n_x + i] = (short int)iter;
            } else {
                ((char *)M)[j * local_n_x + i] = (char)iter;
            }
        }
    }

    // Write the Mandelbrot set to a PGM file
    char filename[32];
    sprintf(filename, "mandelbrot_%d.pgm", rank);
    write_pgm_image(filename, M, I_max, local_n_x, local_n_y);

    free(M);
    MPI_Finalize();
    return 0;
}
