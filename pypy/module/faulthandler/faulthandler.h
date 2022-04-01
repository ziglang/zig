#ifndef PYPY_FAULTHANDLER_H
#define PYPY_FAULTHANDLER_H

#include "src/precommondefs.h"
#ifdef _MSC_VER
#include <crtdefs.h>
#else
#include <stdint.h>
#endif


typedef void (*pypy_faulthandler_cb_t)(int fd, intptr_t *array_p,
                                       intptr_t length);

RPY_EXTERN char *pypy_faulthandler_setup(pypy_faulthandler_cb_t dump_callback);
RPY_EXTERN void pypy_faulthandler_teardown(void);

RPY_EXTERN char *pypy_faulthandler_enable(int fd, int all_threads);
RPY_EXTERN void pypy_faulthandler_disable(void);
RPY_EXTERN int pypy_faulthandler_is_enabled(void);

RPY_EXTERN void pypy_faulthandler_write(int fd, const char *str);
RPY_EXTERN void pypy_faulthandler_write_uint(int fd, unsigned long value,
                                             int min_digits);

RPY_EXTERN void pypy_faulthandler_dump_traceback(int fd, int all_threads,
                                                 void *ucontext);

RPY_EXTERN char *pypy_faulthandler_dump_traceback_later(
    long long microseconds, int repeat, int fd, int exit);
RPY_EXTERN void pypy_faulthandler_cancel_dump_traceback_later(void);

RPY_EXTERN int pypy_faulthandler_check_signum(long signum);
RPY_EXTERN char *pypy_faulthandler_register(int, int, int, int);
RPY_EXTERN int pypy_faulthandler_unregister(int signum);


RPY_EXTERN int pypy_faulthandler_read_null(void);
RPY_EXTERN void pypy_faulthandler_sigsegv(void);
RPY_EXTERN int pypy_faulthandler_sigfpe(void);
RPY_EXTERN void pypy_faulthandler_sigabrt(void);
RPY_EXTERN double pypy_faulthandler_stackoverflow(double);


#endif  /* PYPY_FAULTHANDLER_H */
