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
#ifndef _UAPI_LINUX_RSEQ_H
#define _UAPI_LINUX_RSEQ_H
#include <linux/types.h>
#include <asm/byteorder.h>
enum rseq_cpu_id_state {
  RSEQ_CPU_ID_UNINITIALIZED = - 1,
  RSEQ_CPU_ID_REGISTRATION_FAILED = - 2,
};
enum rseq_flags {
  RSEQ_FLAG_UNREGISTER = (1 << 0),
};
enum rseq_cs_flags_bit {
  RSEQ_CS_FLAG_NO_RESTART_ON_PREEMPT_BIT = 0,
  RSEQ_CS_FLAG_NO_RESTART_ON_SIGNAL_BIT = 1,
  RSEQ_CS_FLAG_NO_RESTART_ON_MIGRATE_BIT = 2,
};
enum rseq_cs_flags {
  RSEQ_CS_FLAG_NO_RESTART_ON_PREEMPT = (1U << RSEQ_CS_FLAG_NO_RESTART_ON_PREEMPT_BIT),
  RSEQ_CS_FLAG_NO_RESTART_ON_SIGNAL = (1U << RSEQ_CS_FLAG_NO_RESTART_ON_SIGNAL_BIT),
  RSEQ_CS_FLAG_NO_RESTART_ON_MIGRATE = (1U << RSEQ_CS_FLAG_NO_RESTART_ON_MIGRATE_BIT),
};
struct rseq_cs {
  __u32 version;
  __u32 flags;
  __u64 start_ip;
  __u64 post_commit_offset;
  __u64 abort_ip;
} __attribute__((aligned(4 * sizeof(__u64))));
struct rseq {
  __u32 cpu_id_start;
  __u32 cpu_id;
  union {
    __u64 ptr64;
#ifdef __LP64__
    __u64 ptr;
#else
    struct {
#if defined(__BYTE_ORDER) && __BYTE_ORDER == __BIG_ENDIAN || defined(__BIG_ENDIAN)
      __u32 padding;
      __u32 ptr32;
#else
      __u32 ptr32;
      __u32 padding;
#endif
    } ptr;
#endif
  } rseq_cs;
  __u32 flags;
} __attribute__((aligned(4 * sizeof(__u64))));
#endif