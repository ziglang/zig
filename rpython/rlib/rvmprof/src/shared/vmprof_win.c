#include "vmprof_win.h"

volatile int thread_started = 0;
volatile int enabled = 0;

HANDLE write_mutex;

int prepare_concurrent_bufs(void)
{
    if (!(write_mutex = CreateMutex(NULL, FALSE, NULL)))
        return -1;
    return 0;
}

int vmprof_register_virtual_function(char *code_name, intptr_t code_uid,
                                     int auto_retry)
{
    char buf[2048];
    long namelen;

    namelen = (long)strnlen(code_name, 1023);
    buf[0] = MARKER_VIRTUAL_IP;
    *(intptr_t*)(buf + 1) = code_uid;
    *(long*)(buf + 1 + sizeof(intptr_t)) = namelen;
    memcpy(buf + 1 + sizeof(intptr_t) + sizeof(long), code_name, namelen);
    vmp_write_all(buf, 1 + sizeof(intptr_t) + sizeof(long) + namelen);
    return 0;
}

int vmp_write_all(const char *buf, size_t bufsize)
{
    int res;
    int fd;
    int count;

    res = WaitForSingleObject(write_mutex, INFINITE);
    fd = vmp_profile_fileno();

    if (fd == -1) {
        ReleaseMutex(write_mutex);
        return -1;
    }
    while (bufsize > 0) {
        count = _write(fd, buf, (long)bufsize);
        if (count <= 0) {
            ReleaseMutex(write_mutex);
            return -1;   /* failed */
        }
        buf += count;
        bufsize -= count;
    }
    ReleaseMutex(write_mutex);
    return 0;
}

HANDLE write_mutex;

#include "vmprof_common.h"

int vmprof_snapshot_thread(DWORD thread_id, PY_WIN_THREAD_STATE *tstate, prof_stacktrace_s *stack)
{
    HRESULT result;
    HANDLE hThread;
    int depth;
    CONTEXT ctx;
#ifdef RPYTHON_LL2CTYPES
    return 0; // not much we can do
#else
#if !defined(RPY_TLOFS_thread_ident) && defined(RPYTHON_VMPROF)
    return 0; // we can't freeze threads, unsafe
#else
    hThread = OpenThread(THREAD_ALL_ACCESS, FALSE, thread_id);
    if (!hThread) {
        return -1;
    }
    result = SuspendThread(hThread);
    if(result == 0xffffffff)
        return -1; // possible, e.g. attached debugger or thread alread suspended
    // find the correct thread
#ifdef RPYTHON_VMPROF
    ctx.ContextFlags = CONTEXT_FULL;
    if (!GetThreadContext(hThread, &ctx))
        return -1;
    depth = get_stack_trace(tstate->vmprof_tl_stack,
                     stack->stack, MAX_STACK_DEPTH-2, ctx.Eip);
    stack->depth = depth;
    stack->stack[depth++] = thread_id;
    stack->count = 1;
    stack->marker = MARKER_STACKTRACE;
    ResumeThread(hThread);
    return depth;
#else
    depth = vmp_walk_and_record_stack(tstate->frame, stack->stack,
                                      MAX_STACK_DEPTH, 0, 0);
    stack->depth = depth;
    stack->stack[depth++] = (void*)((ULONG_PTR)thread_id);
    stack->count = 1;
    stack->marker = MARKER_STACKTRACE;
    ResumeThread(hThread);
    return depth;
#endif

#endif
#endif
}

/* Seems that CPython 3.5.1 made our job harder.  Did not find out how
   to do that without these hacks.  We can't use PyThreadState_GET(),
   because that calls PyThreadState_Get() which fails an assert if the
   result is NULL. */
#if PY_MAJOR_VERSION >= 3 && !defined(_Py_atomic_load_relaxed)
                             /* this was abruptly un-defined in 3.5.1 */
void *volatile _PyThreadState_Current;
   /* XXX simple volatile access is assumed atomic */
#  define _Py_atomic_load_relaxed(pp)  (*(pp))
#endif

#ifndef RPYTHON_VMPROF
static
PY_WIN_THREAD_STATE * get_current_thread_state(void)
{
#if PY_MAJOR_VERSION < 3
    return _PyThreadState_Current;
#elif PY_VERSION_HEX < 0x03050200
    return (PyThreadState*) _Py_atomic_load_relaxed(&_PyThreadState_Current);
#else
    return _PyThreadState_UncheckedGet();
#endif
}
#endif

long __stdcall vmprof_mainloop(void *arg)
{
#ifdef RPYTHON_LL2CTYPES
    // for tests only
    return 0;
#else
    // it is not a test case!
    PY_WIN_THREAD_STATE *tstate;
    HANDLE hThreadSnap = INVALID_HANDLE_VALUE; 
    prof_stacktrace_s *stack = (prof_stacktrace_s*)malloc(SINGLE_BUF_SIZE);
    int depth;
#ifndef RPYTHON_VMPROF
    // cpython version
    while (1) {
        Sleep(vmprof_get_profile_interval_usec() * 1000);
        if (!enabled) {
            continue;
        }
        tstate = get_current_thread_state();
        if (!tstate)
            continue;
        depth = vmprof_snapshot_thread(tstate->thread_id, tstate, stack);
        if (depth > 0) {
            vmp_write_all((char*)stack + offsetof(prof_stacktrace_s, marker),
                          SIZEOF_PROF_STACKTRACE + depth * sizeof(void*));
        }
    }
#else
    // pypy version
    while (1) {
        //Sleep(vmprof_get_profile_interval_usec() * 1000);
        Sleep(10);
        if (!enabled) {
            continue;
        }
        _RPython_ThreadLocals_Acquire();
        tstate = _RPython_ThreadLocals_Head(); // the first one is one behind head
        tstate = _RPython_ThreadLocals_Enum(tstate);
        while (tstate) {
            if (tstate->ready == 42) {
                depth = vmprof_snapshot_thread(tstate->thread_ident, tstate, stack);
                if (depth > 0) {
                    vmp_write_all((char*)stack + offsetof(prof_stacktrace_s, marker),
                         depth * sizeof(void *) +
                         sizeof(struct prof_stacktrace_s) -
                         offsetof(struct prof_stacktrace_s, marker));
                }
            }
            tstate = _RPython_ThreadLocals_Enum(tstate);
        }
        _RPython_ThreadLocals_Release();
    }
#endif
#endif
}

RPY_EXTERN
int vmprof_enable(int memory, int native, int real_time)
{
    if (!thread_started) {
        if (!CreateThread(NULL, 0, vmprof_mainloop, NULL, 0, NULL)) {
            return -1;
        }
        thread_started = 1;
    }
    enabled = 1;
    return 0;
}

RPY_EXTERN
int vmprof_disable(void)
{
    char marker = MARKER_TRAILER;
    (void)vmp_write_time_now(MARKER_TRAILER);

    enabled = 0;
    vmp_set_profile_fileno(-1);
    return 0;
}

RPY_EXTERN
void vmprof_ignore_signals(int ignored)
{
    enabled = !ignored;
}

int vmp_native_enable(void)
{
    return 0;
}

void vmp_native_disable(void)
{
}

int get_stack_trace(PY_WIN_THREAD_STATE * current, void** result,
                    int max_depth, intptr_t pc)
{
    return 0;
}
