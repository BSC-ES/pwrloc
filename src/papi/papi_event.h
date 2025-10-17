/* -----------------------------------------------------------------------------
 * Header file for papi_event.c file.
 * Contains definitions for a doubly linked list of PAPI events.
 * -----------------------------------------------------------------------------
 */

/* Definition of an event node. */
struct event {
    char* name;
    char* unit;
    struct event* prev;
    struct event* next;
};

/* Allocate and initialize a new event linked list node. */
struct event* allocate_event(char* name, char* unit);
