#pragma once

#define _GNU_SOURCE 1

#ifndef RPYTHON_VMPROF
#include <Python.h>
#endif

#ifdef VMPROF_UNIX
#include <unistd.h>
#endif

// common defines
#define MARKER_STACKTRACE '\x01'
#define MARKER_VIRTUAL_IP '\x02'
#define MARKER_TRAILER '\x03'
#define MARKER_INTERP_NAME '\x04'   /* deprecated */
#define MARKER_HEADER '\x05'
#define MARKER_TIME_N_ZONE '\x06'
#define MARKER_META '\x07'
#define MARKER_NATIVE_SYMBOLS '\x08'

#define VERSION_BASE '\x00'
#define VERSION_THREAD_ID '\x01'
#define VERSION_TAG '\x02'
#define VERSION_MEMORY '\x03'
#define VERSION_MODE_AWARE '\x04'
#define VERSION_DURATION '\x05'
#define VERSION_TIMESTAMP '\x06'

#define PROFILE_MEMORY '\x01'
#define PROFILE_LINES  '\x02'
#define PROFILE_NATIVE '\x04'
#define PROFILE_RPYTHON '\x08'
#define PROFILE_REAL_TIME '\x10'

#define DYN_JIT_FLAG 0xbeefbeef

#ifdef _WIN32
#ifndef VMPROF_WINDOWS
#define VMPROF_WINDOWS
#endif
#endif

#ifdef __x86_64__
#define X86_64
#elif defined(__i386__)
#define X86_32
#endif

#ifdef VMPROF_UNIX
#if defined(X86_64) || defined(X86_32) || defined(__powerpc64__)
#define VMP_SUPPORTS_NATIVE_PROFILING
#endif
#endif

#ifdef RPYTHON_VMPROF
// only for pypy
#include "rvmprof.h"
#include "vmprof_stack.h"
#define PY_STACK_FRAME_T vmprof_stack_t
#define PY_EVAL_RETURN_T void
#define PY_THREAD_STATE_T void
#define FRAME_STEP(f) f->next
#define FRAME_CODE(f) f->
int IS_VMPROF_EVAL(void * ptr);
#else
#define RPY_EXTERN
// for cpython
#include "_vmprof.h"
#include <Python.h>
#include <pythread.h>
#include <frameobject.h>
#define PY_STACK_FRAME_T PyFrameObject
#define PY_EVAL_RETURN_T PyObject
#define PY_THREAD_STATE_T PyThreadState
#define FRAME_STEP(f) f->f_back
#define FRAME_CODE(f) f->f_code

#if CPYTHON_HAS_FRAME_EVALUATION
#define IS_VMPROF_EVAL(PTR) PTR == (void*)_PyEval_EvalFrameDefault
#else
#define IS_VMPROF_EVAL(PTR) (PTR == (void*)PyEval_EvalFrameEx || PTR == (void*)PyEval_EvalFrame)
#endif

#endif

void set_current_codes(void * to);
int opened_profile(const char *interp_name, int memory, int proflines, int native, int real_time);
void flush_codes(void);

