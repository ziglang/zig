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
#ifndef _UAPI_LINUX_RPL_IPTUNNEL_H
#define _UAPI_LINUX_RPL_IPTUNNEL_H
enum {
  RPL_IPTUNNEL_UNSPEC,
  RPL_IPTUNNEL_SRH,
  __RPL_IPTUNNEL_MAX,
};
#define RPL_IPTUNNEL_MAX (__RPL_IPTUNNEL_MAX - 1)
#define RPL_IPTUNNEL_SRH_SIZE(srh) (((srh)->hdrlen + 1) << 3)
#endif