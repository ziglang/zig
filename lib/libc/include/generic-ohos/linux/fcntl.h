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
#ifndef _UAPI_LINUX_FCNTL_H
#define _UAPI_LINUX_FCNTL_H
#include <asm/fcntl.h>
#include <linux/openat2.h>
#define F_SETLEASE (F_LINUX_SPECIFIC_BASE + 0)
#define F_GETLEASE (F_LINUX_SPECIFIC_BASE + 1)
#define F_CANCELLK (F_LINUX_SPECIFIC_BASE + 5)
#define F_DUPFD_CLOEXEC (F_LINUX_SPECIFIC_BASE + 6)
#define F_NOTIFY (F_LINUX_SPECIFIC_BASE + 2)
#define F_SETPIPE_SZ (F_LINUX_SPECIFIC_BASE + 7)
#define F_GETPIPE_SZ (F_LINUX_SPECIFIC_BASE + 8)
#define F_ADD_SEALS (F_LINUX_SPECIFIC_BASE + 9)
#define F_GET_SEALS (F_LINUX_SPECIFIC_BASE + 10)
#define F_SEAL_SEAL 0x0001
#define F_SEAL_SHRINK 0x0002
#define F_SEAL_GROW 0x0004
#define F_SEAL_WRITE 0x0008
#define F_SEAL_FUTURE_WRITE 0x0010
#define F_GET_RW_HINT (F_LINUX_SPECIFIC_BASE + 11)
#define F_SET_RW_HINT (F_LINUX_SPECIFIC_BASE + 12)
#define F_GET_FILE_RW_HINT (F_LINUX_SPECIFIC_BASE + 13)
#define F_SET_FILE_RW_HINT (F_LINUX_SPECIFIC_BASE + 14)
#define RWH_WRITE_LIFE_NOT_SET 0
#define RWH_WRITE_LIFE_NONE 1
#define RWH_WRITE_LIFE_SHORT 2
#define RWH_WRITE_LIFE_MEDIUM 3
#define RWH_WRITE_LIFE_LONG 4
#define RWH_WRITE_LIFE_EXTREME 5
#define RWF_WRITE_LIFE_NOT_SET RWH_WRITE_LIFE_NOT_SET
#define DN_ACCESS 0x00000001
#define DN_MODIFY 0x00000002
#define DN_CREATE 0x00000004
#define DN_DELETE 0x00000008
#define DN_RENAME 0x00000010
#define DN_ATTRIB 0x00000020
#define DN_MULTISHOT 0x80000000
#define AT_FDCWD - 100
#define AT_SYMLINK_NOFOLLOW 0x100
#define AT_EACCESS 0x200
#define AT_REMOVEDIR 0x200
#define AT_SYMLINK_FOLLOW 0x400
#define AT_NO_AUTOMOUNT 0x800
#define AT_EMPTY_PATH 0x1000
#define AT_STATX_SYNC_TYPE 0x6000
#define AT_STATX_SYNC_AS_STAT 0x0000
#define AT_STATX_FORCE_SYNC 0x2000
#define AT_STATX_DONT_SYNC 0x4000
#define AT_RECURSIVE 0x8000
#endif