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
#ifndef SCSI_NETLINK_FC_H
#define SCSI_NETLINK_FC_H
#include <linux/types.h>
#include <scsi/scsi_netlink.h>
#define FC_NL_ASYNC_EVENT 0x0100
#define FC_NL_MSGALIGN(len) (((len) + 7) & ~7)
struct fc_nl_event {
  struct scsi_nl_hdr snlh;
  __u64 seconds;
  __u64 vendor_id;
  __u16 host_no;
  __u16 event_datalen;
  __u32 event_num;
  __u32 event_code;
  __u32 event_data;
} __attribute__((aligned(sizeof(__u64))));
#endif