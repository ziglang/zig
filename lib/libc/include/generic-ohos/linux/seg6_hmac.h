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
#ifndef _UAPI_LINUX_SEG6_HMAC_H
#define _UAPI_LINUX_SEG6_HMAC_H
#include <linux/types.h>
#include <linux/seg6.h>
#define SEG6_HMAC_SECRET_LEN 64
#define SEG6_HMAC_FIELD_LEN 32
struct sr6_tlv_hmac {
  struct sr6_tlv tlvhdr;
  __u16 reserved;
  __be32 hmackeyid;
  __u8 hmac[SEG6_HMAC_FIELD_LEN];
};
enum {
  SEG6_HMAC_ALGO_SHA1 = 1,
  SEG6_HMAC_ALGO_SHA256 = 2,
};
#endif