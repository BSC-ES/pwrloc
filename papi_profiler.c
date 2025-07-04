/* -----------------------------------------------------------------------------
 * This wrapper contains functions for interacting with the PAPI energy 
 * profiling options.
 * -----------------------------------------------------------------------------
 */

#include <stdlib.h>
#include <papi.h>

/* Entry point. */
int main(int argc, char **argv) {
    /* Initialize PAPI library, check for errors. */
    int retval = PAPI_library_init(PAPI_VER_CURRENT);
    if (retval != PAPI_OK) {
        printf("Error while initializing PAPI, exitting..\n");
        exit(EXIT_FAILURE);
    }

    exit(EXIT_SUCCESS);
}
