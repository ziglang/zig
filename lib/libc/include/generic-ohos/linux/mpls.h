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
#ifndef _UAPI_MPLS_H
#define _UAPI_MPLS_H
#include <linux/types.h>
#include <asm/byteorder.h>
struct mpls_label {
  __be32 entry;
};
#define MPLS_LS_LABEL_MASK 0xFFFFF000
#define MPLS_LS_LABEL_SHIFT 12
#define MPLS_LS_TC_MASK 0x00000E00
#define MPLS_LS_TC_SHIFT 9
#define MPLS_LS_S_MASK 0x00000100
#define MPLS_LS_S_SHIFT 8
#define MPLS_LS_TTL_MASK 0x000000FF
#define MPLS_LS_TTL_SHIFT 0
#define MPLS_LABEL_IPV4NULL 0
#define MPLS_LABEL_RTALERT 1
#define MPLS_LABEL_IPV6NULL 2
#define MPLS_LABEL_IMPLNULL 3
#define MPLS_LABEL_ENTROPY 7
#define MPLS_LABEL_GAL 13
#define MPLS_LABEL_OAMALERT 14
#define MPLS_LABEL_EXTENSION 15
#define MPLS_LABEL_FIRST_UNRESERVED 16
enum {
  MPLS_STATS_UNSPEC,
  MPLS_STATS_LINK,
  __MPLS_STATS_MAX,
};
#define MPLS_STATS_MAX (__MPLS_STATS_MAX - 1)
struct mpls_link_stats {
  __u64 rx_packets;
  __u64 tx_packets;
  __u64 rx_bytes;
  __u64 tx_bytes;
  __u64 rx_errors;
  __u64 tx_errors;
  __u64 rx_dropped;
  __u64 tx_dropped;
  __u64 rx_noroute;
};
#endif