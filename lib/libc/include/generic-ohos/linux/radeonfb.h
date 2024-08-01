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
#ifndef __LINUX_RADEONFB_H__
#define __LINUX_RADEONFB_H__
#include <asm/ioctl.h>
#include <linux/types.h>
#define ATY_RADEON_LCD_ON 0x00000001
#define ATY_RADEON_CRT_ON 0x00000002
#define FBIO_RADEON_GET_MIRROR _IOR('@', 3, size_t)
#define FBIO_RADEON_SET_MIRROR _IOW('@', 4, size_t)
#endif