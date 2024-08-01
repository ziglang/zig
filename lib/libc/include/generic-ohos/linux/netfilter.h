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
#ifndef _UAPI__LINUX_NETFILTER_H
#define _UAPI__LINUX_NETFILTER_H
#include <linux/types.h>
#include <linux/compiler.h>
#include <linux/in.h>
#include <linux/in6.h>
#define NF_DROP 0
#define NF_ACCEPT 1
#define NF_STOLEN 2
#define NF_QUEUE 3
#define NF_REPEAT 4
#define NF_STOP 5
#define NF_MAX_VERDICT NF_STOP
#define NF_VERDICT_MASK 0x000000ff
#define NF_VERDICT_FLAG_QUEUE_BYPASS 0x00008000
#define NF_VERDICT_QMASK 0xffff0000
#define NF_VERDICT_QBITS 16
#define NF_QUEUE_NR(x) ((((x) << 16) & NF_VERDICT_QMASK) | NF_QUEUE)
#define NF_DROP_ERR(x) (((- x) << 16) | NF_DROP)
#define NF_VERDICT_BITS 16
enum nf_inet_hooks {
  NF_INET_PRE_ROUTING,
  NF_INET_LOCAL_IN,
  NF_INET_FORWARD,
  NF_INET_LOCAL_OUT,
  NF_INET_POST_ROUTING,
  NF_INET_NUMHOOKS,
  NF_INET_INGRESS = NF_INET_NUMHOOKS,
};
enum nf_dev_hooks {
  NF_NETDEV_INGRESS,
  NF_NETDEV_NUMHOOKS
};
enum {
  NFPROTO_UNSPEC = 0,
  NFPROTO_INET = 1,
  NFPROTO_IPV4 = 2,
  NFPROTO_ARP = 3,
  NFPROTO_NETDEV = 5,
  NFPROTO_BRIDGE = 7,
  NFPROTO_IPV6 = 10,
  NFPROTO_DECNET = 12,
  NFPROTO_NUMPROTO,
};
union nf_inet_addr {
  __u32 all[4];
  __be32 ip;
  __be32 ip6[4];
  struct in_addr in;
  struct in6_addr in6;
};
#endif