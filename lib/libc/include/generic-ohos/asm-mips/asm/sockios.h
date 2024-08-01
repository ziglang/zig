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
#ifndef _ASM_SOCKIOS_H
#define _ASM_SOCKIOS_H
#include <asm/ioctl.h>
#define FIOGETOWN _IOR('f', 123, int)
#define FIOSETOWN _IOW('f', 124, int)
#define SIOCATMARK _IOR('s', 7, int)
#define SIOCSPGRP _IOW('s', 8, pid_t)
#define SIOCGPGRP _IOR('s', 9, pid_t)
#define SIOCGSTAMP_OLD 0x8906
#define SIOCGSTAMPNS_OLD 0x8907
#endif