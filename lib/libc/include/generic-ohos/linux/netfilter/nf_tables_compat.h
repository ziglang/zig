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
#ifndef _NFT_COMPAT_NFNETLINK_H_
#define _NFT_COMPAT_NFNETLINK_H_
enum nft_target_attributes {
  NFTA_TARGET_UNSPEC,
  NFTA_TARGET_NAME,
  NFTA_TARGET_REV,
  NFTA_TARGET_INFO,
  __NFTA_TARGET_MAX
};
#define NFTA_TARGET_MAX (__NFTA_TARGET_MAX - 1)
enum nft_match_attributes {
  NFTA_MATCH_UNSPEC,
  NFTA_MATCH_NAME,
  NFTA_MATCH_REV,
  NFTA_MATCH_INFO,
  __NFTA_MATCH_MAX
};
#define NFTA_MATCH_MAX (__NFTA_MATCH_MAX - 1)
#define NFT_COMPAT_NAME_MAX 32
enum {
  NFNL_MSG_COMPAT_GET,
  NFNL_MSG_COMPAT_MAX
};
enum {
  NFTA_COMPAT_UNSPEC = 0,
  NFTA_COMPAT_NAME,
  NFTA_COMPAT_REV,
  NFTA_COMPAT_TYPE,
  __NFTA_COMPAT_MAX,
};
#define NFTA_COMPAT_MAX (__NFTA_COMPAT_MAX - 1)
#endif