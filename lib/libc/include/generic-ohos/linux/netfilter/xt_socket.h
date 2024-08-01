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
#ifndef _XT_SOCKET_H
#define _XT_SOCKET_H
#include <linux/types.h>
enum {
  XT_SOCKET_TRANSPARENT = 1 << 0,
  XT_SOCKET_NOWILDCARD = 1 << 1,
  XT_SOCKET_RESTORESKMARK = 1 << 2,
};
struct xt_socket_mtinfo1 {
  __u8 flags;
};
#define XT_SOCKET_FLAGS_V1 XT_SOCKET_TRANSPARENT
struct xt_socket_mtinfo2 {
  __u8 flags;
};
#define XT_SOCKET_FLAGS_V2 (XT_SOCKET_TRANSPARENT | XT_SOCKET_NOWILDCARD)
struct xt_socket_mtinfo3 {
  __u8 flags;
};
#define XT_SOCKET_FLAGS_V3 (XT_SOCKET_TRANSPARENT | XT_SOCKET_NOWILDCARD | XT_SOCKET_RESTORESKMARK)
#endif