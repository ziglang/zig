/* Restartable Sequences exported symbols.  Linux header.
   Copyright (C) 2021-2023 Free Software Foundation, Inc.

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

#ifndef _SYS_RSEQ_H
#define _SYS_RSEQ_H	1

/* Architecture-specific rseq signature.  */
#include <bits/rseq.h>

#include <stddef.h>
#include <stdint.h>
#include <sys/cdefs.h>

#ifdef __has_include
# if __has_include ("linux/rseq.h")
#  define __GLIBC_HAVE_KERNEL_RSEQ
# endif
#else
# include <linux/version.h>
# if LINUX_VERSION_CODE >= KERNEL_VERSION (4, 18, 0)
#  define __GLIBC_HAVE_KERNEL_RSEQ
# endif
#endif

#ifdef __GLIBC_HAVE_KERNEL_RSEQ
/* We use the structures declarations from the kernel headers.  */
# include <linux/rseq.h>
#else /* __GLIBC_HAVE_KERNEL_RSEQ */
/* We use a copy of the include/uapi/linux/rseq.h kernel header.  */

enum rseq_cpu_id_state
  {
    RSEQ_CPU_ID_UNINITIALIZED = -1,
    RSEQ_CPU_ID_REGISTRATION_FAILED = -2,
  };

enum rseq_flags
  {
    RSEQ_FLAG_UNREGISTER = (1 << 0),
  };

enum rseq_cs_flags_bit
  {
    RSEQ_CS_FLAG_NO_RESTART_ON_PREEMPT_BIT = 0,
    RSEQ_CS_FLAG_NO_RESTART_ON_SIGNAL_BIT = 1,
    RSEQ_CS_FLAG_NO_RESTART_ON_MIGRATE_BIT = 2,
  };

enum rseq_cs_flags
  {
    RSEQ_CS_FLAG_NO_RESTART_ON_PREEMPT =
      (1U << RSEQ_CS_FLAG_NO_RESTART_ON_PREEMPT_BIT),
    RSEQ_CS_FLAG_NO_RESTART_ON_SIGNAL =
      (1U << RSEQ_CS_FLAG_NO_RESTART_ON_SIGNAL_BIT),
    RSEQ_CS_FLAG_NO_RESTART_ON_MIGRATE =
      (1U << RSEQ_CS_FLAG_NO_RESTART_ON_MIGRATE_BIT),
  };

/* struct rseq_cs is aligned on 32 bytes to ensure it is always
   contained within a single cache-line.  It is usually declared as
   link-time constant data.  */
struct rseq_cs
  {
    /* Version of this structure.  */
    uint32_t version;
    /* enum rseq_cs_flags.  */
    uint32_t flags;
    uint64_t start_ip;
    /* Offset from start_ip.  */
    uint64_t post_commit_offset;
    uint64_t abort_ip;
  } __attribute__ ((__aligned__ (32)));

/* struct rseq is aligned on 32 bytes to ensure it is always
   contained within a single cache-line.

   A single struct rseq per thread is allowed.  */
struct rseq
  {
    /* Restartable sequences cpu_id_start field.  Updated by the
       kernel.  Read by user-space with single-copy atomicity
       semantics.  This field should only be read by the thread which
       registered this data structure.  Aligned on 32-bit.  Always
       contains a value in the range of possible CPUs, although the
       value may not be the actual current CPU (e.g. if rseq is not
       initialized).  This CPU number value should always be compared
       against the value of the cpu_id field before performing a rseq
       commit or returning a value read from a data structure indexed
       using the cpu_id_start value.  */
    uint32_t cpu_id_start;
    /* Restartable sequences cpu_id field.  Updated by the kernel.
       Read by user-space with single-copy atomicity semantics.  This
       field should only be read by the thread which registered this
       data structure.  Aligned on 32-bit.  Values
       RSEQ_CPU_ID_UNINITIALIZED and RSEQ_CPU_ID_REGISTRATION_FAILED
       have a special semantic: the former means "rseq uninitialized",
       and latter means "rseq initialization failed".  This value is
       meant to be read within rseq critical sections and compared
       with the cpu_id_start value previously read, before performing
       the commit instruction, or read and compared with the
       cpu_id_start value before returning a value loaded from a data
       structure indexed using the cpu_id_start value.  */
    uint32_t cpu_id;
    /* Restartable sequences rseq_cs field.

       Contains NULL when no critical section is active for the current
       thread, or holds a pointer to the currently active struct rseq_cs.

       Updated by user-space, which sets the address of the currently
       active rseq_cs at the beginning of assembly instruction sequence
       block, and set to NULL by the kernel when it restarts an assembly
       instruction sequence block, as well as when the kernel detects that
       it is preempting or delivering a signal outside of the range
       targeted by the rseq_cs.  Also needs to be set to NULL by user-space
       before reclaiming memory that contains the targeted struct rseq_cs.

       Read and set by the kernel. Set by user-space with single-copy
       atomicity semantics. This field should only be updated by the
       thread which registered this data structure. Aligned on 64-bit.

       32-bit architectures should update the low order bits of the
       rseq_cs field, leaving the high order bits initialized to 0.  */
    uint64_t rseq_cs;
    /* Restartable sequences flags field.

       This field should only be updated by the thread which
       registered this data structure.  Read by the kernel.
       Mainly used for single-stepping through rseq critical sections
       with debuggers.

       - RSEQ_CS_FLAG_NO_RESTART_ON_PREEMPT
           Inhibit instruction sequence block restart on preemption
           for this thread.
       - RSEQ_CS_FLAG_NO_RESTART_ON_SIGNAL
           Inhibit instruction sequence block restart on signal
           delivery for this thread.
       - RSEQ_CS_FLAG_NO_RESTART_ON_MIGRATE
           Inhibit instruction sequence block restart on migration for
           this thread.  */
    uint32_t flags;
  } __attribute__ ((__aligned__ (32)));

#endif /* __GLIBC_HAVE_KERNEL_RSEQ */

/* Offset from the thread pointer to the rseq area.  */
extern const ptrdiff_t __rseq_offset;

/* Size of the registered rseq area.  0 if the registration was
   unsuccessful.  */
extern const unsigned int __rseq_size;

/* Flags used during rseq registration.  */
extern const unsigned int __rseq_flags;

#endif /* sys/rseq.h */