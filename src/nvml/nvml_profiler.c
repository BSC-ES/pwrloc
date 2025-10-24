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
        execvp(argv[1], &argv[1]);

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
        printf("GPU %d:\t%.3f J\n", i, energy_consumed[i]);
        total_energy += energy_consumed[i];
    }

    printf("Total:\t%.3f J\n", total_energy);
    nvmlShutdown();
    return EXIT_SUCCESS;
}
