/* -----------------------------------------------------------------------------
 * This wrapper contains functions for interacting with the PAPI energy
 * profiling.
 * -----------------------------------------------------------------------------
 */

#include "papi_component.h"
#include "papi_event.h"

#include <stdio.h>
#include <stdlib.h>
#include <papi.h>
#include <string.h>
#include <stdbool.h>

int ARGV_PROGRAM_IDX = 3;

/* Extract the component of an event name. */
char* parse_event_component(char* event) {
    char* event_str = strdup(event);
    char* event_save;
    char* event_token = strtok_r(event_str, ":", &event_save);

    /* Check for no occurrence of :, and return full string if so. */
    if (event_token == NULL) {
        return event;
    }

    return event_token;
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
void parse_input(
    int argc, char** argv, struct component** components, char** program
) {
    /* Return if there are no events and units to profile. */
    if (argc < 3) {
        fprintf(stderr, "No events and units specified.\n");
        exit(EXIT_FAILURE);
    } else if (argc < ARGV_PROGRAM_IDX) {
        fprintf(stderr, "No program provided to profile.\n");
        exit(EXIT_FAILURE);
    }

    /* Parse user-provided events into a linked list of event components. */
    char* event_str = argv[1];
    char* event_save;
    char* event_component;
    char* unit_str = argv[2];
    char* unit_save;

    /* Use thread-safe strtok_r to allow for parsing two lists concurrently. */
    char* event_token = strtok_r(event_str, "\n\\n ", &event_save);
    char* unit_token = strtok_r(unit_str, "\n\\n ", &unit_save);
    struct component* comp;

    /* Parse all events and units, and add them to the right event component. */
    while (event_token != NULL && unit_token != NULL) {
        /* Get the component name from the event and get the component node. */
        event_component = parse_event_component(event_token);
        comp = get_component(*components, event_component);

        /* Store component as root if it is the first. */
        if (*components == NULL) {
            *components = comp;
        }

        /* Add the event to the component node. */
        add_event_to_component(comp, event_token, unit_token);

        /* Move to the next event. */
        event_token = strtok_r(NULL, "\n\\n ", &event_save);
        unit_token = strtok_r(NULL, "\n\\n ", &unit_save);
    }

    /* Concatenate all program arguments into one string. */
    concat_program_args(argc, argv, program);
}

/* Create a PAPI event set and return the number of valid events.
 * Returns EXIT_SUCCESS on success, EXIT_FAILURE otherwise.
 */
int create_papi_eventset(struct component* component) {
    int retval;
    struct event* event;
    struct event* next;
    int num_events;

    /* Creata a PAPI event set for each component. */
    while (component) {
        /* Create the event set. */
        retval = PAPI_create_eventset(&(component->eventset));
        if (retval != PAPI_OK) {
            fprintf(
                stderr, "Error creating eventset: %s\n", PAPI_strerror(retval)
            );
            return EXIT_FAILURE;
        }

        /* Add the events. */
        event = component->first_event;
        num_events = 0;
        while (event) {
            retval = PAPI_add_named_event(component->eventset, event->name);
            if (retval != PAPI_OK) {
                fprintf(
                    stderr,
                    "\033[1;33mWARNING: Invalid PAPI counter: %s\t(%s)\n\033[0m",
                    event->name, PAPI_strerror(retval)
                );

                /* Remove current event from list and move to the next. */
                next = event->next;
                event->prev->next = event->next;

                if (next) {
                    event->next->prev = event->prev;
                }

                free(event);
                event = next;
            } else {
                /* Increment number of successfully parsed events. */
                num_events++;

                /* Move to the next event on success. */
                event = event->next;
            }
        }

        /* Allocate memory for storing the values after PAPI_STOP. */
        component->values = malloc(sizeof(long long) * num_events);

        /* Move to the next component. */
        component = component->next;
    }

    return EXIT_SUCCESS;
}

/* Clean up everything that is allocated. */
void clean_up(struct component* components, char* program) {
    if (components != NULL) clean_up_component(components);
    if (program != NULL) free(program);
}

/* Usage: ./papi_profiler "<events>" "<units>" "<bin>" [arg1 arg2 arg3 ...] */
int main(int argc, char** argv) {
    /* Parse user input.
     * NOTE: This mallocs events and program!
     */
    struct component* components = NULL;
    char* program = NULL;
    parse_input(argc, argv, &components, &program);

    /* Initialize PAPI library, check for errors. */
    int retval = PAPI_library_init(PAPI_VER_CURRENT);
    if (retval != PAPI_VER_CURRENT) {
        fprintf(stderr, "Error initializing PAPI: %s\n", PAPI_strerror(retval));
        clean_up(components, program);
        return EXIT_FAILURE;
    }

    /* Create PAPI event set and remove invalid events from the components. */
    if (create_papi_eventset(components) == EXIT_FAILURE) {
        clean_up(components, program);
        return EXIT_FAILURE;
    }

    /* Reset PAPI counters. */
    bool shutdown = false;
    struct component* cur_comp = components;
    while (cur_comp) {
        retval = PAPI_reset(cur_comp->eventset);
        if (retval != PAPI_OK) {
            fprintf(stderr, "Error resetting PAPI: %s\n", PAPI_strerror(retval));
            shutdown = true;
        }
        cur_comp = cur_comp->next;
    }
    if (shutdown) {
        clean_up(components, program);
        return EXIT_FAILURE;
    }

    /* Start PAPI counters. */
    cur_comp = components;
    while (cur_comp) {
        retval = PAPI_start(cur_comp->eventset);
        if (retval != PAPI_OK) {
            fprintf(stderr, "Error resetting PAPI: %s\n", PAPI_strerror(retval));
            shutdown = true;
        }
        cur_comp = cur_comp->next;
    }
    if (shutdown) {
        clean_up(components, program);
        return EXIT_FAILURE;
    }

    /* Execute application.
     * Using system() works with RAPL as it profiles system wide.
     */
    retval = system(program);
    if (retval != EXIT_SUCCESS) {
        fprintf(
            stderr,
            "\033[1;33mWARNING: The user's program failed.\n\033[0m"
        );
    }

    /* Stop tracking counters. */
    cur_comp = components;
    while (cur_comp) {
        retval = PAPI_stop(cur_comp->eventset, cur_comp->values);
        if (retval != PAPI_OK) {
            fprintf(stderr, "Error stopping PAPI: %s\n", PAPI_strerror(retval));
            shutdown = true;
        }
        cur_comp = cur_comp->next;
    }
    if (shutdown) {
        clean_up(components, program);
        PAPI_shutdown();
        return EXIT_FAILURE;
    }

    /* Print measured results. */
    int event_idx;
    double unit_d;
    struct event* cur_event;
    cur_comp = components;

    while (cur_comp) {
        event_idx = 0;
        cur_event = cur_comp->first_event;

        while (cur_event) {
            unit_d = strtold(cur_event->unit, NULL);
            printf(
                "%s %.3lf J\n", cur_event->name,
                (double)(cur_comp->values[event_idx++] * unit_d)
            );
            cur_event = cur_event->next;
        }

        cur_comp = cur_comp->next;
    }

    /* Clean up. */
    clean_up(components, program);
    PAPI_shutdown();

    return EXIT_SUCCESS;
}
