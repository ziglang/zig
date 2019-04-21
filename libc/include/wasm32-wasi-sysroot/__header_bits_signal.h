#ifndef __wasilibc___header_bits_signal_h
#define __wasilibc___header_bits_signal_h

#include <wasi/core.h>

#define SIGHUP    __WASI_SIGHUP
#define SIGINT    __WASI_SIGINT
#define SIGQUIT   __WASI_SIGQUIT
#define SIGILL    __WASI_SIGILL
#define SIGTRAP   __WASI_SIGTRAP
#define SIGABRT   __WASI_SIGABRT
#define SIGBUS    __WASI_SIGBUS
#define SIGFPE    __WASI_SIGFPE
#define SIGKILL   __WASI_SIGKILL
#define SIGUSR1   __WASI_SIGUSR1
#define SIGSEGV   __WASI_SIGSEGV
#define SIGUSR2   __WASI_SIGUSR2
#define SIGPIPE   __WASI_SIGPIPE
#define SIGALRM   __WASI_SIGALRM
#define SIGTERM   __WASI_SIGTERM
#define SIGCHLD   __WASI_SIGCHLD
#define SIGCONT   __WASI_SIGCONT
#define SIGSTOP   __WASI_SIGSTOP
#define SIGTSTP   __WASI_SIGTSTP
#define SIGTTIN   __WASI_SIGTTIN
#define SIGTTOU   __WASI_SIGTTOU
#define SIGURG    __WASI_SIGURG
#define SIGXCPU   __WASI_SIGXCPU
#define SIGXFSZ   __WASI_SIGXFSZ
#define SIGVTALRM __WASI_SIGVTALRM
#define SIGPROF   __WASI_SIGPROF
#define SIGWINCH  __WASI_SIGWINCH
#define SIGPOLL   __WASI_SIGPOLL
#define SIGPWR    __WASI_SIGPWR
#define SIGSYS    __WASI_SIGSYS

#define SIGIOT    SIGABRT
#define SIGIO     SIGPOLL
#define SIGUNUSED SIGSYS

#endif
