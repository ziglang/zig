#ifndef _PYPY_SIGNALS_H
#define _PYPY_SIGNALS_H

#include "src/precommondefs.h"


/* utilities to set a signal handler */
RPY_EXTERN
void pypysig_ignore(int signum);  /* signal will be ignored (SIG_IGN) */
RPY_EXTERN
void pypysig_default(int signum); /* signal will do default action (SIG_DFL) */
RPY_EXTERN
void pypysig_setflag(int signum); /* signal will set a flag which can be
                                     queried with pypysig_poll() */
RPY_EXTERN
void pypysig_reinstall(int signum);
RPY_EXTERN
int pypysig_set_wakeup_fd(int fd, int with_nul_byte);

/* utility to poll for signals that arrived */
RPY_EXTERN
int pypysig_poll(void);   /* => signum or -1 */
RPY_EXTERN
void pypysig_pushback(int signum);

/* When a signal is received, pypysig_counter is set to -1. */
/* This is a struct for the JIT. See rsignal.py. */
struct pypysig_long_struct {
    Signed value;
};
RPY_EXTERN struct pypysig_long_struct pypysig_counter;

/* some C tricks to get/set the variable as efficiently as possible:
   use macros when compiling as a stand-alone program, but still
   export a function with the correct name for testing */
RPY_EXTERN
void *pypysig_getaddr_occurred(void);
#define pypysig_getaddr_occurred()   ((void *)(&pypysig_counter))

inline static char pypysig_check_and_reset(void) {
    /* used by reverse_debugging */
    char result = --pypysig_counter.value < 0;
    if (result)
        pypysig_counter.value = 100;
    return result;
}

#endif
