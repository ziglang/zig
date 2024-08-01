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
#ifndef _ASM_GENERIC_FCNTL_H
#define _ASM_GENERIC_FCNTL_H

#include <linux/types.h>
#define O_ACCMODE 00000003
#define O_RDONLY 00000000
#define O_WRONLY 00000001
#define O_RDWR 00000002
#ifndef O_CREAT
#define O_CREAT 00000100
#endif
#ifndef O_EXCL
#define O_EXCL 00000200
#endif
#ifndef O_NOCTTY
#define O_NOCTTY 00000400
#endif
#ifndef O_TRUNC
#define O_TRUNC 00001000
#endif
#ifndef O_APPEND
#define O_APPEND 00002000
#endif
#ifndef O_NONBLOCK
#define O_NONBLOCK 00004000
#endif
#ifndef O_DSYNC
#define O_DSYNC 00010000
#endif
#ifndef FASYNC
#define FASYNC 00020000
#endif
#ifndef O_DIRECT
#define O_DIRECT 00040000
#endif
#ifndef O_LARGEFILE
#define O_LARGEFILE 00100000
#endif
#ifndef O_DIRECTORY
#define O_DIRECTORY 00200000
#endif
#ifndef O_NOFOLLOW
#define O_NOFOLLOW 00400000
#endif
#ifndef O_NOATIME
#define O_NOATIME 01000000
#endif
#ifndef O_CLOEXEC
#define O_CLOEXEC 02000000
#endif
#ifndef O_SYNC
#define __O_SYNC 04000000
#define O_SYNC (__O_SYNC | O_DSYNC)
#endif
#ifndef O_PATH
#define O_PATH 010000000
#endif
#ifndef __O_TMPFILE
#define __O_TMPFILE 020000000
#endif
#define O_TMPFILE (__O_TMPFILE | O_DIRECTORY)
#define O_TMPFILE_MASK (__O_TMPFILE | O_DIRECTORY | O_CREAT)
#ifndef O_NDELAY
#define O_NDELAY O_NONBLOCK
#endif
#define F_DUPFD 0
#define F_GETFD 1
#define F_SETFD 2
#define F_GETFL 3
#define F_SETFL 4
#ifndef F_GETLK
#define F_GETLK 5
#define F_SETLK 6
#define F_SETLKW 7
#endif
#ifndef F_SETOWN
#define F_SETOWN 8
#define F_GETOWN 9
#endif
#ifndef F_SETSIG
#define F_SETSIG 10
#define F_GETSIG 11
#endif
#ifndef __LP64__
#ifndef F_GETLK64
#define F_GETLK64 12
#define F_SETLK64 13
#define F_SETLKW64 14
#endif
#endif
#ifndef F_SETOWN_EX
#define F_SETOWN_EX 15
#define F_GETOWN_EX 16
#endif
#ifndef F_GETOWNER_UIDS
#define F_GETOWNER_UIDS 17
#endif
#define F_OFD_GETLK 36
#define F_OFD_SETLK 37
#define F_OFD_SETLKW 38
#define F_OWNER_TID 0
#define F_OWNER_PID 1
#define F_OWNER_PGRP 2
struct f_owner_ex {
  int type;
  __kernel_pid_t pid;
};
#define FD_CLOEXEC 1
#ifndef F_RDLCK
#define F_RDLCK 0
#define F_WRLCK 1
#define F_UNLCK 2
#endif
#ifndef F_EXLCK
#define F_EXLCK 4
#define F_SHLCK 8
#endif
#define LOCK_SH 1
#define LOCK_EX 2
#define LOCK_NB 4
#define LOCK_UN 8
#define LOCK_MAND 32
#define LOCK_READ 64
#define LOCK_WRITE 128
#define LOCK_RW 192
#define F_LINUX_SPECIFIC_BASE 1024
#ifndef HAVE_ARCH_STRUCT_FLOCK
#ifndef __ARCH_FLOCK_PAD
#define __ARCH_FLOCK_PAD
#endif

struct flock {
	short	l_type;
	short	l_whence;
	__kernel_off_t	l_start;
	__kernel_off_t	l_len;
	__kernel_pid_t	l_pid;
	__ARCH_FLOCK_PAD
};
#endif
#ifndef HAVE_ARCH_STRUCT_FLOCK64
#ifndef __ARCH_FLOCK64_PAD
#define __ARCH_FLOCK64_PAD
#endif

struct flock64 {
	short  l_type;
	short  l_whence;
	__kernel_loff_t l_start;
	__kernel_loff_t l_len;
	__kernel_pid_t  l_pid;
	__ARCH_FLOCK64_PAD
};
#endif
#endif