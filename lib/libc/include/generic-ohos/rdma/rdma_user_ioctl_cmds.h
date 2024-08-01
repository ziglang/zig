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
#ifndef RDMA_USER_IOCTL_CMDS_H
#define RDMA_USER_IOCTL_CMDS_H
#include <linux/types.h>
#include <linux/ioctl.h>
#define RDMA_IOCTL_MAGIC 0x1b
#define RDMA_VERBS_IOCTL _IOWR(RDMA_IOCTL_MAGIC, 1, struct ib_uverbs_ioctl_hdr)
enum {
  UVERBS_ATTR_F_MANDATORY = 1U << 0,
  UVERBS_ATTR_F_VALID_OUTPUT = 1U << 1,
};
struct ib_uverbs_attr {
  __u16 attr_id;
  __u16 len;
  __u16 flags;
  union {
    struct {
      __u8 elem_id;
      __u8 reserved;
    } enum_data;
    __u16 reserved;
  } attr_data;
  union {
    __aligned_u64 data;
    __s64 data_s64;
  };
};
struct ib_uverbs_ioctl_hdr {
  __u16 length;
  __u16 object_id;
  __u16 method_id;
  __u16 num_attrs;
  __aligned_u64 reserved1;
  __u32 driver_id;
  __u32 reserved2;
  struct ib_uverbs_attr attrs[0];
};
#endif