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
#ifndef _IP6T_SRH_H
#define _IP6T_SRH_H
#include <linux/types.h>
#include <linux/netfilter.h>
#define IP6T_SRH_NEXTHDR 0x0001
#define IP6T_SRH_LEN_EQ 0x0002
#define IP6T_SRH_LEN_GT 0x0004
#define IP6T_SRH_LEN_LT 0x0008
#define IP6T_SRH_SEGS_EQ 0x0010
#define IP6T_SRH_SEGS_GT 0x0020
#define IP6T_SRH_SEGS_LT 0x0040
#define IP6T_SRH_LAST_EQ 0x0080
#define IP6T_SRH_LAST_GT 0x0100
#define IP6T_SRH_LAST_LT 0x0200
#define IP6T_SRH_TAG 0x0400
#define IP6T_SRH_PSID 0x0800
#define IP6T_SRH_NSID 0x1000
#define IP6T_SRH_LSID 0x2000
#define IP6T_SRH_MASK 0x3FFF
#define IP6T_SRH_INV_NEXTHDR 0x0001
#define IP6T_SRH_INV_LEN_EQ 0x0002
#define IP6T_SRH_INV_LEN_GT 0x0004
#define IP6T_SRH_INV_LEN_LT 0x0008
#define IP6T_SRH_INV_SEGS_EQ 0x0010
#define IP6T_SRH_INV_SEGS_GT 0x0020
#define IP6T_SRH_INV_SEGS_LT 0x0040
#define IP6T_SRH_INV_LAST_EQ 0x0080
#define IP6T_SRH_INV_LAST_GT 0x0100
#define IP6T_SRH_INV_LAST_LT 0x0200
#define IP6T_SRH_INV_TAG 0x0400
#define IP6T_SRH_INV_PSID 0x0800
#define IP6T_SRH_INV_NSID 0x1000
#define IP6T_SRH_INV_LSID 0x2000
#define IP6T_SRH_INV_MASK 0x3FFF
struct ip6t_srh {
  __u8 next_hdr;
  __u8 hdr_len;
  __u8 segs_left;
  __u8 last_entry;
  __u16 tag;
  __u16 mt_flags;
  __u16 mt_invflags;
};
struct ip6t_srh1 {
  __u8 next_hdr;
  __u8 hdr_len;
  __u8 segs_left;
  __u8 last_entry;
  __u16 tag;
  struct in6_addr psid_addr;
  struct in6_addr nsid_addr;
  struct in6_addr lsid_addr;
  struct in6_addr psid_msk;
  struct in6_addr nsid_msk;
  struct in6_addr lsid_msk;
  __u16 mt_flags;
  __u16 mt_invflags;
};
#endif