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
#ifndef _UAPI_NFNETLINK_H
#define _UAPI_NFNETLINK_H
#include <linux/types.h>
#include <linux/netfilter/nfnetlink_compat.h>
enum nfnetlink_groups {
  NFNLGRP_NONE,
#define NFNLGRP_NONE NFNLGRP_NONE
  NFNLGRP_CONNTRACK_NEW,
#define NFNLGRP_CONNTRACK_NEW NFNLGRP_CONNTRACK_NEW
  NFNLGRP_CONNTRACK_UPDATE,
#define NFNLGRP_CONNTRACK_UPDATE NFNLGRP_CONNTRACK_UPDATE
  NFNLGRP_CONNTRACK_DESTROY,
#define NFNLGRP_CONNTRACK_DESTROY NFNLGRP_CONNTRACK_DESTROY
  NFNLGRP_CONNTRACK_EXP_NEW,
#define NFNLGRP_CONNTRACK_EXP_NEW NFNLGRP_CONNTRACK_EXP_NEW
  NFNLGRP_CONNTRACK_EXP_UPDATE,
#define NFNLGRP_CONNTRACK_EXP_UPDATE NFNLGRP_CONNTRACK_EXP_UPDATE
  NFNLGRP_CONNTRACK_EXP_DESTROY,
#define NFNLGRP_CONNTRACK_EXP_DESTROY NFNLGRP_CONNTRACK_EXP_DESTROY
  NFNLGRP_NFTABLES,
#define NFNLGRP_NFTABLES NFNLGRP_NFTABLES
  NFNLGRP_ACCT_QUOTA,
#define NFNLGRP_ACCT_QUOTA NFNLGRP_ACCT_QUOTA
  NFNLGRP_NFTRACE,
#define NFNLGRP_NFTRACE NFNLGRP_NFTRACE
  __NFNLGRP_MAX,
};
#define NFNLGRP_MAX (__NFNLGRP_MAX - 1)
struct nfgenmsg {
  __u8 nfgen_family;
  __u8 version;
  __be16 res_id;
};
#define NFNETLINK_V0 0
#define NFNL_SUBSYS_ID(x) ((x & 0xff00) >> 8)
#define NFNL_MSG_TYPE(x) (x & 0x00ff)
#define NFNL_SUBSYS_NONE 0
#define NFNL_SUBSYS_CTNETLINK 1
#define NFNL_SUBSYS_CTNETLINK_EXP 2
#define NFNL_SUBSYS_QUEUE 3
#define NFNL_SUBSYS_ULOG 4
#define NFNL_SUBSYS_OSF 5
#define NFNL_SUBSYS_IPSET 6
#define NFNL_SUBSYS_ACCT 7
#define NFNL_SUBSYS_CTNETLINK_TIMEOUT 8
#define NFNL_SUBSYS_CTHELPER 9
#define NFNL_SUBSYS_NFTABLES 10
#define NFNL_SUBSYS_NFT_COMPAT 11
#define NFNL_SUBSYS_COUNT 12
#define NFNL_MSG_BATCH_BEGIN NLMSG_MIN_TYPE
#define NFNL_MSG_BATCH_END NLMSG_MIN_TYPE + 1
enum nfnl_batch_attributes {
  NFNL_BATCH_UNSPEC,
  NFNL_BATCH_GENID,
  __NFNL_BATCH_MAX
};
#define NFNL_BATCH_MAX (__NFNL_BATCH_MAX - 1)
#endif