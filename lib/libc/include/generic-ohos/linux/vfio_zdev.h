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
#ifndef _VFIO_ZDEV_H_
#define _VFIO_ZDEV_H_
#include <linux/types.h>
#include <linux/vfio.h>
struct vfio_device_info_cap_zpci_base {
  struct vfio_info_cap_header header;
  __u64 start_dma;
  __u64 end_dma;
  __u16 pchid;
  __u16 vfn;
  __u16 fmb_length;
  __u8 pft;
  __u8 gid;
};
struct vfio_device_info_cap_zpci_group {
  struct vfio_info_cap_header header;
  __u64 dasm;
  __u64 msi_addr;
  __u64 flags;
#define VFIO_DEVICE_INFO_ZPCI_FLAG_REFRESH 1
  __u16 mui;
  __u16 noi;
  __u16 maxstbl;
  __u8 version;
};
struct vfio_device_info_cap_zpci_util {
  struct vfio_info_cap_header header;
  __u32 size;
  __u8 util_str[];
};
struct vfio_device_info_cap_zpci_pfip {
  struct vfio_info_cap_header header;
  __u32 size;
  __u8 pfip[];
};
#endif