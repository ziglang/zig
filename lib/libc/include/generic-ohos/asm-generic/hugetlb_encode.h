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
#ifndef _ASM_GENERIC_HUGETLB_ENCODE_H_
#define _ASM_GENERIC_HUGETLB_ENCODE_H_
#define HUGETLB_FLAG_ENCODE_SHIFT 26
#define HUGETLB_FLAG_ENCODE_MASK 0x3f
#define HUGETLB_FLAG_ENCODE_16KB (14 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_64KB (16 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_512KB (19 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_1MB (20 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_2MB (21 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_8MB (23 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_16MB (24 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_32MB (25 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_256MB (28 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_512MB (29 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_1GB (30 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_2GB (31 << HUGETLB_FLAG_ENCODE_SHIFT)
#define HUGETLB_FLAG_ENCODE_16GB (34 << HUGETLB_FLAG_ENCODE_SHIFT)
#endif