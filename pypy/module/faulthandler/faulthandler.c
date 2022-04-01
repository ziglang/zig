#include "faulthandler.h"
#include <stdlib.h>
#include <stdio.h>
#include <signal.h>
#include <assert.h>
#include <errno.h>
#include <string.h>
#ifndef _WIN32
#include <unistd.h>
#include <sys/resource.h>
#endif
#include <math.h>

#ifdef RPYTHON_LL2CTYPES
#  include "../../../rpython/rlib/rvmprof/src/rvmprof.h"
#else
#  include "common_header.h"
#  include "structdef.h"
#  include "rvmprof.h"
#endif
#include "src/threadlocal.h"

#define MAX_FRAME_DEPTH   100
#define FRAME_DEPTH_N     RVMPROF_TRACEBACK_ESTIMATE_N(MAX_FRAME_DEPTH)

#ifndef _WIN32
#define HAVE_SIGACTION 1
#define HAVE_SIGALTSTACK 1
#endif

#ifdef HAVE_SIGACTION
typedef struct sigaction _Py_sighandler_t;
#else
typedef void (*_Py_sighandler_t)(int);
#endif

typedef struct {
    const int signum;
    volatile int enabled;
    const char* name;
    _Py_sighandler_t previous;
} fault_handler_t;

static struct {
    int initialized;
    int enabled;
    volatile int fd, all_threads;
    volatile pypy_faulthandler_cb_t dump_traceback;
} fatal_error;

#ifdef HAVE_SIGALTSTACK
static stack_t stack;
#endif


static fault_handler_t faulthandler_handlers[] = {
#ifdef SIGBUS
    {SIGBUS, 0, "Bus error", },
#endif
#ifdef SIGILL
    {SIGILL, 0, "Illegal instruction", },
#endif
    {SIGFPE, 0, "Floating point exception", },
    {SIGABRT, 0, "Aborted", },
    /* define SIGSEGV at the end to make it the default choice if searching the
       handler fails in faulthandler_fatal_error() */
    {SIGSEGV, 0, "Segmentation fault", }
};
static const int faulthandler_nsignals =
    sizeof(faulthandler_handlers) / sizeof(fault_handler_t);

RPY_EXTERN
void pypy_faulthandler_write(int fd, const char *str)
{
    ssize_t n, count;
    count = 0;
    while (str[count] != 0)
        count++;

    while (count > 0) {
        n = write(fd, str, count);
        if (n < 0) {
            if (errno != EINTR)
                return;   /* give up */
            n = 0;
        }
        str += n;
        count -= n;
    }
}

RPY_EXTERN
void pypy_faulthandler_write_uint(int fd, unsigned long uvalue, int min_digits)
{
    char buf[48], *p = buf + 48;
    *--p = 0;
    while (uvalue || min_digits > 0) {
        assert(p > buf);
        *--p = '0' + (uvalue % 10UL);
        uvalue /= 10UL;
        min_digits--;
    }

    pypy_faulthandler_write(fd, p);
}

static void pypy_faulthandler_write_hex(int fd, Unsigned uvalue)
{
    char buf[48], *p = buf + 48;
    *--p = 0;
    do {
        Unsigned byte = uvalue % 16UL;
        assert(p > buf);
        if (byte < 10)
            *--p = '0' + byte;
        else
            *--p = 'A' + byte - 10;
        uvalue /= 16UL;
    } while (uvalue > 0UL);

    pypy_faulthandler_write(fd, p);
}


RPY_EXTERN
void pypy_faulthandler_dump_traceback(int fd, int all_threads,
                                      void *ucontext)
{
    pypy_faulthandler_cb_t fn;
    intptr_t array_p[FRAME_DEPTH_N], array_length;

    fn = fatal_error.dump_traceback;
    if (!fn)
        return;

#ifndef RPYTHON_LL2CTYPES
    if (all_threads && _RPython_ThreadLocals_AcquireTimeout(10000) == 0) {
        /* This is known not to be perfectly safe against segfaults if we
           don't hold the GIL ourselves.  Too bad.  I suspect that CPython
           has issues there too.
        */
        struct pypy_threadlocal_s *my, *p;
        int blankline = 0;

        my = (struct pypy_threadlocal_s *)_RPy_ThreadLocals_Get();
        p = _RPython_ThreadLocals_Head();
        p = _RPython_ThreadLocals_Enum(p);
        while (p != NULL) {
            if (blankline)
                pypy_faulthandler_write(fd, "\n");
            blankline = 1;

            pypy_faulthandler_write(fd, my == p ? "Current thread 0x"
                                                : "Thread 0x");
            pypy_faulthandler_write_hex(fd, (Unsigned)p->thread_ident);
            pypy_faulthandler_write(fd, " (most recent call first,"
                                        " approximate line numbers):\n");

            array_length = vmprof_get_traceback(p->vmprof_tl_stack,
                                                my == p ? ucontext : NULL,
                                                array_p, FRAME_DEPTH_N);
            fn(fd, array_p, array_length);

            p = _RPython_ThreadLocals_Enum(p);
        }
        _RPython_ThreadLocals_Release();
    }
    else {
        pypy_faulthandler_write(fd, "Stack (most recent call first,"
                                    " approximate line numbers):\n");
        array_length = vmprof_get_traceback(NULL, ucontext,
                                            array_p, FRAME_DEPTH_N);
        fn(fd, array_p, array_length);
    }
#else
    pypy_faulthandler_write(fd, "(no traceback when untranslated)\n");
#endif
}

static void
faulthandler_dump_traceback(int fd, int all_threads, void *ucontext)
{
    static volatile int reentrant = 0;

    if (reentrant)
        return;
    reentrant = 1;
    pypy_faulthandler_dump_traceback(fd, all_threads, ucontext);
    reentrant = 0;
}


/************************************************************/


#ifdef PYPY_FAULTHANDLER_LATER
#include "src/thread.h"
static struct {
    int fd;
    long long microseconds;
    int repeat, exit;
    /* The main thread always holds this lock. It is only released when
       faulthandler_thread() is interrupted before this thread exits, or at
       Python exit. */
    struct RPyOpaque_ThreadLock cancel_event;
    /* released by child thread when joined */
    struct RPyOpaque_ThreadLock running;
} thread_later;

static void faulthandler_thread(void)
{
#ifndef _WIN32
    /* we don't want to receive any signal */
    sigset_t set;
    sigfillset(&set);
    pthread_sigmask(SIG_SETMASK, &set, NULL);
#endif

    RPyLockStatus st;
    unsigned long hours, minutes, seconds, fraction;
    long long t;
    int fd;

    do {
        st = RPyThreadAcquireLockTimed(&thread_later.cancel_event,
                                       thread_later.microseconds, 0);
        if (st == RPY_LOCK_ACQUIRED) {
            RPyThreadReleaseLock(&thread_later.cancel_event);
            break;
        }
        /* Timeout => dump traceback */
        assert(st == RPY_LOCK_FAILURE);

        /* getting to know which thread holds the GIL is not as simple
         * as in CPython, so for now we don't */

        t = thread_later.microseconds;
        fraction = (unsigned long)(t % 1000000);
        t /= 1000000;
        seconds = (unsigned long)(t % 60);
        t /= 60;
        minutes = (unsigned long)(t % 60);
        t /= 60;
        hours = (unsigned long)t;

        fd = thread_later.fd;
        pypy_faulthandler_write(fd, "Timeout (");
        pypy_faulthandler_write_uint(fd, hours, 1);
        pypy_faulthandler_write(fd, ":");
        pypy_faulthandler_write_uint(fd, minutes, 2);
        pypy_faulthandler_write(fd, ":");
        pypy_faulthandler_write_uint(fd, seconds, 2);
        if (fraction != 0) {
            pypy_faulthandler_write(fd, ".");
            pypy_faulthandler_write_uint(fd, fraction, 6);
        }
        pypy_faulthandler_write(fd, ")!\n");
        pypy_faulthandler_dump_traceback(fd, 1, NULL);

        if (thread_later.exit)
            _exit(1);
    } while (thread_later.repeat);

    /* The only way out */
    RPyThreadReleaseLock(&thread_later.running);
}

RPY_EXTERN
char *pypy_faulthandler_dump_traceback_later(long long microseconds, int repeat,
                                             int fd, int exit)
{
    pypy_faulthandler_cancel_dump_traceback_later();

    thread_later.fd = fd;
    thread_later.microseconds = microseconds;
    thread_later.repeat = repeat;
    thread_later.exit = exit;

    RPyThreadAcquireLock(&thread_later.running, 1);

    if (RPyThreadStart(&faulthandler_thread) == -1) {
        RPyThreadReleaseLock(&thread_later.running);
        return "unable to start watchdog thread";
    }
    return NULL;
}
#endif   /* PYPY_FAULTHANDLER_LATER */

RPY_EXTERN
void pypy_faulthandler_cancel_dump_traceback_later(void)
{
#ifdef PYPY_FAULTHANDLER_LATER
    /* Notify cancellation */
    RPyThreadReleaseLock(&thread_later.cancel_event);

    /* Wait for thread to join (or does nothing if no thread is running) */
    RPyThreadAcquireLock(&thread_later.running, 1);
    RPyThreadReleaseLock(&thread_later.running);

    /* The main thread should always hold the cancel_event lock */
    RPyThreadAcquireLock(&thread_later.cancel_event, 1);
#endif   /* PYPY_FAULTHANDLER_LATER */
}


/************************************************************/


#ifdef PYPY_FAULTHANDLER_USER
typedef struct {
    int enabled;
    int fd;
    int all_threads;
    int chain;
    _Py_sighandler_t previous;
} user_signal_t;

static user_signal_t *user_signals;

#ifndef NSIG
# if defined(_NSIG)
#  define NSIG _NSIG            /* For BSD/SysV */
# elif defined(_SIGMAX)
#  define NSIG (_SIGMAX + 1)    /* For QNX */
# elif defined(SIGMAX)
#  define NSIG (SIGMAX + 1)     /* For djgpp */
# else
#  define NSIG 64               /* Use a reasonable default value */
# endif
#endif

#ifdef HAVE_SIGACTION
static void faulthandler_user(int signum, siginfo_t *info, void *ucontext);
#else
static void faulthandler_user(int signum);
#endif

static int
faulthandler_register(int signum, int chain, _Py_sighandler_t *p_previous)
{
#ifdef HAVE_SIGACTION
    struct sigaction action;
    action.sa_sigaction = faulthandler_user;
    sigemptyset(&action.sa_mask);
    /* if the signal is received while the kernel is executing a system
       call, try to restart the system call instead of interrupting it and
       return EINTR. */
    action.sa_flags = SA_RESTART | SA_SIGINFO;
    if (chain) {
        /* do not prevent the signal from being received from within its
           own signal handler */
        action.sa_flags = SA_NODEFER;
    }
    if (stack.ss_sp != NULL) {
        /* Call the signal handler on an alternate signal stack
           provided by sigaltstack() */
        action.sa_flags |= SA_ONSTACK;
    }
    return sigaction(signum, &action, p_previous);
#else
    _Py_sighandler_t previous;
    previous = signal(signum, faulthandler_user);
    if (p_previous != NULL)
        *p_previous = previous;
    return (previous == SIG_ERR);
#endif
}

#ifdef HAVE_SIGACTION
static void faulthandler_user(int signum, siginfo_t *info, void *ucontext)
{
#else
static void faulthandler_user(int signum)
{
    void *ucontext = NULL;
#endif
    int save_errno;
    user_signal_t *user = &user_signals[signum];

    if (!user->enabled)
        return;

    save_errno = errno;
    faulthandler_dump_traceback(user->fd, user->all_threads, ucontext);

#ifdef HAVE_SIGACTION
    if (user->chain) {
        (void)sigaction(signum, &user->previous, NULL);
        errno = save_errno;

        /* call the previous signal handler */
        raise(signum);

        save_errno = errno;
        (void)faulthandler_register(signum, user->chain, NULL);
    }

    errno = save_errno;
#else
    if (user->chain) {
        errno = save_errno;
        /* call the previous signal handler */
        user->previous(signum);
    }
#endif
}

RPY_EXTERN
int pypy_faulthandler_check_signum(long signum)
{
    unsigned int i;

    for (i = 0; i < faulthandler_nsignals; i++) {
        if (faulthandler_handlers[i].signum == signum) {
            return -1;
        }
    }
    if (signum < 1 || NSIG <= signum) {
        return -2;
    }
    return 0;
}

RPY_EXTERN
char *pypy_faulthandler_register(int signum, int fd, int all_threads, int chain)
{
    user_signal_t *user;
    _Py_sighandler_t previous;
    int err;

    if (user_signals == NULL) {
        user_signals = malloc(NSIG * sizeof(user_signal_t));
        if (user_signals == NULL)
            return "out of memory";
        memset(user_signals, 0, NSIG * sizeof(user_signal_t));
    }

    user = &user_signals[signum];
    user->fd = fd;
    user->all_threads = all_threads;
    user->chain = chain;

    if (!user->enabled) {
        err = faulthandler_register(signum, chain, &previous);
        if (err)
            return strerror(errno);

        user->previous = previous;
        user->enabled = 1;
    }
    return NULL;
}

RPY_EXTERN
int pypy_faulthandler_unregister(int signum)
{
    user_signal_t *user;

    if (user_signals == NULL)
        return 0;

    user = &user_signals[signum];
    if (user->enabled) {
        user->enabled = 0;
        (void)sigaction(signum, &user->previous, NULL);
        user->fd = -1;
        return 1;
    }
    else
        return 0;
}
#endif   /* PYPY_FAULTHANDLER_USER */


/************************************************************/


/* Handler for SIGSEGV, SIGFPE, SIGABRT, SIGBUS and SIGILL signals.

   Display the current Python traceback, restore the previous handler and call
   the previous handler.

   On Windows, don't explicitly call the previous handler, because the Windows
   signal handler would not be called (for an unknown reason). The execution of
   the program continues at faulthandler_fatal_error() exit, but the same
   instruction will raise the same fault (signal), and so the previous handler
   will be called.

   This function is signal-safe and should only call signal-safe functions. */

static void
#ifdef HAVE_SIGACTION
faulthandler_fatal_error(int signum, siginfo_t *info, void *ucontext)
{
#else
faulthandler_fatal_error(int signum)
{
    void *ucontext = NULL;
#endif
    int fd = fatal_error.fd;
    int i;
    fault_handler_t *handler = NULL;
    int save_errno = errno;

    for (i = 0; i < faulthandler_nsignals; i++) {
        handler = &faulthandler_handlers[i];
        if (handler->signum == signum)
            break;
    }
    /* If not found, we use the SIGSEGV handler (the last one in the list) */

    /* restore the previous handler */
    if (handler->enabled) {
#ifdef HAVE_SIGACTION
        (void)sigaction(signum, &handler->previous, NULL);
#else
        (void)signal(signum, handler->previous);
#endif
        handler->enabled = 0;
    }

    pypy_faulthandler_write(fd, "Fatal Python error: ");
    pypy_faulthandler_write(fd, handler->name);
    pypy_faulthandler_write(fd, "\n\n");

    faulthandler_dump_traceback(fd, fatal_error.all_threads, ucontext);

    errno = save_errno;
#ifdef _WIN32
    if (signum == SIGSEGV) {
        /* don't explicitly call the previous handler for SIGSEGV in this signal
           handler, because the Windows signal handler would not be called */
        return;
    }
#endif
    /* call the previous signal handler: it is called immediately if we use
       sigaction() thanks to SA_NODEFER flag, otherwise it is deferred */
    raise(signum);
}


RPY_EXTERN
char *pypy_faulthandler_setup(pypy_faulthandler_cb_t dump_callback)
{
    if (fatal_error.initialized)
        return NULL;
    assert(!fatal_error.enabled);
    fatal_error.dump_traceback = dump_callback;

#ifdef HAVE_SIGALTSTACK
    /* Try to allocate an alternate stack for faulthandler() signal handler to
     * be able to allocate memory on the stack, even on a stack overflow. If it
     * fails, ignore the error. */
    stack.ss_flags = 0;
    stack.ss_size = SIGSTKSZ;
    stack.ss_sp = malloc(stack.ss_size);
    if (stack.ss_sp != NULL) {
        int err = sigaltstack(&stack, NULL);
        if (err) {
            free(stack.ss_sp);
            stack.ss_sp = NULL;
        }
    }
#endif

#ifdef PYPY_FAULTHANDLER_LATER
    if (!RPyThreadLockInit(&thread_later.cancel_event) ||
        !RPyThreadLockInit(&thread_later.running))
        return "failed to initialize locks";
    RPyThreadAcquireLock(&thread_later.cancel_event, 1);
#endif

    fatal_error.fd = -1;
    fatal_error.initialized = 1;

    return NULL;
}

RPY_EXTERN
void pypy_faulthandler_teardown(void)
{
    if (fatal_error.initialized) {

#ifdef PYPY_FAULTHANDLER_LATER
        pypy_faulthandler_cancel_dump_traceback_later();
        RPyThreadReleaseLock(&thread_later.cancel_event);
        RPyOpaqueDealloc_ThreadLock(&thread_later.running);
        RPyOpaqueDealloc_ThreadLock(&thread_later.cancel_event);
#endif

#ifdef PYPY_FAULTHANDLER_USER
        int signum;
        for (signum = 0; signum < NSIG; signum++)
            pypy_faulthandler_unregister(signum);
        /* don't free 'user_signals', the gain is very minor and it can
           lead to rare crashes if another thread is still busy */
#endif

        pypy_faulthandler_disable();
        fatal_error.initialized = 0;
#ifdef HAVE_SIGALTSTACK
        if (stack.ss_sp) {
            stack.ss_flags = SS_DISABLE;
            sigaltstack(&stack, NULL);
            free(stack.ss_sp);
            stack.ss_sp = NULL;
        }
#endif
    }
}

RPY_EXTERN
char *pypy_faulthandler_enable(int fd, int all_threads)
{
    /* Install the handler for fatal signals, faulthandler_fatal_error(). */
    int i;
    fatal_error.fd = fd;
    fatal_error.all_threads = all_threads;

    if (!fatal_error.enabled) {
        fatal_error.enabled = 1;

        for (i = 0; i < faulthandler_nsignals; i++) {
            int err;
            fault_handler_t *handler = &faulthandler_handlers[i];
#ifdef HAVE_SIGACTION
            struct sigaction action;
            action.sa_sigaction = faulthandler_fatal_error;
            sigemptyset(&action.sa_mask);
            /* Do not prevent the signal from being received from within
               its own signal handler */
            action.sa_flags = SA_NODEFER | SA_SIGINFO;
            if (stack.ss_sp != NULL) {
                /* Call the signal handler on an alternate signal stack
                   provided by sigaltstack() */
                action.sa_flags |= SA_ONSTACK;
            }
            err = sigaction(handler->signum, &action, &handler->previous);
#else
            handler->previous = signal(handler->signum,
                                       faulthandler_fatal_error);
            err = (handler->previous == SIG_ERR);
#endif
            if (err) {
                return strerror(errno);
            }
            handler->enabled = 1;
        }
    }
    return NULL;
}

RPY_EXTERN
void pypy_faulthandler_disable(void)
{
    int i;
    if (fatal_error.enabled) {
        fatal_error.enabled = 0;
        for (i = 0; i < faulthandler_nsignals; i++) {
            fault_handler_t *handler = &faulthandler_handlers[i];
            if (!handler->enabled)
                continue;
#ifdef HAVE_SIGACTION
            (void)sigaction(handler->signum, &handler->previous, NULL);
#else
            (void)signal(handler->signum, handler->previous);
#endif
            handler->enabled = 0;
        }
    }
    fatal_error.fd = -1;
}

RPY_EXTERN
int pypy_faulthandler_is_enabled(void)
{
    return fatal_error.enabled;
}


/************************************************************/


/* for tests... */

static void
faulthandler_suppress_crash_report(void)
{
#ifdef _WIN32
    UINT mode;

    /* Configure Windows to not display the Windows Error Reporting dialog */
    mode = SetErrorMode(SEM_NOGPFAULTERRORBOX);
    SetErrorMode(mode | SEM_NOGPFAULTERRORBOX);
#endif

#ifndef _WIN32
    struct rlimit rl;

    /* Disable creation of core dump */
    if (getrlimit(RLIMIT_CORE, &rl) != 0) {
        rl.rlim_cur = 0;
        setrlimit(RLIMIT_CORE, &rl);
    }
#endif

#ifdef _MSC_VER
    /* Visual Studio: configure abort() to not display an error message nor
       open a popup asking to report the fault. */
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif
}

RPY_EXTERN
int pypy_faulthandler_read_null(void)
{
    int *volatile x;

    faulthandler_suppress_crash_report();
    x = NULL;
    return *x;
}

RPY_EXTERN
void pypy_faulthandler_sigsegv(void)
{
    faulthandler_suppress_crash_report();
#ifdef _WIN32
    /* For SIGSEGV, faulthandler_fatal_error() restores the previous signal
       handler and then gives back the execution flow to the program (without
       explicitly calling the previous error handler). In a normal case, the
       SIGSEGV was raised by the kernel because of a fault, and so if the
       program retries to execute the same instruction, the fault will be
       raised again.

       Here the fault is simulated by a fake SIGSEGV signal raised by the
       application. We have to raise SIGSEGV at lease twice: once for
       faulthandler_fatal_error(), and one more time for the previous signal
       handler. */
    while(1)
        raise(SIGSEGV);
#else
    raise(SIGSEGV);
#endif
}

RPY_EXTERN
int pypy_faulthandler_sigfpe(void)
{
    /* Do an integer division by zero: raise a SIGFPE on Intel CPU, but not on
       PowerPC. Use volatile to disable compile-time optimizations. */
    volatile int x = 1, y = 0, z;
    faulthandler_suppress_crash_report();
    z = x / y;
    /* If the division by zero didn't raise a SIGFPE (e.g. on PowerPC),
       raise it manually. */
    raise(SIGFPE);
    /* This line is never reached, but we pretend to make something with z
       to silence a compiler warning. */
    return z;
}

RPY_EXTERN
void pypy_faulthandler_sigabrt(void)
{
    faulthandler_suppress_crash_report();
    abort();
}

static double fh_stack_overflow(double levels)
{
    if (levels > 2.5) {
        return (sqrt(fh_stack_overflow(levels - 1.0))
                + fh_stack_overflow(levels * 1e-10));
    }
    return 1e100 + levels;
}

RPY_EXTERN
double pypy_faulthandler_stackoverflow(double levels)
{
    faulthandler_suppress_crash_report();
    return fh_stack_overflow(levels);
}
