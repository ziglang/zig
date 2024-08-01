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
#ifndef _UAPI_LINUX_SEG6_H
#define _UAPI_LINUX_SEG6_H
#include <linux/types.h>
#include <linux/in6.h>
struct ipv6_sr_hdr {
  __u8 nexthdr;
  __u8 hdrlen;
  __u8 type;
  __u8 segments_left;
  __u8 first_segment;
  __u8 flags;
  __u16 tag;
  struct in6_addr segments[0];
};
#define SR6_FLAG1_PROTECTED (1 << 6)
#define SR6_FLAG1_OAM (1 << 5)
#define SR6_FLAG1_ALERT (1 << 4)
#define SR6_FLAG1_HMAC (1 << 3)
#define SR6_TLV_INGRESS 1
#define SR6_TLV_EGRESS 2
#define SR6_TLV_OPAQUE 3
#define SR6_TLV_PADDING 4
#define SR6_TLV_HMAC 5
#define sr_has_hmac(srh) ((srh)->flags & SR6_FLAG1_HMAC)
struct sr6_tlv {
  __u8 type;
  __u8 len;
  __u8 data[0];
};
#endif