#include "src/signals.h"

#include <limits.h>
#include <stdlib.h>
#include <errno.h>
#ifdef _WIN32
#include <process.h>
#include <io.h>
#include <winsock2.h>
#pragma comment(lib,"ws2_32.lib")   /* for getsockopt() and send() */
#else
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#endif
#include <signal.h>


/* some ifdefs from CPython's signalmodule.c... */

#if defined(PYOS_OS2) && !defined(PYCC_GCC)
#define NSIG 12
#include <process.h>
#endif

#ifndef NSIG
# if defined(_NSIG)
#  define NSIG _NSIG		/* For BSD/SysV */
# elif defined(_SIGMAX)
#  define NSIG (_SIGMAX + 1)	/* For QNX */
# elif defined(SIGMAX)
#  define NSIG (SIGMAX + 1)	/* For djgpp */
# else
#  define NSIG 64		/* Use a reasonable default value */
# endif
#endif

#define N_LONGBITS  (8 * sizeof(long))
#define N_LONGSIG   ((NSIG - 1) / N_LONGBITS + 1)

#define PYPYSIG_WITH_NUL_BYTE   0x01
#define PYPYSIG_USE_SEND        0x02
#define PYPYSIG_NO_WARN_FULL    0x04

struct pypysig_long_struct pypysig_counter = {0};
static long volatile pypysig_flags_bits[N_LONGSIG];
static int wakeup_fd = -1;
static int wakeup_send_flags = PYPYSIG_WITH_NUL_BYTE;

#undef pypysig_getaddr_occurred
void *pypysig_getaddr_occurred(void)
{
    return (void *)(&pypysig_counter); 
}

void pypysig_ignore(int signum)
{
#ifdef SA_RESTART
    /* assume sigaction exists */
    struct sigaction context;
    context.sa_handler = SIG_IGN;
    sigemptyset(&context.sa_mask);
    context.sa_flags = 0;
    sigaction(signum, &context, NULL);
#else
    signal(signum, SIG_IGN);
#endif
}

void pypysig_default(int signum)
{
#ifdef SA_RESTART
    /* assume sigaction exists */
    struct sigaction context;
    context.sa_handler = SIG_DFL;
    sigemptyset(&context.sa_mask);
    context.sa_flags = 0;
    sigaction(signum, &context, NULL);
#else
    signal(signum, SIG_DFL);
#endif
}

#ifdef _WIN32
#include <Windows.h>
#define atomic_cas(ptr, oldv, newv)   (InterlockedCompareExchange(ptr, \
                                            newv, oldv) == (oldv))
#else
#define atomic_cas(ptr, oldv, newv)    __sync_bool_compare_and_swap(ptr, \
                                            oldv, newv)
#endif

void pypysig_pushback(int signum)
{
    if (0 <= signum && signum < NSIG)
      {
        int ok, index = signum / N_LONGBITS;
        unsigned long bitmask = 1UL << (signum % N_LONGBITS);
        do
        {
            long value = pypysig_flags_bits[index];
            if (value & bitmask)
                break;   /* already set */
            ok = atomic_cas(&pypysig_flags_bits[index], value, value | bitmask);
        } while (!ok);

        pypysig_counter.value = -1;
      }
}

static void write_str(int fd, const char *p)
{
    int i = 0;
    int res RPY_UNUSED;
    while (p[i] != '\x00')
        i++;
    res = write(fd, p, i);
}

#ifdef _WIN32
/* this is set manually from pypy3's module/time/interp_time */
HANDLE pypy_sigint_interrupt_event = NULL;
#endif

static void signal_setflag_handler(int signum)
{
    pypysig_pushback(signum);

    /* Warning, this logic needs to be async-signal-safe */
    if (wakeup_fd != -1) {
#ifndef _WIN32
        ssize_t res;
#else
        int res;
#endif
        int old_errno = errno;
        unsigned char byte = (unsigned char)signum;
        if (wakeup_send_flags & PYPYSIG_WITH_NUL_BYTE)
            byte = 0;
     retry:
        if (wakeup_send_flags & PYPYSIG_USE_SEND)
            res = send(wakeup_fd, &byte, 1, 0);
        else
            res = write(wakeup_fd, &byte, 1);
        if (res < 0 && ((wakeup_send_flags & PYPYSIG_NO_WARN_FULL) == 0 ||
                        errno != EAGAIN)) {
            unsigned int e = (unsigned int)errno;
            char c[27], *p;
            if (e == EINTR)
                goto retry;
            write_str(2, "Exception ignored when trying to write to the "
                         "signal wakeup fd: Errno ");
            p = c + sizeof(c);
            *--p = 0;
            *--p = '\n';
            do {
                *--p = '0' + e % 10;
                e /= 10;
            } while (e != 0);
            write_str(2, p);
        }
        errno = old_errno;
    }

#ifdef _WIN32
    if (signum == SIGINT && pypy_sigint_interrupt_event)
        SetEvent(pypy_sigint_interrupt_event);
#endif
}

void pypysig_setflag(int signum)
{
#ifdef SA_RESTART
    /* assume sigaction exists */
    struct sigaction context;
    context.sa_handler = signal_setflag_handler;
    sigemptyset(&context.sa_mask);
    context.sa_flags = 0;
    sigaction(signum, &context, NULL);
#else
    signal(signum, signal_setflag_handler);
#endif
}

void pypysig_reinstall(int signum)
{
#ifdef SA_RESTART
    /* Assume sigaction was used.  We did not pass SA_RESETHAND to
       sa_flags, so there is nothing to do here. */
#else
# ifdef SIGCHLD
    /* To avoid infinite recursion, this signal remains
       reset until explicitly re-instated.  (Copied from CPython) */
    if (signum != SIGCHLD)
# endif
    pypysig_setflag(signum);
#endif
}

int pypysig_poll(void)
{
    int index;
    for (index = 0; index < N_LONGSIG; index++) {
        long value;
      retry:
        value = pypysig_flags_bits[index];
        if (value != 0L) {
            int j = 0;
            while ((value & (1UL << j)) == 0)
                j++;
            if (!atomic_cas(&pypysig_flags_bits[index], value,
                            value & ~(1UL << j)))
                goto retry;
            return index * N_LONGBITS + j;
        }
    }
    return -1;  /* no pending signal */
}

int pypysig_set_wakeup_fd(int fd, int send_flags)
{
  int old_fd = wakeup_fd;
#ifdef _WIN32
  /* check if 'fd' seems to be a socket handle instead of a file handle.
     The call to getsockopt() can fail for a number of reasons, starting
     from WSAStartup() never called.  CPython is more careful about
     distinguishing error cases.  We just assume that a failure means
     that the fd is not a socket descriptor but a file descriptor.

     Win64 note: in theory, socket descriptors could be 64-bit there,
     but in practice they always fit in 32-bit so it shouldn't really
     be a problem according to:
             https://stackoverflow.com/questions/1953639/
             is-it-safe-to-cast-socket-to-int-under-win64
     */
  if (fd != -1) {
    int res;
    int res_size = sizeof res;
    if (getsockopt(fd, SOL_SOCKET, SO_ERROR, (char *)&res, &res_size) == 0)
      send_flags |= PYPYSIG_USE_SEND;
  }
#endif
  wakeup_fd = fd;
  wakeup_send_flags = send_flags;
  return old_fd;
}
