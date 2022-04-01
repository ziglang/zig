#pragma once

/* VMPROF
 *
 * statistical sampling profiler specifically designed to profile programs
 * which run on a Virtual Machine and/or bytecode interpreter, such as Python,
 * etc.
 *
 * The logic to dump the C stack traces is partly stolen from the code in
 * gperftools.
 * The file "getpc.h" has been entirely copied from gperftools.
 *
 * Tested only on gcc, linux, x86_64.
 *
 * Copyright (C) 2014-2017
 *   Antonio Cuni - anto.cuni@gmail.com
 *   Maciej Fijalkowski - fijall@gmail.com
 *   Armin Rigo - arigo@tunes.org
 *   Richard Plangger - planrichi@gmail.com
 *
 */

#include "vmprof.h"

#include "vmprof_mt.h"

#ifdef __FreeBSD__
#include <ucontext.h>
#endif
#include <signal.h>

RPY_EXTERN void vmprof_ignore_signals(int ignored);
RPY_EXTERN long vmprof_enter_signal(void);
RPY_EXTERN long vmprof_exit_signal(void);

/* *************************************************************
 * functions to dump the stack trace
 * *************************************************************
 */

#ifndef RPYTHON_VMPROF
PY_THREAD_STATE_T * _get_pystate_for_this_thread(void);
#endif
int get_stack_trace(PY_THREAD_STATE_T * current, void** result, int max_depth, intptr_t pc);

/* *************************************************************
 * the signal handler
 * *************************************************************
 */

#include <setjmp.h>

void segfault_handler(int arg);
int _vmprof_sample_stack(struct profbuf_s *p, PY_THREAD_STATE_T * tstate, ucontext_t * uc);
void sigprof_handler(int sig_nr, siginfo_t* info, void *ucontext);


/* *************************************************************
 * the setup and teardown functions
 * *************************************************************
 */

int install_sigprof_handler(void);
int remove_sigprof_handler(void);
int install_sigprof_timer(void);
int remove_sigprof_timer(void);
void atfork_disable_timer(void);
void atfork_enable_timer(void);
void atfork_close_profile_file(void);
int install_pthread_atfork_hooks(void);

#ifdef VMP_SUPPORTS_NATIVE_PROFILING
void init_cpyprof(int native);
static void disable_cpyprof(void);
#endif

int close_profile(void);

RPY_EXTERN
int vmprof_enable(int memory, int native, int real_time);
RPY_EXTERN
int vmprof_disable(void);
RPY_EXTERN
int vmprof_register_virtual_function(char *code_name, intptr_t code_uid,
                                     int auto_retry);


void vmprof_aquire_lock(void);
void vmprof_release_lock(void);
