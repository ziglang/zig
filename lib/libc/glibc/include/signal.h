#ifndef _SIGNAL_H
# include <signal/signal.h>

# ifndef _ISOMAC
#  include <sigsetops.h>

libc_hidden_proto (sigemptyset)
libc_hidden_proto (sigfillset)
libc_hidden_proto (sigaddset)
libc_hidden_proto (sigdelset)
libc_hidden_proto (sigismember)
extern int __sigpause (int sig_or_mask, int is_sig);
libc_hidden_proto (__sigpause)
libc_hidden_proto (raise)
libc_hidden_proto (__libc_current_sigrtmin)
libc_hidden_proto (__libc_current_sigrtmax)
extern const char * const __sys_siglist[_NSIG] attribute_hidden;
extern const char * const __sys_sigabbrev[_NSIG] attribute_hidden;

/* Now define the internal interfaces.  */
extern __sighandler_t __bsd_signal (int __sig, __sighandler_t __handler);
extern int __kill (__pid_t __pid, int __sig);
libc_hidden_proto (__kill)
extern int __sigaction (int __sig, const struct sigaction *__restrict __act,
			struct sigaction *__restrict __oact);
libc_hidden_proto (__sigaction)
extern int __sigblock (int __mask);
libc_hidden_proto (__sigblock)
extern int __sigsetmask (int __mask);
extern int __sigprocmask (int __how,
			  const sigset_t *__set, sigset_t *__oset);
libc_hidden_proto (__sigprocmask)
extern int __sigsuspend (const sigset_t *__set);
libc_hidden_proto (__sigsuspend)
extern int __sigwait (const sigset_t *__set, int *__sig);
libc_hidden_proto (__sigwait)
extern int __sigwaitinfo (const sigset_t *__set, siginfo_t *__info);
libc_hidden_proto (__sigwaitinfo)
#if __TIMESIZE == 64
# define __sigtimedwait64 __sigtimedwait
#else
# include <struct___timespec64.h>
extern int __sigtimedwait64 (const sigset_t *__set, siginfo_t *__info,
			     const struct __timespec64 *__timeout);
libc_hidden_proto (__sigtimedwait64)
#endif
extern int __sigtimedwait (const sigset_t *__set, siginfo_t *__info,
			   const struct timespec *__timeout);
libc_hidden_proto (__sigtimedwait)
extern int __sigqueue (__pid_t __pid, int __sig,
		       const union sigval __val);
#ifdef __USE_MISC
extern int __sigreturn (struct sigcontext *__scp);
#endif
extern int __sigaltstack (const stack_t *__ss,
			  stack_t *__oss);
libc_hidden_proto (__sigaltstack)
extern int __libc_sigaction (int sig, const struct sigaction *act,
			     struct sigaction *oact);
libc_hidden_proto (__libc_sigaction)

extern int __default_sigpause (int mask);
extern int __xpg_sigpause (int sig);

/* Allocate real-time signal with highest/lowest available priority.  */
extern int __libc_allocate_rtsig (int __high);

#  if IS_IN (rtld)
extern __typeof (__sigaction) __sigaction attribute_hidden;
extern __typeof (__libc_sigaction) __libc_sigaction attribute_hidden;
#  endif

# endif /* _ISOMAC */
#endif /* signal.h */
