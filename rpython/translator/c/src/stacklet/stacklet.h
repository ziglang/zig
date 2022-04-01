/********** A really minimal coroutine package for C **********/
#ifndef _STACKLET_H_
#define _STACKLET_H_

#include "src/precommondefs.h"
#include <stdlib.h>


/* A "stacklet handle" is an opaque pointer to a suspended stack.
 * Whenever we suspend the current stack in order to switch elsewhere,
 * stacklet.c passes to the target a 'stacklet_handle' argument that points
 * to the original stack now suspended.  The handle must later be passed
 * back to this API once, in order to resume the stack.  It is only
 * valid once.
 */
typedef struct stacklet_s *stacklet_handle;

#define EMPTY_STACKLET_HANDLE  ((stacklet_handle) -1)


/* Multithread support.
 */
typedef struct stacklet_thread_s *stacklet_thread_handle;

RPY_EXTERN stacklet_thread_handle stacklet_newthread(void);
RPY_EXTERN void stacklet_deletethread(stacklet_thread_handle thrd);


/* The "run" function of a stacklet.  The first argument is the handle
 * of the stack from where we come.  When such a function returns, it
 * must return a (non-empty) stacklet_handle that tells where to go next.
 */
typedef stacklet_handle (*stacklet_run_fn)(stacklet_handle, void *);

/* Call 'run(source, run_arg)' in a new stack.  See stacklet_switch()
 * for the return value.
 */
RPY_EXTERN stacklet_handle stacklet_new(stacklet_thread_handle thrd,
                             stacklet_run_fn run, void *run_arg);

/* Switch to the target handle, resuming its stack.  This returns:
 *  - if we come back from another call to stacklet_switch(), the source handle
 *  - if we come back from a run() that finishes, EMPTY_STACKLET_HANDLE
 *  - if we run out of memory, NULL
 * Don't call this with an already-used target, with EMPTY_STACKLET_HANDLE,
 * or with a stack handle from another thread (in multithreaded apps).
 */
RPY_EXTERN stacklet_handle stacklet_switch(stacklet_handle target);

/* Delete a stack handle without resuming it at all.
 * (This works even if the stack handle is of a different thread)
 */
RPY_EXTERN void stacklet_destroy(stacklet_handle target);

/* stacklet_handle _stacklet_switch_to_copy(stacklet_handle) --- later */

/* Hack: translate a pointer into the stack of a stacklet into a pointer
 * to where it is really stored so far.  Only to access word-sized data.
 */
RPY_EXTERN
char **_stacklet_translate_pointer(stacklet_handle context, char **ptr);

#endif /* _STACKLET_H_ */
