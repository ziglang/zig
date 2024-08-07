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
#ifndef _UAPI_MISC_OCXL_H
#define _UAPI_MISC_OCXL_H
#include <linux/types.h>
#include <linux/ioctl.h>
enum ocxl_event_type {
  OCXL_AFU_EVENT_XSL_FAULT_ERROR = 0,
};
#define OCXL_KERNEL_EVENT_FLAG_LAST 0x0001
struct ocxl_kernel_event_header {
  __u16 type;
  __u16 flags;
  __u32 reserved;
};
struct ocxl_kernel_event_xsl_fault_error {
  __u64 addr;
  __u64 dsisr;
  __u64 count;
  __u64 reserved;
};
struct ocxl_ioctl_attach {
  __u64 amr;
  __u64 reserved1;
  __u64 reserved2;
  __u64 reserved3;
};
struct ocxl_ioctl_metadata {
  __u16 version;
  __u8 afu_version_major;
  __u8 afu_version_minor;
  __u32 pasid;
  __u64 pp_mmio_size;
  __u64 global_mmio_size;
  __u64 reserved[13];
};
struct ocxl_ioctl_p9_wait {
  __u16 thread_id;
  __u16 reserved1;
  __u32 reserved2;
  __u64 reserved3[3];
};
#define OCXL_IOCTL_FEATURES_FLAGS0_P9_WAIT 0x01
struct ocxl_ioctl_features {
  __u64 flags[4];
};
struct ocxl_ioctl_irq_fd {
  __u64 irq_offset;
  __s32 eventfd;
  __u32 reserved;
};
#define OCXL_MAGIC 0xCA
#define OCXL_IOCTL_ATTACH _IOW(OCXL_MAGIC, 0x10, struct ocxl_ioctl_attach)
#define OCXL_IOCTL_IRQ_ALLOC _IOR(OCXL_MAGIC, 0x11, __u64)
#define OCXL_IOCTL_IRQ_FREE _IOW(OCXL_MAGIC, 0x12, __u64)
#define OCXL_IOCTL_IRQ_SET_FD _IOW(OCXL_MAGIC, 0x13, struct ocxl_ioctl_irq_fd)
#define OCXL_IOCTL_GET_METADATA _IOR(OCXL_MAGIC, 0x14, struct ocxl_ioctl_metadata)
#define OCXL_IOCTL_ENABLE_P9_WAIT _IOR(OCXL_MAGIC, 0x15, struct ocxl_ioctl_p9_wait)
#define OCXL_IOCTL_GET_FEATURES _IOR(OCXL_MAGIC, 0x16, struct ocxl_ioctl_features)
#endif