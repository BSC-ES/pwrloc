/* -----------------------------------------------------------------------------
 * Contains definitions for a singly linked list of PAPI event components.
 * -----------------------------------------------------------------------------
 */

#include <papi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "papi_component.h"
#include "papi_event.h"

/* Allocate and initialize a new event linked list node. */
struct component* allocate_component(char* name) {
    /* Allocate data. */
    struct component* component = malloc(sizeof(struct component));
    if (!component) {
        perror("malloc failed");
        exit(EXIT_FAILURE);
    }

    /* Initialize data. */
    component->name = name;
    component->eventset = PAPI_NULL;
    component->values = NULL;
    component->first_event = NULL;
    component->last_event = NULL;
    component->next = NULL;

    return component;
}

/* Return a component with the provided component name. */
struct component* get_component(struct component* comp, char* name) {
    struct component* prev = NULL;

    /* Loop over provided component list. */
    while (comp) {
        /* On a match, return component. */
        if (strcmp(comp->name, name) == 0) {
            return comp;
        }

        /* Move up to the next node. */
        prev = comp;
        comp = comp->next;
    }

    /* Create new component if there was no match. */
    comp = allocate_component(name);

    if (prev) {
        prev->next = comp;
    }

    return comp;
}

/* Add new event to the singly linked list of a component. */
void add_event_to_component(struct component* comp, char* name, char* unit) {
    /* Set new event as first node, or prepend to end of existing list. */
    if (comp->first_event == NULL) {
        comp->first_event = allocate_event(name, unit);
        comp->last_event = comp->first_event;
    } else {
        struct event* event = allocate_event(name, unit);
        comp->last_event->next = event;
        event->prev = comp->last_event;
        comp->last_event = event;
    }
}

/* Clean up a component from the root. */
void clean_up_component(struct component* root) {
    struct component* next;
    struct event* cur_event;
    struct event* next_event;

    /* Clean up entire linked list. */
    while (root) {
        /* Clean up eventset. */
        PAPI_cleanup_eventset(root->eventset);
        PAPI_destroy_eventset(&(root->eventset));

        /* Clean up values. */
        free(root->values);

        /* Clean up link list of events. */
        cur_event = root->first_event;

        while (cur_event) {
            next_event = cur_event->next;
            free(cur_event);
            cur_event = next_event;
        }

        next = root->next;
        free(root);
        root = next;
    }
}
