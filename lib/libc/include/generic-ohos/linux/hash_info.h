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
#ifndef _UAPI_LINUX_HASH_INFO_H
#define _UAPI_LINUX_HASH_INFO_H
enum hash_algo {
  HASH_ALGO_MD4,
  HASH_ALGO_MD5,
  HASH_ALGO_SHA1,
  HASH_ALGO_RIPE_MD_160,
  HASH_ALGO_SHA256,
  HASH_ALGO_SHA384,
  HASH_ALGO_SHA512,
  HASH_ALGO_SHA224,
  HASH_ALGO_RIPE_MD_128,
  HASH_ALGO_RIPE_MD_256,
  HASH_ALGO_RIPE_MD_320,
  HASH_ALGO_WP_256,
  HASH_ALGO_WP_384,
  HASH_ALGO_WP_512,
  HASH_ALGO_TGR_128,
  HASH_ALGO_TGR_160,
  HASH_ALGO_TGR_192,
  HASH_ALGO_SM3_256,
  HASH_ALGO_STREEBOG_256,
  HASH_ALGO_STREEBOG_512,
  HASH_ALGO__LAST
};
#endif