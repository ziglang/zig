/* `ptrace' debugger support interface.  Linux/SPARC version.
   Copyright (C) 1996-2024 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_PTRACE_H
#define _SYS_PTRACE_H	1

#include <features.h>
#include <bits/types.h>
#include <bits/wordsize.h>

/* Linux/SPARC kernels up to 2.3.18 do not care much
   about what namespace pollution, so use a kludge now.  */
#undef PTRACE_GETREGS
#undef PTRACE_SETREGS
#undef PTRACE_GETFPREGS
#undef PTRACE_SETFPREGS
#undef PTRACE_READDATA
#undef PTRACE_WRITEDATA
#undef PTRACE_READTEXT
#undef PTRACE_WRITETEXT
#undef PTRACE_SUNDETACH

__BEGIN_DECLS

/* Type of the REQUEST argument to `ptrace.'  */
enum __ptrace_request
{
  /* Indicate that the process making this request should be traced.
     All signals received by this process can be intercepted by its
     parent, and its parent can use the other `ptrace' requests.  */
  PTRACE_TRACEME = 0,
#define PT_TRACE_ME PTRACE_TRACEME

  /* Return the word in the process's text space at address ADDR.  */
  PTRACE_PEEKTEXT = 1,
#define PT_READ_I PTRACE_PEEKTEXT

  /* Return the word in the process's data space at address ADDR.  */
  PTRACE_PEEKDATA = 2,
#define PT_READ_D PTRACE_PEEKDATA

  /* Return the word in the process's user area at offset ADDR.  */
  PTRACE_PEEKUSER = 3,
#define PT_READ_U PTRACE_PEEKUSER

  /* Write the word DATA into the process's text space at address ADDR.  */
  PTRACE_POKETEXT = 4,
#define PT_WRITE_I PTRACE_POKETEXT

  /* Write the word DATA into the process's data space at address ADDR.  */
  PTRACE_POKEDATA = 5,
#define PT_WRITE_D PTRACE_POKEDATA

  /* Write the word DATA into the process's user area at offset ADDR.  */
  PTRACE_POKEUSER = 6,
#define PT_WRITE_U PTRACE_POKEUSER

  /* Continue the process.  */
  PTRACE_CONT = 7,
#define PT_CONTINUE PTRACE_CONT

  /* Kill the process.  */
  PTRACE_KILL = 8,
#define PT_KILL PTRACE_KILL

  /* Single step the process.  */
  PTRACE_SINGLESTEP = 9,
#define PT_STEP PTRACE_SINGLESTEP

  /* Detach from a process attached to with PTRACE_ATTACH.  */
  PTRACE_DETACH = 11,
#define PT_DETACH PTRACE_DETACH

  /* This define is needed for older programs which were
     trying to work around sparc-linux ptrace nastiness.  */
#define PTRACE_SUNDETACH PTRACE_DETACH

#if __WORDSIZE == 32

  /* Get all general purpose registers used by a processes.
     This is not supported on all machines.  */
   PTRACE_GETREGS = 12,
#define PT_GETREGS PTRACE_GETREGS

  /* Set all general purpose registers used by a processes.
     This is not supported on all machines.  */
   PTRACE_SETREGS = 13,
#define PT_SETREGS PTRACE_SETREGS

  /* Get all floating point registers used by a processes.
     This is not supported on all machines.  */
   PTRACE_GETFPREGS = 14,
#define PT_GETFPREGS PTRACE_GETFPREGS

  /* Set all floating point registers used by a processes.
     This is not supported on all machines.  */
   PTRACE_SETFPREGS = 15,
#define PT_SETFPREGS PTRACE_SETFPREGS

#endif

  /* Attach to a process that is already running. */
  PTRACE_ATTACH = 16,
#define PT_ATTACH PTRACE_ATTACH

  /* Write several bytes at a time. */
  PTRACE_WRITEDATA = 17,
#define PTRACE_WRITEDATA PTRACE_WRITEDATA

  /* Read several bytes at a time. */
  PTRACE_READTEXT = 18,
#define PTRACE_READTEXT PTRACE_READTEXT
#define PTRACE_READDATA PTRACE_READTEXT

  /* Write several bytes at a time. */
  PTRACE_WRITETEXT = 19,
#define PTRACE_WRITETEXT PTRACE_WRITETEXT

#if __WORDSIZE == 64

  /* Get all general purpose registers used by a processes.
     This is not supported on all machines.  */
   PTRACE_GETREGS = 22,
#define PT_GETREGS PTRACE_GETREGS

  /* Set all general purpose registers used by a processes.
     This is not supported on all machines.  */
   PTRACE_SETREGS = 23,
#define PT_SETREGS PTRACE_SETREGS

#endif

  /* Continue and stop at the next entry to or return from syscall.  */
  PTRACE_SYSCALL = 24,
#define PTRACE_SYSCALL PTRACE_SYSCALL

#if __WORDSIZE == 64

  /* Get all floating point registers used by a processes.
     This is not supported on all machines.  */
   PTRACE_GETFPREGS = 25,
#define PT_GETFPREGS PTRACE_GETFPREGS

  /* Set all floating point registers used by a processes.
     This is not supported on all machines.  */
   PTRACE_SETFPREGS = 26,
#define PT_SETFPREGS PTRACE_SETFPREGS

#endif

  /* Set ptrace filter options.  */
  PTRACE_SETOPTIONS = 0x4200,
#define PT_SETOPTIONS PTRACE_SETOPTIONS

  /* Get last ptrace message.  */
  PTRACE_GETEVENTMSG = 0x4201,
#define PT_GETEVENTMSG PTRACE_GETEVENTMSG

  /* Get siginfo for process.  */
  PTRACE_GETSIGINFO = 0x4202,
#define PT_GETSIGINFO PTRACE_GETSIGINFO

  /* Set new siginfo for process.  */
  PTRACE_SETSIGINFO = 0x4203,
#define PT_SETSIGINFO PTRACE_SETSIGINFO

  /* Get register content.  */
  PTRACE_GETREGSET = 0x4204,
#define PTRACE_GETREGSET PTRACE_GETREGSET

  /* Set register content.  */
  PTRACE_SETREGSET = 0x4205,
#define PTRACE_SETREGSET PTRACE_SETREGSET

  /* Like PTRACE_ATTACH, but do not force tracee to trap and do not affect
     signal or group stop state.  */
  PTRACE_SEIZE = 0x4206,
#define PTRACE_SEIZE PTRACE_SEIZE

  /* Trap seized tracee.  */
  PTRACE_INTERRUPT = 0x4207,
#define PTRACE_INTERRUPT PTRACE_INTERRUPT

  /* Wait for next group event.  */
  PTRACE_LISTEN = 0x4208,
#define PTRACE_LISTEN PTRACE_LISTEN

  /* Retrieve siginfo_t structures without removing signals from a queue.  */
  PTRACE_PEEKSIGINFO = 0x4209,
#define PTRACE_PEEKSIGINFO PTRACE_PEEKSIGINFO

  /* Get the mask of blocked signals.  */
  PTRACE_GETSIGMASK = 0x420a,
#define PTRACE_GETSIGMASK PTRACE_GETSIGMASK

  /* Change the mask of blocked signals.  */
  PTRACE_SETSIGMASK = 0x420b,
#define PTRACE_SETSIGMASK PTRACE_SETSIGMASK

  /* Get seccomp BPF filters.  */
  PTRACE_SECCOMP_GET_FILTER = 0x420c,
#define PTRACE_SECCOMP_GET_FILTER PTRACE_SECCOMP_GET_FILTER

  /* Get seccomp BPF filter metadata.  */
  PTRACE_SECCOMP_GET_METADATA = 0x420d,
#define PTRACE_SECCOMP_GET_METADATA PTRACE_SECCOMP_GET_METADATA

  /* Get information about system call.  */
  PTRACE_GET_SYSCALL_INFO = 0x420e,
#define PTRACE_GET_SYSCALL_INFO PTRACE_GET_SYSCALL_INFO

  /* Get rseq configuration information.  */
  PTRACE_GET_RSEQ_CONFIGURATION = 0x420f,
#define PTRACE_GET_RSEQ_CONFIGURATION PTRACE_GET_RSEQ_CONFIGURATION

  /* Set configuration for syscall user dispatch.  */
  PTRACE_SET_SYSCALL_USER_DISPATCH_CONFIG = 0x4210,
#define PTRACE_SET_SYSCALL_USER_DISPATCH_CONFIG \
  PTRACE_SET_SYSCALL_USER_DISPATCH_CONFIG

  /* Get configuration for syscall user dispatch.  */
  PTRACE_GET_SYSCALL_USER_DISPATCH_CONFIG = 0x4211
#define PTRACE_GET_SYSCALL_USER_DISPATCH_CONFIG \
  PTRACE_GET_SYSCALL_USER_DISPATCH_CONFIG
};


#include <bits/ptrace-shared.h>

__END_DECLS

#endif /* _SYS_PTRACE_H */