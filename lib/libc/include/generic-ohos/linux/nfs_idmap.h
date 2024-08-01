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
#ifndef _UAPINFS_IDMAP_H
#define _UAPINFS_IDMAP_H
#include <linux/types.h>
#define IDMAP_NAMESZ 128
#define IDMAP_TYPE_USER 0
#define IDMAP_TYPE_GROUP 1
#define IDMAP_CONV_IDTONAME 0
#define IDMAP_CONV_NAMETOID 1
#define IDMAP_STATUS_INVALIDMSG 0x01
#define IDMAP_STATUS_AGAIN 0x02
#define IDMAP_STATUS_LOOKUPFAIL 0x04
#define IDMAP_STATUS_SUCCESS 0x08
struct idmap_msg {
  __u8 im_type;
  __u8 im_conv;
  char im_name[IDMAP_NAMESZ];
  __u32 im_id;
  __u8 im_status;
};
#endif