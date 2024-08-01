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
#ifndef _UAPI_LINUX_VIRTIO_IOMMU_H
#define _UAPI_LINUX_VIRTIO_IOMMU_H
#include <linux/types.h>
#define VIRTIO_IOMMU_F_INPUT_RANGE 0
#define VIRTIO_IOMMU_F_DOMAIN_RANGE 1
#define VIRTIO_IOMMU_F_MAP_UNMAP 2
#define VIRTIO_IOMMU_F_BYPASS 3
#define VIRTIO_IOMMU_F_PROBE 4
#define VIRTIO_IOMMU_F_MMIO 5
struct virtio_iommu_range_64 {
  __le64 start;
  __le64 end;
};
struct virtio_iommu_range_32 {
  __le32 start;
  __le32 end;
};
struct virtio_iommu_config {
  __le64 page_size_mask;
  struct virtio_iommu_range_64 input_range;
  struct virtio_iommu_range_32 domain_range;
  __le32 probe_size;
};
#define VIRTIO_IOMMU_T_ATTACH 0x01
#define VIRTIO_IOMMU_T_DETACH 0x02
#define VIRTIO_IOMMU_T_MAP 0x03
#define VIRTIO_IOMMU_T_UNMAP 0x04
#define VIRTIO_IOMMU_T_PROBE 0x05
#define VIRTIO_IOMMU_S_OK 0x00
#define VIRTIO_IOMMU_S_IOERR 0x01
#define VIRTIO_IOMMU_S_UNSUPP 0x02
#define VIRTIO_IOMMU_S_DEVERR 0x03
#define VIRTIO_IOMMU_S_INVAL 0x04
#define VIRTIO_IOMMU_S_RANGE 0x05
#define VIRTIO_IOMMU_S_NOENT 0x06
#define VIRTIO_IOMMU_S_FAULT 0x07
#define VIRTIO_IOMMU_S_NOMEM 0x08
struct virtio_iommu_req_head {
  __u8 type;
  __u8 reserved[3];
};
struct virtio_iommu_req_tail {
  __u8 status;
  __u8 reserved[3];
};
struct virtio_iommu_req_attach {
  struct virtio_iommu_req_head head;
  __le32 domain;
  __le32 endpoint;
  __u8 reserved[8];
  struct virtio_iommu_req_tail tail;
};
struct virtio_iommu_req_detach {
  struct virtio_iommu_req_head head;
  __le32 domain;
  __le32 endpoint;
  __u8 reserved[8];
  struct virtio_iommu_req_tail tail;
};
#define VIRTIO_IOMMU_MAP_F_READ (1 << 0)
#define VIRTIO_IOMMU_MAP_F_WRITE (1 << 1)
#define VIRTIO_IOMMU_MAP_F_MMIO (1 << 2)
#define VIRTIO_IOMMU_MAP_F_MASK (VIRTIO_IOMMU_MAP_F_READ | VIRTIO_IOMMU_MAP_F_WRITE | VIRTIO_IOMMU_MAP_F_MMIO)
struct virtio_iommu_req_map {
  struct virtio_iommu_req_head head;
  __le32 domain;
  __le64 virt_start;
  __le64 virt_end;
  __le64 phys_start;
  __le32 flags;
  struct virtio_iommu_req_tail tail;
};
struct virtio_iommu_req_unmap {
  struct virtio_iommu_req_head head;
  __le32 domain;
  __le64 virt_start;
  __le64 virt_end;
  __u8 reserved[4];
  struct virtio_iommu_req_tail tail;
};
#define VIRTIO_IOMMU_PROBE_T_NONE 0
#define VIRTIO_IOMMU_PROBE_T_RESV_MEM 1
#define VIRTIO_IOMMU_PROBE_T_MASK 0xfff
struct virtio_iommu_probe_property {
  __le16 type;
  __le16 length;
};
#define VIRTIO_IOMMU_RESV_MEM_T_RESERVED 0
#define VIRTIO_IOMMU_RESV_MEM_T_MSI 1
struct virtio_iommu_probe_resv_mem {
  struct virtio_iommu_probe_property head;
  __u8 subtype;
  __u8 reserved[3];
  __le64 start;
  __le64 end;
};
struct virtio_iommu_req_probe {
  struct virtio_iommu_req_head head;
  __le32 endpoint;
  __u8 reserved[64];
  __u8 properties[];
};
#define VIRTIO_IOMMU_FAULT_R_UNKNOWN 0
#define VIRTIO_IOMMU_FAULT_R_DOMAIN 1
#define VIRTIO_IOMMU_FAULT_R_MAPPING 2
#define VIRTIO_IOMMU_FAULT_F_READ (1 << 0)
#define VIRTIO_IOMMU_FAULT_F_WRITE (1 << 1)
#define VIRTIO_IOMMU_FAULT_F_EXEC (1 << 2)
#define VIRTIO_IOMMU_FAULT_F_ADDRESS (1 << 8)
struct virtio_iommu_fault {
  __u8 reason;
  __u8 reserved[3];
  __le32 flags;
  __le32 endpoint;
  __u8 reserved2[4];
  __le64 address;
};
#endif