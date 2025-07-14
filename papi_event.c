/* -----------------------------------------------------------------------------
 * Contains definitions for a doubly linked list of PAPI events.
 * -----------------------------------------------------------------------------
 */

/* Definition of an event node. */
struct event {
    char* name;
    char* unit;
    struct event* prev;
    struct event* next;
}

/* Allocate and initialize a new event linked list node. */
struct event* allocate_event(char* name, char* unit) {
    /* Allocate data. */
    struct event* event = malloc(sizeof(struct event));
    if (!event) {
        perror("malloc failed");
        exit(EXIT_FAILURE);
    }

    /* Initialize data. */
    event->name = name;
    event->unit = unit;
    event->prev = NULL;
    event->next = NULL;

    return event;
}
