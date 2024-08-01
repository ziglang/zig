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
#ifndef _UAPI_LINUX_NVME_IOCTL_H
#define _UAPI_LINUX_NVME_IOCTL_H
#include <linux/types.h>
struct nvme_user_io {
  __u8 opcode;
  __u8 flags;
  __u16 control;
  __u16 nblocks;
  __u16 rsvd;
  __u64 metadata;
  __u64 addr;
  __u64 slba;
  __u32 dsmgmt;
  __u32 reftag;
  __u16 apptag;
  __u16 appmask;
};
struct nvme_passthru_cmd {
  __u8 opcode;
  __u8 flags;
  __u16 rsvd1;
  __u32 nsid;
  __u32 cdw2;
  __u32 cdw3;
  __u64 metadata;
  __u64 addr;
  __u32 metadata_len;
  __u32 data_len;
  __u32 cdw10;
  __u32 cdw11;
  __u32 cdw12;
  __u32 cdw13;
  __u32 cdw14;
  __u32 cdw15;
  __u32 timeout_ms;
  __u32 result;
};
struct nvme_passthru_cmd64 {
  __u8 opcode;
  __u8 flags;
  __u16 rsvd1;
  __u32 nsid;
  __u32 cdw2;
  __u32 cdw3;
  __u64 metadata;
  __u64 addr;
  __u32 metadata_len;
  __u32 data_len;
  __u32 cdw10;
  __u32 cdw11;
  __u32 cdw12;
  __u32 cdw13;
  __u32 cdw14;
  __u32 cdw15;
  __u32 timeout_ms;
  __u32 rsvd2;
  __u64 result;
};
#define nvme_admin_cmd nvme_passthru_cmd
#define NVME_IOCTL_ID _IO('N', 0x40)
#define NVME_IOCTL_ADMIN_CMD _IOWR('N', 0x41, struct nvme_admin_cmd)
#define NVME_IOCTL_SUBMIT_IO _IOW('N', 0x42, struct nvme_user_io)
#define NVME_IOCTL_IO_CMD _IOWR('N', 0x43, struct nvme_passthru_cmd)
#define NVME_IOCTL_RESET _IO('N', 0x44)
#define NVME_IOCTL_SUBSYS_RESET _IO('N', 0x45)
#define NVME_IOCTL_RESCAN _IO('N', 0x46)
#define NVME_IOCTL_ADMIN64_CMD _IOWR('N', 0x47, struct nvme_passthru_cmd64)
#define NVME_IOCTL_IO64_CMD _IOWR('N', 0x48, struct nvme_passthru_cmd64)
#endif