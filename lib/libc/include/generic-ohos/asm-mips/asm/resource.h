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
#ifndef _ASM_RESOURCE_H
#define _ASM_RESOURCE_H
#define RLIMIT_NOFILE 5
#define RLIMIT_AS 6
#define RLIMIT_RSS 7
#define RLIMIT_NPROC 8
#define RLIMIT_MEMLOCK 9
#ifndef __mips64
#define RLIM_INFINITY 0x7fffffffUL
#endif
#include <asm-generic/resource.h>
#endif