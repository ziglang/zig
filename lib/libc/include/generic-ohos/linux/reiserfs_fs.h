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
#ifndef _LINUX_REISER_FS_H
#define _LINUX_REISER_FS_H
#include <linux/types.h>
#include <linux/magic.h>
#define REISERFS_IOC_UNPACK _IOW(0xCD, 1, long)
#define REISERFS_IOC_GETFLAGS FS_IOC_GETFLAGS
#define REISERFS_IOC_SETFLAGS FS_IOC_SETFLAGS
#define REISERFS_IOC_GETVERSION FS_IOC_GETVERSION
#define REISERFS_IOC_SETVERSION FS_IOC_SETVERSION
#endif