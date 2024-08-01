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
#ifndef _UAPI__LINUX_IP6_NETFILTER_H
#define _UAPI__LINUX_IP6_NETFILTER_H
#include <linux/netfilter.h>
#include <limits.h>
#define NF_IP6_PRE_ROUTING 0
#define NF_IP6_LOCAL_IN 1
#define NF_IP6_FORWARD 2
#define NF_IP6_LOCAL_OUT 3
#define NF_IP6_POST_ROUTING 4
#define NF_IP6_NUMHOOKS 5
enum nf_ip6_hook_priorities {
  NF_IP6_PRI_FIRST = INT_MIN,
  NF_IP6_PRI_RAW_BEFORE_DEFRAG = - 450,
  NF_IP6_PRI_CONNTRACK_DEFRAG = - 400,
  NF_IP6_PRI_RAW = - 300,
  NF_IP6_PRI_SELINUX_FIRST = - 225,
  NF_IP6_PRI_CONNTRACK = - 200,
  NF_IP6_PRI_MANGLE = - 150,
  NF_IP6_PRI_NAT_DST = - 100,
  NF_IP6_PRI_FILTER = 0,
  NF_IP6_PRI_SECURITY = 50,
  NF_IP6_PRI_NAT_SRC = 100,
  NF_IP6_PRI_SELINUX_LAST = 225,
  NF_IP6_PRI_CONNTRACK_HELPER = 300,
  NF_IP6_PRI_LAST = INT_MAX,
};
#endif