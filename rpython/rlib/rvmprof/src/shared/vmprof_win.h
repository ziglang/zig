#pragma once

#include "windows.h"
#include "compat.h"
#include "vmp_stack.h"
#include <tlhelp32.h>

int prepare_concurrent_bufs(void);

// This file has been inspired (but not copied from since the LICENSE
// would not allow it) from verysleepy profiler

int vmp_write_all(const char *buf, size_t bufsize);

#ifdef RPYTHON_VMPROF
typedef struct pypy_threadlocal_s PY_WIN_THREAD_STATE;
#else
typedef PyThreadState PY_WIN_THREAD_STATE;
#endif


int vmprof_register_virtual_function(char *code_name, intptr_t code_uid,
                                     int auto_retry);

PY_WIN_THREAD_STATE * get_current_thread_state(void);
int vmprof_enable(int memory, int native, int real_time);
int vmprof_disable(void);
void vmprof_ignore_signals(int ignored);
int vmp_native_enable(void);
void vmp_native_disable(void);
int get_stack_trace(PY_WIN_THREAD_STATE * current, void** result,
                    int max_depth, intptr_t pc);
