/* -----------------------------------------------------------------------------
 * Header file for papi_component.c file.
 * Contains definitions for a singly linked list of PAPI event components.
 * -----------------------------------------------------------------------------
 */

/* Definition of a struct of event arrays. */
struct component {
    char* name;
    int eventset;
    long long* values;
    struct event* first_event;
    struct event* last_event;
    struct component* next;
};

/* Allocate and initialize a new event linked list node. */
struct component* allocate_component(char* name);

/* Return a component with the provided component name. */
struct component* get_component(struct component* comp, char* name);

/* Add new event to the singly linked list of a component. */
void add_event_to_component(struct component* comp, char* name, char* unit);

/* Clean up a component from the root. */
void clean_up_component(struct component* root);
