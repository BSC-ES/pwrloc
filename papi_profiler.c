/* -----------------------------------------------------------------------------
 * This wrapper contains functions for interacting with the PAPI energy
 * profiling.
 * -----------------------------------------------------------------------------
 */

#include <stdio.h>
#include <stdlib.h>
#include <papi.h>
#include <string.h>
#include <stdbool.h>

int ARGV_PROGRAM_IDX = 3;

struct event {
    char* name;
    char* unit;
};


/* Count the number of words in a string. */
int count_words(char* input, const char* delims) {
    char* input_dup = strdup(input);
    char* save_ptr;
    int count = 0;

    char* token = strtok_r(input_dup, delims, &save_ptr);
    while (token != NULL) {
        count++;
        token = strtok_r(NULL, delims, &save_ptr);
    }

    return count;
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
    char* new_alloc = NULL;

    for (int i = ARGV_PROGRAM_IDX; i < argc; i++) {
        /* Resize buffer if needed. Add +2 for space and '\0'. */
        str_size = strlen(*program) + strlen(argv[i]) + 2;

        if (str_size > buf_size) {
            /* Double size until new string fits. */
            while (str_size > buf_size) {
                buf_size *= 2;
            }

            /* Create new bigger buffer. */
            new_alloc = realloc(*program, buf_size);
            if (!new_alloc) {
                perror("malloc failed");
                free(*program);
                exit(EXIT_FAILURE);
            }

            *program = new_alloc;
        }

        /* Concatenate new string into total. */
        if (i > ARGV_PROGRAM_IDX) strcat(*program, " ");
        strcat(*program, argv[i]);
    }
}

/* Parse user input into list of events and the program to profile. 
 * Returns the number of events. 
 */
int parse_input(int argc, char** argv, struct event** events, char** program) {
    /* Return if there are no events and units to profile. */
    if (argc < 3) {
        fprintf(stderr, "No events and units specified.\n");
        exit(EXIT_FAILURE);
    } else if (argc < ARGV_PROGRAM_IDX) {
        fprintf(stderr, "No program provided to profile.\n");
        exit(EXIT_FAILURE);
    }

    /* Allocate events. */
    int num_events = count_words(argv[1], "\n");
    *events = malloc(sizeof(struct event) * num_events);
    if (!*events) {
        perror("malloc failed");
        exit(EXIT_FAILURE);
    }

    /* Parse events and units per combination into one array. */
    char* event_str = argv[1];
    char* event_save;
    char* unit_str = argv[2];
    char* unit_save;

    /* Use thread-safe strtok_r to allow for parsing two lists concurrently. */
    char* event_token = strtok_r(event_str, "\n", &event_save);
    char* unit_token = strtok_r(unit_str, "\n", &unit_save);
    num_events = 0;
    
    while (event_token != NULL && unit_token != NULL) {
        /* Store values in array of structs. */
        (*events)[num_events].name = event_token;
        (*events)[num_events++].unit = unit_token;

        /* Move to the next iteration. */
        event_token = strtok_r(NULL, "\n", &event_save);
        unit_token = strtok_r(NULL, "\n", &unit_save);
    }

    /* Concatenate all program arguments into one string. */
    concat_program_args(argc, argv, program);
    
    return num_events;
}

/* Create a PAPI event set and return the number of valid events. */
int create_papi_eventset(int* eventset, int num_events, struct event** events) {
    /* Create PAPI event set. */
    int retval = PAPI_create_eventset(eventset);
    if (retval != PAPI_OK) {
        fprintf(stderr, "Error creating eventset: %s\n", PAPI_strerror(retval));
        exit(EXIT_FAILURE);
    }

    /* Add counters to even set and ignore the unsupported ones. */
    int num_valid_events = 0;
    for (int i = 0; i < num_events; i++) {
        retval = PAPI_add_named_event(*eventset, (*events)[i].name);
        if (retval != PAPI_OK) {
            fprintf(
                stderr, 
                "Error adding %s: %s - (ignoring)\n", 
                (*events)[i].name, PAPI_strerror(retval)
            );

            /* Mark event entry as unsupported. */
            (*events)[i].name = NULL;
        } else {
            num_valid_events++;
        }
    }

    /* Remove unsupported events from the events list. */
    struct event* valid_events = 
        malloc(sizeof(struct event) * num_valid_events);
    int valid_counter = 0;
    
    for (int i = 0; i < num_events; i++) {
        if ((*events)[i].name != NULL) {
            valid_events[valid_counter].name = (*events)[i].name;
            valid_events[valid_counter++].unit = (*events)[i].unit;
        }
    }

    /* Swap events for updated array and return the new array length. */
    free(*events);
    *events = valid_events;
    return num_valid_events;
}

/* Usage:   ./papi_profiler "<events>" "<units>" "<bin>" [arg1 arg2 arg3 ..] */
int main(int argc, char** argv) {
    /* Parse user input. 
     * NOTE: This mallocs events and program! 
     */
    struct event* events = NULL;
    char* program = NULL;
    int num_events = parse_input(argc, argv, &events, &program);

    /* Initialize PAPI library, check for errors. */
    int retval = PAPI_library_init(PAPI_VER_CURRENT);
    if (retval != PAPI_VER_CURRENT) {
        fprintf(stderr, "Error initializing PAPI: %s\n", PAPI_strerror(retval));
        if (events != NULL) free(events);
        if (program != NULL) free(program);
        return EXIT_FAILURE;
    }

    /* Create PAPI event set and update events list with valid ones. */
    int eventset = PAPI_NULL;
    num_events = create_papi_eventset(&eventset, num_events, &events);
    if (num_events == 0) {
        fprintf(stderr, "No supported PAPI events to profile.\n");
        if (events != NULL) free(events);
        if (program != NULL) free(program);
        return EXIT_FAILURE;
    }

    /* Reset PAPI counters. */
    retval = PAPI_reset(eventset);
    if (retval != PAPI_OK) {
        fprintf(stderr,"Error resetting PAPI: %s\n", PAPI_strerror(retval));
    }

    /* Start tracking PAPI counters. */
    retval = PAPI_start(eventset);
    if (retval != PAPI_OK) {
        fprintf(stderr,"Error starting PAPI: %s\n", PAPI_strerror(retval));
    }

    /* Execute application. */
    // TODO: Fix security problems with system call!
    retval = system(program);
    if (retval != EXIT_SUCCESS) {
        fprintf(stderr, "The user's program failed.\n");
    }

    /* Stop tracking counters. */
    long long values[num_events];
    retval = PAPI_stop(eventset, values);
    if (retval != PAPI_OK) {
        fprintf(stderr,"Error stopping:  %s\n", PAPI_strerror(retval));
        if (events != NULL) free(events);
        if (program != NULL) free(program);
        PAPI_cleanup_eventset(eventset);
        PAPI_destroy_eventset(&eventset);
        PAPI_shutdown();
        return EXIT_FAILURE;
    }

    /* Print measured results. */
    for (int i = 0; i < num_events; i++) {
        /* TODO:  * events[i].scalar */
        printf("%s: %lld\n", events[i].name, values[i]);
    }

    /* Clean up. */
    if (events != NULL) free(events);
    if (program != NULL) free(program);
    PAPI_cleanup_eventset(eventset);
    PAPI_destroy_eventset(&eventset);
    PAPI_shutdown();

    return EXIT_SUCCESS;
}
