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
#ifndef _ASM_MMAN_H
#define _ASM_MMAN_H
#define PROT_NONE 0x00
#define PROT_READ 0x01
#define PROT_WRITE 0x02
#define PROT_EXEC 0x04
#define PROT_SEM 0x10
#define PROT_GROWSDOWN 0x01000000
#define PROT_GROWSUP 0x02000000
#define MAP_TYPE 0x00f
#define MAP_FIXED 0x010
#define MAP_RENAME 0x020
#define MAP_AUTOGROW 0x040
#define MAP_LOCAL 0x080
#define MAP_AUTORSRV 0x100
#define MAP_NORESERVE 0x0400
#define MAP_ANONYMOUS 0x0800
#define MAP_GROWSDOWN 0x1000
#define MAP_DENYWRITE 0x2000
#define MAP_EXECUTABLE 0x4000
#define MAP_LOCKED 0x8000
#define MAP_POPULATE 0x10000
#define MAP_NONBLOCK 0x20000
#define MAP_STACK 0x40000
#define MAP_HUGETLB 0x80000
#define MAP_FIXED_NOREPLACE 0x100000
#define MS_ASYNC 0x0001
#define MS_INVALIDATE 0x0002
#define MS_SYNC 0x0004
#define MCL_CURRENT 1
#define MCL_FUTURE 2
#define MCL_ONFAULT 4
#define MLOCK_ONFAULT 0x01
#define MADV_NORMAL 0
#define MADV_RANDOM 1
#define MADV_SEQUENTIAL 2
#define MADV_WILLNEED 3
#define MADV_DONTNEED 4
#define MADV_FREE 8
#define MADV_REMOVE 9
#define MADV_DONTFORK 10
#define MADV_DOFORK 11
#define MADV_MERGEABLE 12
#define MADV_UNMERGEABLE 13
#define MADV_HWPOISON 100
#define MADV_HUGEPAGE 14
#define MADV_NOHUGEPAGE 15
#define MADV_DONTDUMP 16
#define MADV_DODUMP 17
#define MADV_WIPEONFORK 18
#define MADV_KEEPONFORK 19
#define MADV_COLD 20
#define MADV_PAGEOUT 21
#define MAP_FILE 0
#define PKEY_DISABLE_ACCESS 0x1
#define PKEY_DISABLE_WRITE 0x2
#define PKEY_ACCESS_MASK (PKEY_DISABLE_ACCESS | PKEY_DISABLE_WRITE)
#endif