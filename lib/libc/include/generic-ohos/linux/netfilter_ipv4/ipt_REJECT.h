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
#ifndef _IPT_REJECT_H
#define _IPT_REJECT_H
enum ipt_reject_with {
  IPT_ICMP_NET_UNREACHABLE,
  IPT_ICMP_HOST_UNREACHABLE,
  IPT_ICMP_PROT_UNREACHABLE,
  IPT_ICMP_PORT_UNREACHABLE,
  IPT_ICMP_ECHOREPLY,
  IPT_ICMP_NET_PROHIBITED,
  IPT_ICMP_HOST_PROHIBITED,
  IPT_TCP_RESET,
  IPT_ICMP_ADMIN_PROHIBITED
};
struct ipt_reject_info {
  enum ipt_reject_with with;
};
#endif