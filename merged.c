#include <stdlib.h>
#include <stdio.h>
#include <mpi.h>
#include <omp.h>

#define XWIDTH 256
#define YWIDTH 256
#define MAXVAL 65535

#if ((0x100 & 0xf) == 0x0)
#define I_M_LITTLE_ENDIAN 1
#define swap(mem) (((mem) & (short int)0xff00) >> 8) + (((mem) & (short int)0x00ff) << 8)
#else
#define I_M_LITTLE_ENDIAN 0
#define swap(mem) (mem)
#endif

// Function to write PGM image
void write_pgm_image(void *image, int maxval, int xsize, int ysize, const char *image_name) {
    FILE *image_file;
    image_file = fopen(image_name, "w");

    // Determine color depth based on maximum value
    int color_depth = 1 + (maxval > 255);

    // Write PGM header
    fprintf(image_file, "P5\n# generated by\n# Luca Pernice\n%d %d\n%d\n", xsize, ysize, maxval);

    // Write image data
    fwrite(image, 1, xsize * ysize * color_depth, image_file);

    fclose(image_file);
    return;
}

int main(int argc, char *argv[]) {
    int mpi_provided_thread_level;
    // Initialize MPI with threading support
    MPI_Init_thread(&argc, &argv, MPI_THREAD_FUNNELED, &mpi_provided_thread_level);
    if (mpi_provided_thread_level < MPI_THREAD_FUNNELED) {
        printf("Error: MPI_THREAD_FUNNELED level not provided.\n");
        MPI_Finalize();
        exit(1);
    }

    int rank, size;
    // Get MPI rank and size
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

    // Extract parameters from command-line arguments
    int n_x = atoi(argv[1]);
    int n_y = atoi(argv[2]);
    double x_L = atof(argv[3]);
    double y_L = atof(argv[4]);
    double x_R = atof(argv[5]);
    double y_R = atof(argv[6]);
    int I_max = atoi(argv[7]);

    // Determine matrix type (char or short int) based on maximum value
    int matrix_type = sizeof(short int) <= 2 ? sizeof(short int) : sizeof(char);

    // Calculate local dimensions for each MPI process
    int local_n_x = n_x / size;
    int local_n_y = n_y;
    if (rank < n_x % size) {
        local_n_x++;
    }

    // Allocate memory for the Mandelbrot set matrix
    void *M = calloc(local_n_x * local_n_y, matrix_type);

    // Compute local region of the Mandelbrot set using OpenMP parallelism
    double dx = (x_R - x_L) / n_x;
    double dy = (y_R - y_L) / n_y;
    double local_x_L = x_L + rank * (x_R - x_L) / size;
    double local_y_L = y_L;


#pragma omp parallel for collapse(2)
    for (int j = 0; j < local_n_y; j++) {
        for (int i = 0; i < local_n_x; i++) {
            // Compute Mandelbrot set for each point in the local region
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
            // Store iteration count in Mandelbrot set matrix
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
    write_pgm_image(M, I_max, local_n_x, local_n_y,filename);

    free(M);
    MPI_Finalize();
    return 0;
}

