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
#ifndef _UAPI_LINUX_SEG6_GENL_H
#define _UAPI_LINUX_SEG6_GENL_H
#define SEG6_GENL_NAME "SEG6"
#define SEG6_GENL_VERSION 0x1
enum {
  SEG6_ATTR_UNSPEC,
  SEG6_ATTR_DST,
  SEG6_ATTR_DSTLEN,
  SEG6_ATTR_HMACKEYID,
  SEG6_ATTR_SECRET,
  SEG6_ATTR_SECRETLEN,
  SEG6_ATTR_ALGID,
  SEG6_ATTR_HMACINFO,
  __SEG6_ATTR_MAX,
};
#define SEG6_ATTR_MAX (__SEG6_ATTR_MAX - 1)
enum {
  SEG6_CMD_UNSPEC,
  SEG6_CMD_SETHMAC,
  SEG6_CMD_DUMPHMAC,
  SEG6_CMD_SET_TUNSRC,
  SEG6_CMD_GET_TUNSRC,
  __SEG6_CMD_MAX,
};
#define SEG6_CMD_MAX (__SEG6_CMD_MAX - 1)
#endif