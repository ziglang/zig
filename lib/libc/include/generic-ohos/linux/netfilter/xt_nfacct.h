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
#ifndef _XT_NFACCT_MATCH_H
#define _XT_NFACCT_MATCH_H
#include <linux/netfilter/nfnetlink_acct.h>
struct nf_acct;
struct xt_nfacct_match_info {
  char name[NFACCT_NAME_MAX];
  struct nf_acct * nfacct;
};
struct xt_nfacct_match_info_v1 {
  char name[NFACCT_NAME_MAX];
  struct nf_acct * nfacct __attribute__((aligned(8)));
};
#endif