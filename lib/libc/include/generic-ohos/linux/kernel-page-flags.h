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
#ifndef _UAPILINUX_KERNEL_PAGE_FLAGS_H
#define _UAPILINUX_KERNEL_PAGE_FLAGS_H
#define KPF_LOCKED 0
#define KPF_ERROR 1
#define KPF_REFERENCED 2
#define KPF_UPTODATE 3
#define KPF_DIRTY 4
#define KPF_LRU 5
#define KPF_ACTIVE 6
#define KPF_SLAB 7
#define KPF_WRITEBACK 8
#define KPF_RECLAIM 9
#define KPF_BUDDY 10
#define KPF_MMAP 11
#define KPF_ANON 12
#define KPF_SWAPCACHE 13
#define KPF_SWAPBACKED 14
#define KPF_COMPOUND_HEAD 15
#define KPF_COMPOUND_TAIL 16
#define KPF_HUGE 17
#define KPF_UNEVICTABLE 18
#define KPF_HWPOISON 19
#define KPF_NOPAGE 20
#define KPF_KSM 21
#define KPF_THP 22
#define KPF_OFFLINE 23
#define KPF_ZERO_PAGE 24
#define KPF_IDLE 25
#define KPF_PGTABLE 26
#endif