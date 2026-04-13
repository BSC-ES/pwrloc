/* -----------------------------------------------------------------------------
 * This wrapper contains functions for interacting with the NVML energy
 * profiling of NVIDIA GPUs.
 * -----------------------------------------------------------------------------
 */

#include <nvml.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define INTERVAL_MS 100

/* Resize the given buffer if the new size is bigger than its current size. */
void resize_buffer(char** buffer, size_t* buf_size, size_t min_size) {
    if (min_size > *buf_size) {
        /* Double size until new string fits. */
        while (min_size > *buf_size) {
            *buf_size *= 2;
        }

        /* Create new bigger buffer. */
        char* new_alloc = realloc(*buffer, *buf_size);
        if (!new_alloc) {
            perror("malloc failed");
            free(*buffer);
            exit(EXIT_FAILURE);
        }

        *buffer = new_alloc;
    }
}

/* Concatenate the arguments defining the program and args to be profiled. */
void concat_program_args(int argc, char** argv, char** program) {
    size_t buf_size = 512;

    /* Allocate space for the total string, and initialize as empty. */
    *program = malloc(buf_size);
    if (!*program) {
        perror("malloc failed");
        exit(EXIT_FAILURE);
    }
    (*program)[0] = '\0';

    /* Loop over args and append to string, resizing buffer when needed. */
    size_t str_size = 0;

    for (int i = 1; i < argc; i++) {
        /* Resize buffer if needed. Add +2 for space and '\0'. */
        str_size = strlen(*program) + strlen(argv[i]) + 2;
        resize_buffer(program, &buf_size, str_size);

        /* Concatenate new string into total. */
        if (i > ARGV_PROGRAM_IDX)
            strcat(*program, " ");
        strcat(*program, argv[i]);
    }

    /* Expand program with piping stdout to stderr.
     * Resize buffer if needed. Add +1 for '\0'.
     */
    char* stdout_piping = " 1>&2";
    str_size = strlen(*program) + strlen(stdout_piping) + 1;
    resize_buffer(program, &buf_size, str_size);
    strcat(*program, stdout_piping);
}

/* Get the current time in seconds. */
double get_time_seconds() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

/* Usage: ./nvml_profiler "<bin>" [arg1 arg2 arg3 ...] */
int main(int argc, char* argv[]) {
    /* Verify that an application is passed. */
    if (argc < 2) {
        fprintf(stderr, "No program provided to profile.\n");
        return EXIT_FAILURE;
    }

    /* Initialize NVML. */
    nvmlReturn_t result = nvmlInit();
    if (result != NVML_SUCCESS) {
        fprintf(
            stderr, "Failed to initialize NVML: %s\n", nvmlErrorString(result)
        );
        return EXIT_FAILURE;
    }

    /* Register all available devices. */
    unsigned int num_devices;
    nvmlDeviceGetCount(&num_devices);
    nvmlDevice_t devices[num_devices];

    for (unsigned int i = 0; i < num_devices; i++) {
        result = nvmlDeviceGetHandleByIndex(i, &devices[i]);
        if (result != NVML_SUCCESS) {
            fprintf(
                stderr, "Failed to get handle for GPU %d: %s\n", i,
                nvmlErrorString(result)
            );
            return EXIT_FAILURE;
        }
    }

    /* Run application in a fork, as NVML measures entire GPU boards. */
    pid_t pid = fork();
    if (pid == 0) {
        /* The child process executes the application and terminates. */
        char* program = NULL;
        concat_program_args(argc, argv, program);
        execvp(argv[1], program);

        /* Exit with error if the child process did not terminate. */
        perror("execvp failed");
        exit(EXIT_FAILURE);
    }

    /* The parent process measures power usage while the child is alive. */
    double energy_consumed[num_devices];
    unsigned int power_mw;
    double t0 = get_time_seconds();
    double t1, dt;

    for (unsigned int i = 0; i < num_devices; i++) {
        energy_consumed[i] = 0.0;
    }

    while (waitpid(pid, NULL, WNOHANG) == 0) {
        /* Poll the power consumption at the specified interval. */
        usleep(INTERVAL_MS * 1000);
        t1 = get_time_seconds();
        dt = t1 - t0;
        t0 = t1;

        /* Get power consumption and transform in energy consumption. */
        for (unsigned int i = 0; i < num_devices; i++) {
            if (nvmlDeviceGetPowerUsage(devices[i], &power_mw) ==
                NVML_SUCCESS) {
                /* Convert mW to W. */
                energy_consumed[i] += (power_mw / 1000.0) * dt;
            } else {
                fprintf(
                    stderr, "Failed to get power for GPU %d: %s\n", i,
                    nvmlErrorString(result)
                );
            }
        }
    }

    /* Print consumption per GPU and the total after the child terminates. */
    double total_energy = 0.0;

    for (unsigned int i = 0; i < num_devices; i++) {
        printf("GPU_%d %.3f J\n", i, energy_consumed[i]);
        total_energy += energy_consumed[i];
    }

    printf("Total %.3f J\n", total_energy);
    nvmlShutdown();
    return EXIT_SUCCESS;
}
