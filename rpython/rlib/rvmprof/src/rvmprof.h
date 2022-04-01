#pragma once

#include <signal.h>
#include "shared/vmprof.h"

#define SINGLE_BUF_SIZE (8192 - 2 * sizeof(unsigned int))

#ifdef VMPROF_WINDOWS
#include <crtdefs.h>
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;
typedef intptr_t ssize_t;
#else
#include <inttypes.h>
#include <stdint.h>
#endif

#ifndef RPY_EXTERN
#define RPY_EXTERN RPY_EXPORTED
#endif
#ifdef _WIN32
#ifndef RPY_EXPORTED
#define RPY_EXPORTED __declspec(dllexport)
#endif
#else
#define RPY_EXPORTED  extern __attribute__((visibility("default")))
#endif

RPY_EXTERN char *vmprof_init(int fd, double interval, int memory,
                     int lines, const char *interp_name, int native, int real_time);
RPY_EXTERN void vmprof_ignore_signals(int);
RPY_EXTERN int vmprof_enable(int memory, int native, int real_time);
RPY_EXTERN int vmprof_disable(void);
RPY_EXTERN int vmprof_register_virtual_function(char *, intptr_t, int);
RPY_EXTERN void* vmprof_stack_new(void);
RPY_EXTERN int vmprof_stack_append(void*, long);
RPY_EXTERN long vmprof_stack_pop(void*);
RPY_EXTERN void vmprof_stack_free(void*);
RPY_EXTERN intptr_t vmprof_get_traceback(void *, void *, void**, intptr_t);
RPY_EXTERN long vmprof_get_profile_path(char *, long);
RPY_EXTERN int vmprof_stop_sampling(void);
RPY_EXTERN void vmprof_start_sampling(void);

long vmprof_write_header_for_jit_addr(intptr_t *result, long n,
                                      intptr_t addr, int max_depth);

#define RVMPROF_TRACEBACK_ESTIMATE_N(num_entries)  (2 * (num_entries) + 4)
