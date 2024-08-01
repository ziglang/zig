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
#ifndef _UAPI_LINUX_UUID_H_
#define _UAPI_LINUX_UUID_H_
#include <linux/types.h>
typedef struct {
  __u8 b[16];
} guid_t;
#define GUID_INIT(a,b,c,d0,d1,d2,d3,d4,d5,d6,d7) \
((guid_t) \
{ { (a) & 0xff, ((a) >> 8) & 0xff, ((a) >> 16) & 0xff, ((a) >> 24) & 0xff, (b) & 0xff, ((b) >> 8) & 0xff, (c) & 0xff, ((c) >> 8) & 0xff, (d0), (d1), (d2), (d3), (d4), (d5), (d6), (d7) } })
typedef guid_t uuid_le;
#define UUID_LE(a,b,c,d0,d1,d2,d3,d4,d5,d6,d7) GUID_INIT(a, b, c, d0, d1, d2, d3, d4, d5, d6, d7)
#define NULL_UUID_LE UUID_LE(0x00000000, 0x0000, 0x0000, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
#endif