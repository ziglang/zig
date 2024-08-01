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
#ifndef _UAPI_NFNL_ACCT_H_
#define _UAPI_NFNL_ACCT_H_
#ifndef NFACCT_NAME_MAX
#define NFACCT_NAME_MAX 32
#endif
enum nfnl_acct_msg_types {
  NFNL_MSG_ACCT_NEW,
  NFNL_MSG_ACCT_GET,
  NFNL_MSG_ACCT_GET_CTRZERO,
  NFNL_MSG_ACCT_DEL,
  NFNL_MSG_ACCT_OVERQUOTA,
  NFNL_MSG_ACCT_MAX
};
enum nfnl_acct_flags {
  NFACCT_F_QUOTA_PKTS = (1 << 0),
  NFACCT_F_QUOTA_BYTES = (1 << 1),
  NFACCT_F_OVERQUOTA = (1 << 2),
};
enum nfnl_acct_type {
  NFACCT_UNSPEC,
  NFACCT_NAME,
  NFACCT_PKTS,
  NFACCT_BYTES,
  NFACCT_USE,
  NFACCT_FLAGS,
  NFACCT_QUOTA,
  NFACCT_FILTER,
  NFACCT_PAD,
  __NFACCT_MAX
};
#define NFACCT_MAX (__NFACCT_MAX - 1)
enum nfnl_attr_filter_type {
  NFACCT_FILTER_UNSPEC,
  NFACCT_FILTER_MASK,
  NFACCT_FILTER_VALUE,
  __NFACCT_FILTER_MAX
};
#define NFACCT_FILTER_MAX (__NFACCT_FILTER_MAX - 1)
#endif