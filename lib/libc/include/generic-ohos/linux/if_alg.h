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
#ifndef _LINUX_IF_ALG_H
#define _LINUX_IF_ALG_H
#include <linux/types.h>
struct sockaddr_alg {
  __u16 salg_family;
  __u8 salg_type[14];
  __u32 salg_feat;
  __u32 salg_mask;
  __u8 salg_name[64];
};
struct af_alg_iv {
  __u32 ivlen;
  __u8 iv[0];
};
#define ALG_SET_KEY 1
#define ALG_SET_IV 2
#define ALG_SET_OP 3
#define ALG_SET_AEAD_ASSOCLEN 4
#define ALG_SET_AEAD_AUTHSIZE 5
#define ALG_SET_DRBG_ENTROPY 6
#define ALG_OP_DECRYPT 0
#define ALG_OP_ENCRYPT 1
#endif