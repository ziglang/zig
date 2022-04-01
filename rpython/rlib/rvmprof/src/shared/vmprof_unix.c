#include "vmprof_unix.h"

#ifdef VMPROF_UNIX

#if VMPROF_LINUX
#include <syscall.h>
#endif


#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>

#include "vmp_stack.h"
#include "vmprof_mt.h"
#include "vmprof_getpc.h"
#include "vmprof_common.h"
#include "vmprof_memory.h"
#include "compat.h"



/* value: LSB bit is 1 if signals must be ignored; all other bits
   are a counter for how many threads are currently in a signal handler */
static long volatile signal_handler_ignore = 1;
static long volatile signal_handler_entries = 0;
static char atfork_hook_installed = 0;
static volatile int spinlock;
static jmp_buf restore_point;
static struct profbuf_s *volatile current_codes;


void vmprof_ignore_signals(int ignored)
{
    if (ignored) {
        __sync_add_and_fetch(&signal_handler_ignore, 1L);
        while (signal_handler_entries != 0L) {
            usleep(1);
        }
    } else {
        __sync_sub_and_fetch(&signal_handler_ignore, 1L);
    }
}

long vmprof_enter_signal(void)
{
    __sync_fetch_and_add(&signal_handler_entries, 1L);
    return signal_handler_ignore;
}

long vmprof_exit_signal(void)
{
    return __sync_sub_and_fetch(&signal_handler_entries, 1L);
}

int install_pthread_atfork_hooks(void) {
    /* this is needed to prevent the problems described there:
         - http://code.google.com/p/gperftools/issues/detail?id=278
         - http://lists.debian.org/debian-glibc/2010/03/msg00161.html

        TL;DR: if the RSS of the process is large enough, the clone() syscall
        will be interrupted by the SIGPROF before it can complete, then
        retried, interrupted again and so on, in an endless loop.  The
        solution is to disable the timer around the fork, and re-enable it
        only inside the parent.
    */
    if (atfork_hook_installed)
        return 0;
    int ret = pthread_atfork(atfork_disable_timer, atfork_enable_timer, atfork_close_profile_file);
    if (ret != 0)
        return -1;
    atfork_hook_installed = 1;
    return 0;
}

void segfault_handler(int arg)
{
    longjmp(restore_point, SIGSEGV);
}

int _vmprof_sample_stack(struct profbuf_s *p, PY_THREAD_STATE_T * tstate, ucontext_t * uc)
{
    int depth;
    struct prof_stacktrace_s *st = (struct prof_stacktrace_s *)p->data;
    st->marker = MARKER_STACKTRACE;
    st->count = 1;
#ifdef RPYTHON_VMPROF
    depth = get_stack_trace(get_vmprof_stack(), st->stack, MAX_STACK_DEPTH-1, (intptr_t)GetPC(uc));
#else
    depth = get_stack_trace(tstate, st->stack, MAX_STACK_DEPTH-1, (intptr_t)NULL);
#endif
    // useful for tests (see test_stop_sampling)
#ifndef RPYTHON_LL2CTYPES
    if (depth == 0) {
        return 0;
    }
#endif
    st->depth = depth;
    st->stack[depth++] = tstate;
    long rss = get_current_proc_rss();
    if (rss >= 0)
        st->stack[depth++] = (void*)rss;
    p->data_offset = offsetof(struct prof_stacktrace_s, marker);
    p->data_size = (depth * sizeof(void *) +
                    sizeof(struct prof_stacktrace_s) -
                    offsetof(struct prof_stacktrace_s, marker));
    return 1;
}

#ifndef RPYTHON_VMPROF
PY_THREAD_STATE_T * _get_pystate_for_this_thread(void) {
    // see issue 116 on github.com/vmprof/vmprof-python.
    // PyGILState_GetThisThreadState(); can hang forever
    //
    PyInterpreterState * istate;
    PyThreadState * state;
    long mythread_id;

    mythread_id = PyThread_get_thread_ident();
    istate = PyInterpreterState_Head();
    if (istate == NULL) {
#if DEBUG
        fprintf(stderr, "WARNING: interp state head is null (for thread id %ld)\n", mythread_id);
#endif
        return NULL;
    }
    // fish fish fish, it will NOT lock the keymutex in pythread
    do {
        state = PyInterpreterState_ThreadHead(istate);
        do {
            if (state->thread_id == mythread_id) {
                return state;
            }
        } while ((state = PyThreadState_Next(state)) != NULL);
    } while ((istate = PyInterpreterState_Next(istate)) != NULL);

    // uh? not found?
#if DEBUG
    fprintf(stderr, "WARNING: cannot find thread state (for thread id %ld), sample will be thrown away\n", mythread_id);
#endif
    return NULL;
}
#endif

void flush_codes(void)
{
    struct profbuf_s *p = current_codes;
    if (p != NULL) {
        current_codes = NULL;
        commit_buffer(vmp_profile_fileno(), p);
    }
}

void set_current_codes(void * to) {
    current_codes = to;
}

#endif

void vmprof_aquire_lock(void) {
    while (__sync_lock_test_and_set(&spinlock, 1)) {
    }
}

void vmprof_release_lock(void) {
    __sync_lock_release(&spinlock);
}

void sigprof_handler(int sig_nr, siginfo_t* info, void *ucontext)
{
    int commit;
    PY_THREAD_STATE_T * tstate = NULL;
    void (*prevhandler)(int);

#ifndef RPYTHON_VMPROF

    // Even though the docs say that this function call is for 'esoteric use'
    // it seems to be correctly set when the interpreter is teared down!
    if (!Py_IsInitialized()) {
        return;
    }

    // TERRIBLE HACK AHEAD
    // on OS X, the thread local storage is sometimes uninitialized
    // when the signal handler runs - it means it's impossible to read errno
    // or call any syscall or read PyThread_Current or pthread_self. Additionally,
    // it seems impossible to read the register gs.
    // here we register segfault handler (all guarded by a spinlock) and call
    // longjmp in case segfault happens while reading a thread local
    //
    // We do the same error detection for linux to ensure that
    // get_current_thread_state returns a sane result
    while (__sync_lock_test_and_set(&spinlock, 1)) {
    }

#ifdef VMPROF_UNIX
    // SIGNAL ABUSE AHEAD
    // On linux, the prof timer will deliver the signal to the thread which triggered the timer,
    // because these timers are based on process and system time, and as such, are thread-aware.
    // For the real timer, the signal gets delivered to the main thread, seemingly always.
    // Consequently if we want to sample multiple threads, we need to forward this signal.
    if (vmprof_get_signal_type() == SIGALRM) {
        if (is_main_thread() && broadcast_signal_for_threads()) {
            __sync_lock_release(&spinlock);
            return;
        }
    }
#endif

    prevhandler = signal(SIGSEGV, &segfault_handler);
    int fault_code = setjmp(restore_point);
    if (fault_code == 0) {
        pthread_self();
        tstate = _get_pystate_for_this_thread();
    } else {
        signal(SIGSEGV, prevhandler);
        __sync_lock_release(&spinlock);
        return;
    }
    signal(SIGSEGV, prevhandler);
    __sync_lock_release(&spinlock);
#endif

    long val = vmprof_enter_signal();

    if (val == 0) {
        int saved_errno = errno;
        int fd = vmp_profile_fileno();
        assert(fd >= 0);

        struct profbuf_s *p = reserve_buffer(fd);
        if (p == NULL) {
            /* ignore this signal: there are no free buffers right now */
        } else {
#ifdef RPYTHON_VMPROF
            commit = _vmprof_sample_stack(p, NULL, (ucontext_t*)ucontext);
#else
            commit = _vmprof_sample_stack(p, tstate, (ucontext_t*)ucontext);
#endif
            if (commit) {
                commit_buffer(fd, p);
            } else {
#if DEBUG
                fprintf(stderr, "WARNING: canceled buffer, no stack trace was written\n");
#endif
                cancel_buffer(p);
            }
        }

        errno = saved_errno;
    }

    vmprof_exit_signal();
}

int install_sigprof_handler(void)
{
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = sigprof_handler;
    sa.sa_flags = SA_RESTART | SA_SIGINFO;
    if (sigemptyset(&sa.sa_mask) == -1 ||
        sigaction(vmprof_get_signal_type(), &sa, NULL) == -1)
        return -1;
    return 0;
}

int remove_sigprof_handler(void)
{
    struct sigaction ign_sigint, prev;
    ign_sigint.sa_handler = SIG_IGN;
    ign_sigint.sa_flags = 0;
    sigemptyset(&ign_sigint.sa_mask);

    if (sigaction(vmprof_get_signal_type(), &ign_sigint, NULL) < 0) {
        fprintf(stderr, "Could not remove the signal handler (for profiling)\n");
        return -1;
    }
    return 0;
}

int install_sigprof_timer(void)
{
    static struct itimerval timer;
    timer.it_interval.tv_sec = 0;
    timer.it_interval.tv_usec = (int)vmprof_get_profile_interval_usec();
    timer.it_value = timer.it_interval;
    if (setitimer(vmprof_get_itimer_type(), &timer, NULL) != 0)
        return -1;
    return 0;
}

int remove_sigprof_timer(void)
{
    static struct itimerval timer;
    timerclear(&(timer.it_interval));
    timerclear(&(timer.it_value));
    if (setitimer(vmprof_get_itimer_type(), &timer, NULL) != 0) {
        fprintf(stderr, "Could not disable the signal handler (for profiling)\n");
        return -1;
    }
    return 0;
}

void atfork_disable_timer(void)
{
    if (vmprof_get_profile_interval_usec() > 0) {
        remove_sigprof_timer();
        vmprof_set_enabled(0);
    }
}

void atfork_close_profile_file(void)
{
    int fd = vmp_profile_fileno();
    if (fd != -1)
        close(fd);
    vmp_set_profile_fileno(-1);
}
void atfork_enable_timer(void)
{
    if (vmprof_get_profile_interval_usec() > 0) {
        install_sigprof_timer();
        vmprof_set_enabled(1);
    }
}

#ifdef VMP_SUPPORTS_NATIVE_PROFILING
void init_cpyprof(int native)
{
    // skip this if native should not be enabled
    if (!native) {
        vmp_native_disable();
        return;
    }
    vmp_native_enable();
}

static void disable_cpyprof(void)
{
    vmp_native_disable();
}
#endif

int vmprof_enable(int memory, int native, int real_time)
{
#ifdef VMP_SUPPORTS_NATIVE_PROFILING
    init_cpyprof(native);
#endif
    assert(vmp_profile_fileno() >= 0);
    assert(vmprof_get_prepare_interval_usec() > 0);
    vmprof_set_profile_interval_usec(vmprof_get_prepare_interval_usec());
    if (memory && setup_rss() == -1)
        goto error;
#if VMPROF_UNIX
    if (real_time && insert_thread(pthread_self(), -1) == -1)
        goto error;
#endif
    if (install_pthread_atfork_hooks() == -1)
        goto error;
    if (install_sigprof_handler() == -1)
        goto error;
    if (install_sigprof_timer() == -1)
        goto error;
    signal_handler_ignore = 0;
    return 0;

 error:
    vmp_set_profile_fileno(-1);
    vmprof_set_profile_interval_usec(0);
    return -1;
}


int close_profile(void)
{
    int fileno = vmp_profile_fileno();
    fsync(fileno);
    (void)vmp_write_time_now(MARKER_TRAILER);
    teardown_rss();

    /* don't close() the file descriptor from here */
    vmp_set_profile_fileno(-1);
    return 0;
}

int vmprof_disable(void)
{
    signal_handler_ignore = 1;
    vmprof_set_profile_interval_usec(0);
#ifdef VMP_SUPPORTS_NATIVE_PROFILING
    disable_cpyprof();
#endif

    if (remove_sigprof_timer() == -1) {
        return -1;
    }
    if (remove_sigprof_handler() == -1) {
        return -1;
    }
#ifdef VMPROF_UNIX
    if ((vmprof_get_signal_type() == SIGALRM) && remove_threads() == -1) {
        return -1;
    }
#endif
    flush_codes();
    if (shutdown_concurrent_bufs(vmp_profile_fileno()) < 0)
        return -1;
    return close_profile();
}

int vmprof_register_virtual_function(char *code_name, intptr_t code_uid,
                                     int auto_retry)
{
    long namelen = strnlen(code_name, 1023);
    long blocklen = 1 + sizeof(intptr_t) + sizeof(long) + namelen;
    struct profbuf_s *p;
    char *t;

 retry:
    p = current_codes;
    if (p != NULL) {
        if (__sync_bool_compare_and_swap(&current_codes, p, NULL)) {
            /* grabbed 'current_codes': we will append the current block
               to it if it contains enough room */
            size_t freesize = SINGLE_BUF_SIZE - p->data_size;
            if (freesize < (size_t)blocklen) {
                /* full: flush it */
                commit_buffer(vmp_profile_fileno(), p);
                p = NULL;
            }
        }
        else {
            /* compare-and-swap failed, don't try again */
            p = NULL;
        }
    }

    if (p == NULL) {
        p = reserve_buffer(vmp_profile_fileno());
        if (p == NULL) {
            /* can't get a free block; should almost never be the
               case.  Spin loop if allowed, or return a failure code
               if not (e.g. we're in a signal handler) */
            if (auto_retry > 0) {
                auto_retry--;
                usleep(1);
                goto retry;
            }
            return -1;
        }
    }

    t = p->data + p->data_size;
    p->data_size += blocklen;
    assert(p->data_size <= SINGLE_BUF_SIZE);
    *t++ = MARKER_VIRTUAL_IP;
    memcpy(t, &code_uid, sizeof(intptr_t)); t += sizeof(intptr_t);
    memcpy(t, &namelen, sizeof(long)); t += sizeof(long);
    memcpy(t, code_name, namelen);

    /* try to reattach 'p' to 'current_codes' */
    if (!__sync_bool_compare_and_swap(&current_codes, NULL, p)) {
        /* failed, flush it */
        commit_buffer(vmp_profile_fileno(), p);
    }
    return 0;
}

int get_stack_trace(PY_THREAD_STATE_T * current, void** result, int max_depth, intptr_t pc)
{
    PY_STACK_FRAME_T * frame;
#ifdef RPYTHON_VMPROF
    // do nothing here,
    frame = (PY_STACK_FRAME_T*)current;
#else
    if (current == NULL) {
#if DEBUG
        fprintf(stderr, "WARNING: get_stack_trace, current is NULL\n");
#endif
        return 0;
    }
    frame = current->frame;
#endif
    if (frame == NULL) {
#if DEBUG
        fprintf(stderr, "WARNING: get_stack_trace, frame is NULL\n");
#endif
        return 0;
    }
    return vmp_walk_and_record_stack(frame, result, max_depth, 1, pc);
}
