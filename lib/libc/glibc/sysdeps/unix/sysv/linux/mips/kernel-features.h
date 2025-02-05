/* Set flags signalling availability of kernel features based on given
   kernel version number.
   Copyright (C) 1999-2024 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#include <sgidefs.h>

#include_next <kernel-features.h>

/* The MIPS kernel does not support futex_atomic_cmpxchg_inatomic if
   emulating LL/SC.  */
#if __mips == 1 || defined _MIPS_ARCH_R5900
# undef __ASSUME_SET_ROBUST_LIST
#endif

/* Define this if your 32-bit syscall API requires 64-bit register
   pairs to start with an even-number register.  */
#if _MIPS_SIM == _ABIO32
# define __ASSUME_ALIGNED_REGISTER_PAIRS	1
/* mips32 only supports ipc syscall before 5.1.  */
# if __LINUX_KERNEL_VERSION < 0x050100
#  undef __ASSUME_DIRECT_SYSVIPC_SYSCALLS
#  undef __ASSUME_SYSVIPC_DEFAULT_IPC_64
# else
# endif

/* The o32 MIPS fadvise64 syscall behaves as fadvise64_64.  */
# define __ASSUME_FADVISE64_AS_64_64		1

/* mips32 support wire-up network syscalls.  */
# define __ASSUME_RECV_SYSCALL		1
# define __ASSUME_SEND_SYSCALL		1
#else
# undef __ASSUME_SYSVIPC_DEFAULT_IPC_64
#endif

/* Define that mips64-n32 is a ILP32 ABI to set the correct interface to
   pass 64-bits values through syscalls.  */
#if _MIPS_SIM == _ABIN32
# define __ASSUME_WORDSIZE64_ILP32	1
#endif

#undef __ASSUME_CLONE_DEFAULT
#define __ASSUME_CLONE_BACKWARDS	1
