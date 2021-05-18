// Userspace emulation of `raise` and `signal`.
//
// WebAssembly doesn't support asynchronous signal delivery, so we can't
// support it in WASI libc. But we can make things like `raise` work.

#define _WASI_EMULATED_SIGNAL
#define _ALL_SOURCE
#define _GNU_SOURCE
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <assert.h>

void __SIG_IGN(int sig) {
    // do nothing
}

_Noreturn
void __SIG_ERR(int sig) {
    __builtin_trap();
}

_Noreturn
static void core_handler(int sig) {
    fprintf(stderr, "Program recieved fatal signal: %s\n", strsignal(sig));
    abort();
}

_Noreturn
static void terminate_handler(int sig) {
    fprintf(stderr, "Program recieved termination signal: %s\n", strsignal(sig));
    abort();
}

_Noreturn
static void stop_handler(int sig) {
    fprintf(stderr, "Program recieved stop signal: %s\n", strsignal(sig));
    abort();
}

static void continue_handler(int sig) {
    // do nothing
}

static const sighandler_t default_handlers[_NSIG] = {
    // Default behavior: "core".
    [SIGABRT] = core_handler,
    [SIGBUS] = core_handler,
    [SIGFPE] = core_handler,
    [SIGILL] = core_handler,
#if SIGIOT != SIGABRT
    [SIGIOT] = core_handler,
#endif
    [SIGQUIT] = core_handler,
    [SIGSEGV] = core_handler,
    [SIGSYS] = core_handler,
    [SIGTRAP] = core_handler,
    [SIGXCPU] = core_handler,
    [SIGXFSZ] = core_handler,
#if defined(SIGUNUSED) && SIGUNUSED != SIGSYS
    [SIGUNUSED] = core_handler,
#endif

    // Default behavior: ignore.
    [SIGCHLD] = SIG_IGN,
#if defined(SIGCLD) && SIGCLD != SIGCHLD
    [SIGCLD] = SIG_IGN,
#endif
    [SIGURG] = SIG_IGN,
    [SIGWINCH] = SIG_IGN,

    // Default behavior: "continue".
    [SIGCONT] = continue_handler,

    // Default behavior: "stop".
    [SIGSTOP] = stop_handler,
    [SIGTSTP] = stop_handler,
    [SIGTTIN] = stop_handler,
    [SIGTTOU] = stop_handler,

    // Default behavior: "terminate".
    [SIGHUP] = terminate_handler,
    [SIGINT] = terminate_handler,
    [SIGKILL] = terminate_handler,
    [SIGUSR1] = terminate_handler,
    [SIGUSR2] = terminate_handler,
    [SIGPIPE] = terminate_handler,
    [SIGALRM] = terminate_handler,
    [SIGTERM] = terminate_handler,
    [SIGSTKFLT] = terminate_handler,
    [SIGVTALRM] = terminate_handler,
    [SIGPROF] = terminate_handler,
    [SIGIO] = terminate_handler,
#if SIGPOLL != SIGIO
    [SIGPOLL] = terminate_handler,
#endif
    [SIGPWR] = terminate_handler,
};

static sighandler_t handlers[_NSIG];

int raise(int sig) {
    if (sig < 0 || sig >= _NSIG) {
        errno = EINVAL;
        return -1;
    }

    sighandler_t func = handlers[sig];

    if (func == NULL) {
        default_handlers[sig](sig);
    } else {
        func(sig);
    }

    return 0;
}

void (*signal(int sig, void (*func)(int)))(int) {
    assert(SIG_DFL == NULL);

    if (sig < 0 || sig >= _NSIG) {
        errno = EINVAL;
        return SIG_ERR;
    }

    if (sig == SIGKILL || sig == SIGSTOP) {
        errno = EINVAL;
        return SIG_ERR;
    }

    sighandler_t old = handlers[sig];

    handlers[sig] = func;

    return old;
}

extern __typeof(signal) bsd_signal __attribute__((weak, alias("signal")));
extern __typeof(signal) __sysv_signal __attribute__((weak, alias("signal")));
