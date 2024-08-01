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
#ifndef _UAPI_LINUX_FOU_H
#define _UAPI_LINUX_FOU_H
#define FOU_GENL_NAME "fou"
#define FOU_GENL_VERSION 0x1
enum {
  FOU_ATTR_UNSPEC,
  FOU_ATTR_PORT,
  FOU_ATTR_AF,
  FOU_ATTR_IPPROTO,
  FOU_ATTR_TYPE,
  FOU_ATTR_REMCSUM_NOPARTIAL,
  FOU_ATTR_LOCAL_V4,
  FOU_ATTR_LOCAL_V6,
  FOU_ATTR_PEER_V4,
  FOU_ATTR_PEER_V6,
  FOU_ATTR_PEER_PORT,
  FOU_ATTR_IFINDEX,
  __FOU_ATTR_MAX,
};
#define FOU_ATTR_MAX (__FOU_ATTR_MAX - 1)
enum {
  FOU_CMD_UNSPEC,
  FOU_CMD_ADD,
  FOU_CMD_DEL,
  FOU_CMD_GET,
  __FOU_CMD_MAX,
};
enum {
  FOU_ENCAP_UNSPEC,
  FOU_ENCAP_DIRECT,
  FOU_ENCAP_GUE,
};
#define FOU_CMD_MAX (__FOU_CMD_MAX - 1)
#endif