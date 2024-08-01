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
#ifndef _UAPI_LINUX_PERSONALITY_H
#define _UAPI_LINUX_PERSONALITY_H
enum {
  UNAME26 = 0x0020000,
  ADDR_NO_RANDOMIZE = 0x0040000,
  FDPIC_FUNCPTRS = 0x0080000,
  MMAP_PAGE_ZERO = 0x0100000,
  ADDR_COMPAT_LAYOUT = 0x0200000,
  READ_IMPLIES_EXEC = 0x0400000,
  ADDR_LIMIT_32BIT = 0x0800000,
  SHORT_INODE = 0x1000000,
  WHOLE_SECONDS = 0x2000000,
  STICKY_TIMEOUTS = 0x4000000,
  ADDR_LIMIT_3GB = 0x8000000,
};
#define PER_CLEAR_ON_SETID (READ_IMPLIES_EXEC | ADDR_NO_RANDOMIZE | ADDR_COMPAT_LAYOUT | MMAP_PAGE_ZERO)
enum {
  PER_LINUX = 0x0000,
  PER_LINUX_32BIT = 0x0000 | ADDR_LIMIT_32BIT,
  PER_LINUX_FDPIC = 0x0000 | FDPIC_FUNCPTRS,
  PER_SVR4 = 0x0001 | STICKY_TIMEOUTS | MMAP_PAGE_ZERO,
  PER_SVR3 = 0x0002 | STICKY_TIMEOUTS | SHORT_INODE,
  PER_SCOSVR3 = 0x0003 | STICKY_TIMEOUTS | WHOLE_SECONDS | SHORT_INODE,
  PER_OSR5 = 0x0003 | STICKY_TIMEOUTS | WHOLE_SECONDS,
  PER_WYSEV386 = 0x0004 | STICKY_TIMEOUTS | SHORT_INODE,
  PER_ISCR4 = 0x0005 | STICKY_TIMEOUTS,
  PER_BSD = 0x0006,
  PER_SUNOS = 0x0006 | STICKY_TIMEOUTS,
  PER_XENIX = 0x0007 | STICKY_TIMEOUTS | SHORT_INODE,
  PER_LINUX32 = 0x0008,
  PER_LINUX32_3GB = 0x0008 | ADDR_LIMIT_3GB,
  PER_IRIX32 = 0x0009 | STICKY_TIMEOUTS,
  PER_IRIXN32 = 0x000a | STICKY_TIMEOUTS,
  PER_IRIX64 = 0x000b | STICKY_TIMEOUTS,
  PER_RISCOS = 0x000c,
  PER_SOLARIS = 0x000d | STICKY_TIMEOUTS,
  PER_UW7 = 0x000e | STICKY_TIMEOUTS | MMAP_PAGE_ZERO,
  PER_OSF4 = 0x000f,
  PER_HPUX = 0x0010,
  PER_MASK = 0x00ff,
};
#endif