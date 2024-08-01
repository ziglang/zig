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
#ifndef _UAPI_LINUX_NET_NAMESPACE_H_
#define _UAPI_LINUX_NET_NAMESPACE_H_
enum {
  NETNSA_NONE,
#define NETNSA_NSID_NOT_ASSIGNED - 1
  NETNSA_NSID,
  NETNSA_PID,
  NETNSA_FD,
  NETNSA_TARGET_NSID,
  NETNSA_CURRENT_NSID,
  __NETNSA_MAX,
};
#define NETNSA_MAX (__NETNSA_MAX - 1)
#endif