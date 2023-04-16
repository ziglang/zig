/* `ptrace' debugger support interface.  Linux/PowerPC version.
   Copyright (C) 2001-2023 Free Software Foundation, Inc.
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

__BEGIN_DECLS

#if defined _LINUX_PTRACE_H || defined _ASM_POWERPC_PTRACE_H
/* Do not let Linux headers macros interfere with enum __ptrace_request.  */
# undef PTRACE_ATTACH
# undef PTRACE_CONT
# undef PTRACE_DETACH
# undef PTRACE_GET_DEBUGREG
# undef PTRACE_GETEVENTMSG
# undef PTRACE_GETEVRREGS
# undef PTRACE_GETFPREGS
# undef PTRACE_GETREGS
# undef PTRACE_GETREGS64
# undef PTRACE_GETREGSET
# undef PTRACE_GET_RSEQ_CONFIGURATION
# undef PTRACE_GETSIGINFO
# undef PTRACE_GETSIGMASK
# undef PTRACE_GET_SYSCALL_INFO
# undef PTRACE_GETVRREGS
# undef PTRACE_GETVSRREGS
# undef PTRACE_INTERRUPT
# undef PTRACE_KILL
# undef PTRACE_LISTEN
# undef PTRACE_PEEKDATA
# undef PTRACE_PEEKSIGINFO
# undef PTRACE_PEEKTEXT
# undef PTRACE_POKEDATA
# undef PTRACE_POKETEXT
# undef PTRACE_SECCOMP_GET_FILTER
# undef PTRACE_SECCOMP_GET_METADATA
# undef PTRACE_SEIZE
# undef PTRACE_SET_DEBUGREG
# undef PTRACE_SETEVRREGS
# undef PTRACE_SETFPREGS
# undef PTRACE_SETOPTIONS
# undef PTRACE_SETREGS
# undef PTRACE_SETREGS64
# undef PTRACE_SETREGSET
# undef PTRACE_SETSIGINFO
# undef PTRACE_SETSIGMASK
# undef PTRACE_SETVRREGS
# undef PTRACE_SETVSRREGS
# undef PTRACE_SINGLEBLOCK
# undef PTRACE_SINGLESTEP
# undef PTRACE_SYSCALL
# undef PTRACE_SYSCALL_INFO_NONE
# undef PTRACE_SYSCALL_INFO_ENTRY
# undef PTRACE_SYSCALL_INFO_EXIT
# undef PTRACE_SYSCALL_INFO_SECCOMP
# undef PTRACE_SYSEMU
# undef PTRACE_SYSEMU_SINGLESTEP
# undef PTRACE_TRACEME
#endif

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

  /* Get all general purpose registers used by a process.  */
  PTRACE_GETREGS = 12,
#define PT_GETREGS PTRACE_GETREGS

  /* Set all general purpose registers used by a process.  */
  PTRACE_SETREGS = 13,
#define PT_SETREGS PTRACE_SETREGS

  /* Get all floating point registers used by a process.  */
  PTRACE_GETFPREGS = 14,
#define PT_GETFPREGS PTRACE_GETFPREGS

  /* Set all floating point registers used by a process.  */
  PTRACE_SETFPREGS = 15,
#define PT_SETFPREGS PTRACE_SETFPREGS

  /* Attach to a process that is already running. */
  PTRACE_ATTACH = 16,
#define PT_ATTACH PTRACE_ATTACH

  /* Detach from a process attached to with PTRACE_ATTACH.  */
  PTRACE_DETACH = 17,
#define PT_DETACH PTRACE_DETACH

  /* Get all altivec registers used by a process.  */
  PTRACE_GETVRREGS = 18,
#define PT_GETVRREGS PTRACE_GETVRREGS

  /* Set all altivec registers used by a process.  */
  PTRACE_SETVRREGS = 19,
#define PT_SETVRREGS PTRACE_SETVRREGS

  /* Get all SPE registers used by a process.  */
  PTRACE_GETEVRREGS = 20,
#define PT_GETEVRREGS PTRACE_GETEVRREGS

  /* Set all SPE registers used by a process.  */
  PTRACE_SETEVRREGS = 21,
#define PT_SETEVRREGS PTRACE_SETEVRREGS

  /* Same as PTRACE_GETREGS except a 32-bit process will obtain
     the full 64-bit registers.  Implemented by 64-bit kernels only.  */
  PTRACE_GETREGS64 = 22,
#define PT_GETREGS64 PTRACE_GETREGS64

  /* Same as PTRACE_SETREGS except a 32-bit process will set
     the full 64-bit registers.  Implemented by 64-bit kernels only.  */
  PTRACE_SETREGS64 = 23,
#define PT_SETREGS64 PTRACE_SETREGS64

  /* Continue and stop at the next entry to or return from syscall.  */
  PTRACE_SYSCALL = 24,
#define PT_SYSCALL PTRACE_SYSCALL

  /* Get a debug register of a process.  */
  PTRACE_GET_DEBUGREG = 25,
#define PT_GET_DEBUGREG PTRACE_GET_DEBUGREG

  /* Set a debug register of a process.  */
  PTRACE_SET_DEBUGREG = 26,
#define PT_SET_DEBUGREG PTRACE_SET_DEBUGREG

  /* Get the first 32 VSX registers of a process.  */
  PTRACE_GETVSRREGS = 27,
#define PT_GETVSRREGS PTRACE_GETVSRREGS

  /* Set the first 32 VSX registers of a process.  */
  PTRACE_SETVSRREGS = 28,
#define PT_SETVSRREGS PTRACE_SETVSRREGS

  /* Continue and stop at the next syscall, it will not be executed.  */
  PTRACE_SYSEMU = 29,
#define PT_SYSEMU PTRACE_SYSEMU

  /* Single step the process, the next syscall will not be executed.  */
  PTRACE_SYSEMU_SINGLESTEP = 30,
#define PT_SYSEMU_SINGLESTEP PTRACE_SYSEMU_SINGLESTEP

  /* Execute process until next taken branch.  */
  PTRACE_SINGLEBLOCK = 256,
#define PT_STEPBLOCK PTRACE_SINGLEBLOCK

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
  PTRACE_GET_RSEQ_CONFIGURATION = 0x420f
#define PTRACE_GET_RSEQ_CONFIGURATION PTRACE_GET_RSEQ_CONFIGURATION
};


#include <bits/ptrace-shared.h>

__END_DECLS

#endif /* _SYS_PTRACE_H */