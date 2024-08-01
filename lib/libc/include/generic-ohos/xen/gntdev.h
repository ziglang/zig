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
#ifndef __LINUX_PUBLIC_GNTDEV_H__
#define __LINUX_PUBLIC_GNTDEV_H__
#include <linux/types.h>
struct ioctl_gntdev_grant_ref {
  __u32 domid;
  __u32 ref;
};
#define IOCTL_GNTDEV_MAP_GRANT_REF _IOC(_IOC_NONE, 'G', 0, sizeof(struct ioctl_gntdev_map_grant_ref))
struct ioctl_gntdev_map_grant_ref {
  __u32 count;
  __u32 pad;
  __u64 index;
  struct ioctl_gntdev_grant_ref refs[1];
};
#define IOCTL_GNTDEV_UNMAP_GRANT_REF _IOC(_IOC_NONE, 'G', 1, sizeof(struct ioctl_gntdev_unmap_grant_ref))
struct ioctl_gntdev_unmap_grant_ref {
  __u64 index;
  __u32 count;
  __u32 pad;
};
#define IOCTL_GNTDEV_GET_OFFSET_FOR_VADDR _IOC(_IOC_NONE, 'G', 2, sizeof(struct ioctl_gntdev_get_offset_for_vaddr))
struct ioctl_gntdev_get_offset_for_vaddr {
  __u64 vaddr;
  __u64 offset;
  __u32 count;
  __u32 pad;
};
#define IOCTL_GNTDEV_SET_MAX_GRANTS _IOC(_IOC_NONE, 'G', 3, sizeof(struct ioctl_gntdev_set_max_grants))
struct ioctl_gntdev_set_max_grants {
  __u32 count;
};
#define IOCTL_GNTDEV_SET_UNMAP_NOTIFY _IOC(_IOC_NONE, 'G', 7, sizeof(struct ioctl_gntdev_unmap_notify))
struct ioctl_gntdev_unmap_notify {
  __u64 index;
  __u32 action;
  __u32 event_channel_port;
};
struct gntdev_grant_copy_segment {
  union {
    void __user * virt;
    struct {
      grant_ref_t ref;
      __u16 offset;
      domid_t domid;
    } foreign;
  } source, dest;
  __u16 len;
  __u16 flags;
  __s16 status;
};
#define IOCTL_GNTDEV_GRANT_COPY _IOC(_IOC_NONE, 'G', 8, sizeof(struct ioctl_gntdev_grant_copy))
struct ioctl_gntdev_grant_copy {
  unsigned int count;
  struct gntdev_grant_copy_segment __user * segments;
};
#define UNMAP_NOTIFY_CLEAR_BYTE 0x1
#define UNMAP_NOTIFY_SEND_EVENT 0x2
#define GNTDEV_DMA_FLAG_WC (1 << 0)
#define GNTDEV_DMA_FLAG_COHERENT (1 << 1)
#define IOCTL_GNTDEV_DMABUF_EXP_FROM_REFS _IOC(_IOC_NONE, 'G', 9, sizeof(struct ioctl_gntdev_dmabuf_exp_from_refs))
struct ioctl_gntdev_dmabuf_exp_from_refs {
  __u32 flags;
  __u32 count;
  __u32 fd;
  __u32 domid;
  __u32 refs[1];
};
#define IOCTL_GNTDEV_DMABUF_EXP_WAIT_RELEASED _IOC(_IOC_NONE, 'G', 10, sizeof(struct ioctl_gntdev_dmabuf_exp_wait_released))
struct ioctl_gntdev_dmabuf_exp_wait_released {
  __u32 fd;
  __u32 wait_to_ms;
};
#define IOCTL_GNTDEV_DMABUF_IMP_TO_REFS _IOC(_IOC_NONE, 'G', 11, sizeof(struct ioctl_gntdev_dmabuf_imp_to_refs))
struct ioctl_gntdev_dmabuf_imp_to_refs {
  __u32 fd;
  __u32 count;
  __u32 domid;
  __u32 reserved;
  __u32 refs[1];
};
#define IOCTL_GNTDEV_DMABUF_IMP_RELEASE _IOC(_IOC_NONE, 'G', 12, sizeof(struct ioctl_gntdev_dmabuf_imp_release))
struct ioctl_gntdev_dmabuf_imp_release {
  __u32 fd;
  __u32 reserved;
};
#endif