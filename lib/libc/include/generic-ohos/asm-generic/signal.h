/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _UAPI__ASM_GENERIC_SIGNAL_H
#define _UAPI__ASM_GENERIC_SIGNAL_H
#include <linux/types.h>
#define _KERNEL__NSIG 64
#define _NSIG_BPW __BITS_PER_LONG
#define _NSIG_WORDS (_KERNEL__NSIG / _NSIG_BPW)
#define SIGHUP 1
#define SIGINT 2
#define SIGQUIT 3
#define SIGILL 4
#define SIGTRAP 5
#define SIGABRT 6
#define SIGIOT 6
#define SIGBUS 7
#define SIGFPE 8
#define SIGKILL 9
#define SIGUSR1 10
#define SIGSEGV 11
#define SIGUSR2 12
#define SIGPIPE 13
#define SIGALRM 14
#define SIGTERM 15
#define SIGSTKFLT 16
#define SIGCHLD 17
#define SIGCONT 18
#define SIGSTOP 19
#define SIGTSTP 20
#define SIGTTIN 21
#define SIGTTOU 22
#define SIGURG 23
#define SIGXCPU 24
#define SIGXFSZ 25
#define SIGVTALRM 26
#define SIGPROF 27
#define SIGWINCH 28
#define SIGIO 29
#define SIGPOLL SIGIO
#define SIGPWR 30
#define SIGSYS 31
#define SIGUNUSED 31
#define __SIGRTMIN 32
#ifndef __SIGRTMAX
#define __SIGRTMAX _KERNEL__NSIG
#endif
#define SA_NOCLDSTOP 0x00000001
#define SA_NOCLDWAIT 0x00000002
#define SA_SIGINFO 0x00000004
#define SA_ONSTACK 0x08000000
#define SA_RESTART 0x10000000
#define SA_NODEFER 0x40000000
#define SA_RESETHAND 0x80000000
#define SA_NOMASK SA_NODEFER
#define SA_ONESHOT SA_RESETHAND
#if !defined(MINSIGSTKSZ) || !defined(SIGSTKSZ)
#define MINSIGSTKSZ 2048
#define SIGSTKSZ 8192
#endif
#ifndef __ASSEMBLY__
typedef struct {
  unsigned long sig[_NSIG_WORDS];
} sigset_t;
typedef unsigned long old_sigset_t;
#include <asm-generic/signal-defs.h>
#ifdef SA_RESTORER
#define __ARCH_HAS_SA_RESTORER
#endif
struct sigaction {
  __sighandler_t sa_handler;
  unsigned long sa_flags;
#ifdef SA_RESTORER
  __sigrestore_t sa_restorer;
#endif
  sigset_t sa_mask;
};
typedef struct sigaltstack {
  void __user * ss_sp;
  int ss_flags;
  size_t ss_size;
} stack_t;
#endif
#endif