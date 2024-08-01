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
#ifndef _NFNL_CTHELPER_H_
#define _NFNL_CTHELPER_H_
#define NFCT_HELPER_STATUS_DISABLED 0
#define NFCT_HELPER_STATUS_ENABLED 1
enum nfnl_acct_msg_types {
  NFNL_MSG_CTHELPER_NEW,
  NFNL_MSG_CTHELPER_GET,
  NFNL_MSG_CTHELPER_DEL,
  NFNL_MSG_CTHELPER_MAX
};
enum nfnl_cthelper_type {
  NFCTH_UNSPEC,
  NFCTH_NAME,
  NFCTH_TUPLE,
  NFCTH_QUEUE_NUM,
  NFCTH_POLICY,
  NFCTH_PRIV_DATA_LEN,
  NFCTH_STATUS,
  __NFCTH_MAX
};
#define NFCTH_MAX (__NFCTH_MAX - 1)
enum nfnl_cthelper_policy_type {
  NFCTH_POLICY_SET_UNSPEC,
  NFCTH_POLICY_SET_NUM,
  NFCTH_POLICY_SET,
  NFCTH_POLICY_SET1 = NFCTH_POLICY_SET,
  NFCTH_POLICY_SET2,
  NFCTH_POLICY_SET3,
  NFCTH_POLICY_SET4,
  __NFCTH_POLICY_SET_MAX
};
#define NFCTH_POLICY_SET_MAX (__NFCTH_POLICY_SET_MAX - 1)
enum nfnl_cthelper_pol_type {
  NFCTH_POLICY_UNSPEC,
  NFCTH_POLICY_NAME,
  NFCTH_POLICY_EXPECT_MAX,
  NFCTH_POLICY_EXPECT_TIMEOUT,
  __NFCTH_POLICY_MAX
};
#define NFCTH_POLICY_MAX (__NFCTH_POLICY_MAX - 1)
enum nfnl_cthelper_tuple_type {
  NFCTH_TUPLE_UNSPEC,
  NFCTH_TUPLE_L3PROTONUM,
  NFCTH_TUPLE_L4PROTONUM,
  __NFCTH_TUPLE_MAX,
};
#define NFCTH_TUPLE_MAX (__NFCTH_TUPLE_MAX - 1)
#endif