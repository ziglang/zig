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
#ifndef LINUX_ATMCLIP_H
#define LINUX_ATMCLIP_H
#include <linux/sockios.h>
#include <linux/atmioc.h>
#define RFC1483LLC_LEN 8
#define RFC1626_MTU 9180
#define CLIP_DEFAULT_IDLETIMER 1200
#define CLIP_CHECK_INTERVAL 10
#define SIOCMKCLIP _IO('a', ATMIOC_CLIP)
#endif