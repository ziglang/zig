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
#ifndef _UAPI_LINUX_MMAN_H
#define _UAPI_LINUX_MMAN_H
#include <asm/mman.h>
#include <asm-generic/hugetlb_encode.h>
#define MREMAP_MAYMOVE 1
#define MREMAP_FIXED 2
#define MREMAP_DONTUNMAP 4
#define OVERCOMMIT_GUESS 0
#define OVERCOMMIT_ALWAYS 1
#define OVERCOMMIT_NEVER 2
#define MAP_SHARED 0x01
#define MAP_PRIVATE 0x02
#define MAP_SHARED_VALIDATE 0x03
#define MAP_HUGE_SHIFT HUGETLB_FLAG_ENCODE_SHIFT
#define MAP_HUGE_MASK HUGETLB_FLAG_ENCODE_MASK
#define MAP_HUGE_16KB HUGETLB_FLAG_ENCODE_16KB
#define MAP_HUGE_64KB HUGETLB_FLAG_ENCODE_64KB
#define MAP_HUGE_512KB HUGETLB_FLAG_ENCODE_512KB
#define MAP_HUGE_1MB HUGETLB_FLAG_ENCODE_1MB
#define MAP_HUGE_2MB HUGETLB_FLAG_ENCODE_2MB
#define MAP_HUGE_8MB HUGETLB_FLAG_ENCODE_8MB
#define MAP_HUGE_16MB HUGETLB_FLAG_ENCODE_16MB
#define MAP_HUGE_32MB HUGETLB_FLAG_ENCODE_32MB
#define MAP_HUGE_256MB HUGETLB_FLAG_ENCODE_256MB
#define MAP_HUGE_512MB HUGETLB_FLAG_ENCODE_512MB
#define MAP_HUGE_1GB HUGETLB_FLAG_ENCODE_1GB
#define MAP_HUGE_2GB HUGETLB_FLAG_ENCODE_2GB
#define MAP_HUGE_16GB HUGETLB_FLAG_ENCODE_16GB
#endif