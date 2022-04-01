#pragma once

#include "vmprof.h"
#include "machine.h"
#include "compat.h"

#include <stddef.h>
#include <time.h>
#include <stdlib.h>

#ifdef VMPROF_UNIX
#include <sys/time.h>
#include "vmprof_mt.h"
#include <signal.h>
#include <pthread.h>
#endif

#ifdef VMPROF_UNIX
#include "vmprof_getpc.h"
#endif

#ifdef VMPROF_LINUX
#include <syscall.h>
#endif

#ifdef VMPROF_BSD
#include <sys/syscall.h>
#endif

#define MAX_FUNC_NAME 1024

#ifdef VMPROF_UNIX

ssize_t search_thread(pthread_t tid, ssize_t i);
ssize_t insert_thread(pthread_t tid, ssize_t i);
ssize_t remove_thread(pthread_t tid, ssize_t i);
ssize_t remove_threads(void);

#endif

#define MAX_STACK_DEPTH   \
    ((SINGLE_BUF_SIZE - sizeof(struct prof_stacktrace_s)) / sizeof(void *))

/*
 * NOTE SHOULD NOT BE DONE THIS WAY. Here is an example why:
 * assume the following struct content:
 * struct ... {
 *    char padding[sizeof(long) - 1];
 *    char marker;
 *    long count, depth;
 *    void *stack[];
 * }
 *
 * Here a table of the offsets on a 64 bit machine:
 * field  | GCC | VSC (windows)
 * ---------------------------
 * marker |   7 |   3
 * count  |   8 |   4
 * depth  |  16 |   8
 * stack  |  24 |   16 (VSC adds 4 padding byte hurray!)
 *
 * This means that win32 worked by chance (because sizeof(void*)
 * is 4, but fails on win32
 */
typedef struct prof_stacktrace_s {
#ifdef VMPROF_WINDOWS
    // if padding is 8 bytes, then on both 32bit and 64bit, the
    // stack field is aligned
    char padding[sizeof(void*) - 1];
#else
    char padding[sizeof(long) - 1];
#endif
    char marker;
    long count, depth;
    void *stack[];
} prof_stacktrace_s;

#define SIZEOF_PROF_STACKTRACE sizeof(long)+sizeof(long)+sizeof(char)

RPY_EXTERN
char *vmprof_init(int fd, double interval, int memory,
                  int proflines, const char *interp_name, int native, int real_time);

int opened_profile(const char *interp_name, int memory, int proflines, int native, int real_time);

#ifdef RPYTHON_VMPROF
PY_STACK_FRAME_T *get_vmprof_stack(void);
RPY_EXTERN
intptr_t vmprof_get_traceback(void *stack, void *ucontext,
                              void **result_p, intptr_t result_length);
#endif

int vmprof_get_signal_type(void);
long vmprof_get_prepare_interval_usec(void);
long vmprof_get_profile_interval_usec(void);
void vmprof_set_prepare_interval_usec(long value);
void vmprof_set_profile_interval_usec(long value);
int vmprof_is_enabled(void);
void vmprof_set_enabled(int value);
int vmprof_get_itimer_type(void);
#ifdef VMPROF_UNIX
int broadcast_signal_for_threads(void);
int is_main_thread(void);
#endif
