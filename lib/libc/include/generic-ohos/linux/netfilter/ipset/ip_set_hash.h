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
#ifndef _UAPI__IP_SET_HASH_H
#define _UAPI__IP_SET_HASH_H
#include <linux/netfilter/ipset/ip_set.h>
enum {
  IPSET_ERR_HASH_FULL = IPSET_ERR_TYPE_SPECIFIC,
  IPSET_ERR_HASH_ELEM,
  IPSET_ERR_INVALID_PROTO,
  IPSET_ERR_MISSING_PROTO,
  IPSET_ERR_HASH_RANGE_UNSUPPORTED,
  IPSET_ERR_HASH_RANGE,
};
#endif