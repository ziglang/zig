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
#ifndef _XT_CONNBYTES_H
#define _XT_CONNBYTES_H
#include <linux/types.h>
enum xt_connbytes_what {
  XT_CONNBYTES_PKTS,
  XT_CONNBYTES_BYTES,
  XT_CONNBYTES_AVGPKT,
};
enum xt_connbytes_direction {
  XT_CONNBYTES_DIR_ORIGINAL,
  XT_CONNBYTES_DIR_REPLY,
  XT_CONNBYTES_DIR_BOTH,
};
struct xt_connbytes_info {
  struct {
    __aligned_u64 from;
    __aligned_u64 to;
  } count;
  __u8 what;
  __u8 direction;
};
#endif