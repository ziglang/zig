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
#ifndef _UAPI_NF_CONNTRACK_COMMON_H
#define _UAPI_NF_CONNTRACK_COMMON_H
enum ip_conntrack_info {
  IP_CT_ESTABLISHED,
  IP_CT_RELATED,
  IP_CT_NEW,
  IP_CT_IS_REPLY,
  IP_CT_ESTABLISHED_REPLY = IP_CT_ESTABLISHED + IP_CT_IS_REPLY,
  IP_CT_RELATED_REPLY = IP_CT_RELATED + IP_CT_IS_REPLY,
  IP_CT_NUMBER,
  IP_CT_NEW_REPLY = IP_CT_NUMBER,
};
#define NF_CT_STATE_INVALID_BIT (1 << 0)
#define NF_CT_STATE_BIT(ctinfo) (1 << ((ctinfo) % IP_CT_IS_REPLY + 1))
#define NF_CT_STATE_UNTRACKED_BIT (1 << 6)
enum ip_conntrack_status {
  IPS_EXPECTED_BIT = 0,
  IPS_EXPECTED = (1 << IPS_EXPECTED_BIT),
  IPS_SEEN_REPLY_BIT = 1,
  IPS_SEEN_REPLY = (1 << IPS_SEEN_REPLY_BIT),
  IPS_ASSURED_BIT = 2,
  IPS_ASSURED = (1 << IPS_ASSURED_BIT),
  IPS_CONFIRMED_BIT = 3,
  IPS_CONFIRMED = (1 << IPS_CONFIRMED_BIT),
  IPS_SRC_NAT_BIT = 4,
  IPS_SRC_NAT = (1 << IPS_SRC_NAT_BIT),
  IPS_DST_NAT_BIT = 5,
  IPS_DST_NAT = (1 << IPS_DST_NAT_BIT),
  IPS_NAT_MASK = (IPS_DST_NAT | IPS_SRC_NAT),
  IPS_SEQ_ADJUST_BIT = 6,
  IPS_SEQ_ADJUST = (1 << IPS_SEQ_ADJUST_BIT),
  IPS_SRC_NAT_DONE_BIT = 7,
  IPS_SRC_NAT_DONE = (1 << IPS_SRC_NAT_DONE_BIT),
  IPS_DST_NAT_DONE_BIT = 8,
  IPS_DST_NAT_DONE = (1 << IPS_DST_NAT_DONE_BIT),
  IPS_NAT_DONE_MASK = (IPS_DST_NAT_DONE | IPS_SRC_NAT_DONE),
  IPS_DYING_BIT = 9,
  IPS_DYING = (1 << IPS_DYING_BIT),
  IPS_FIXED_TIMEOUT_BIT = 10,
  IPS_FIXED_TIMEOUT = (1 << IPS_FIXED_TIMEOUT_BIT),
  IPS_TEMPLATE_BIT = 11,
  IPS_TEMPLATE = (1 << IPS_TEMPLATE_BIT),
  IPS_UNTRACKED_BIT = 12,
  IPS_UNTRACKED = (1 << IPS_UNTRACKED_BIT),
  IPS_HELPER_BIT = 13,
  IPS_HELPER = (1 << IPS_HELPER_BIT),
  IPS_OFFLOAD_BIT = 14,
  IPS_OFFLOAD = (1 << IPS_OFFLOAD_BIT),
  IPS_HW_OFFLOAD_BIT = 15,
  IPS_HW_OFFLOAD = (1 << IPS_HW_OFFLOAD_BIT),
  IPS_UNCHANGEABLE_MASK = (IPS_NAT_DONE_MASK | IPS_NAT_MASK | IPS_EXPECTED | IPS_CONFIRMED | IPS_DYING | IPS_SEQ_ADJUST | IPS_TEMPLATE | IPS_UNTRACKED | IPS_OFFLOAD | IPS_HW_OFFLOAD),
  __IPS_MAX_BIT = 16,
};
enum ip_conntrack_events {
  IPCT_NEW,
  IPCT_RELATED,
  IPCT_DESTROY,
  IPCT_REPLY,
  IPCT_ASSURED,
  IPCT_PROTOINFO,
  IPCT_HELPER,
  IPCT_MARK,
  IPCT_SEQADJ,
  IPCT_NATSEQADJ = IPCT_SEQADJ,
  IPCT_SECMARK,
  IPCT_LABEL,
  IPCT_SYNPROXY,
};
enum ip_conntrack_expect_events {
  IPEXP_NEW,
  IPEXP_DESTROY,
};
#define NF_CT_EXPECT_PERMANENT 0x1
#define NF_CT_EXPECT_INACTIVE 0x2
#define NF_CT_EXPECT_USERSPACE 0x4
#endif