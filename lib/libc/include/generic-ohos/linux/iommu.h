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
#ifndef _UAPI_IOMMU_H
#define _UAPI_IOMMU_H
#include <linux/types.h>
#define IOMMU_FAULT_PERM_READ (1 << 0)
#define IOMMU_FAULT_PERM_WRITE (1 << 1)
#define IOMMU_FAULT_PERM_EXEC (1 << 2)
#define IOMMU_FAULT_PERM_PRIV (1 << 3)
enum iommu_fault_type {
  IOMMU_FAULT_DMA_UNRECOV = 1,
  IOMMU_FAULT_PAGE_REQ,
};
enum iommu_fault_reason {
  IOMMU_FAULT_REASON_UNKNOWN = 0,
  IOMMU_FAULT_REASON_PASID_FETCH,
  IOMMU_FAULT_REASON_BAD_PASID_ENTRY,
  IOMMU_FAULT_REASON_PASID_INVALID,
  IOMMU_FAULT_REASON_WALK_EABT,
  IOMMU_FAULT_REASON_PTE_FETCH,
  IOMMU_FAULT_REASON_PERMISSION,
  IOMMU_FAULT_REASON_ACCESS,
  IOMMU_FAULT_REASON_OOR_ADDRESS,
};
struct iommu_fault_unrecoverable {
  __u32 reason;
#define IOMMU_FAULT_UNRECOV_PASID_VALID (1 << 0)
#define IOMMU_FAULT_UNRECOV_ADDR_VALID (1 << 1)
#define IOMMU_FAULT_UNRECOV_FETCH_ADDR_VALID (1 << 2)
  __u32 flags;
  __u32 pasid;
  __u32 perm;
  __u64 addr;
  __u64 fetch_addr;
};
struct iommu_fault_page_request {
#define IOMMU_FAULT_PAGE_REQUEST_PASID_VALID (1 << 0)
#define IOMMU_FAULT_PAGE_REQUEST_LAST_PAGE (1 << 1)
#define IOMMU_FAULT_PAGE_REQUEST_PRIV_DATA (1 << 2)
#define IOMMU_FAULT_PAGE_RESPONSE_NEEDS_PASID (1 << 3)
  __u32 flags;
  __u32 pasid;
  __u32 grpid;
  __u32 perm;
  __u64 addr;
  __u64 private_data[2];
};
struct iommu_fault {
  __u32 type;
  __u32 padding;
  union {
    struct iommu_fault_unrecoverable event;
    struct iommu_fault_page_request prm;
    __u8 padding2[56];
  };
};
enum iommu_page_response_code {
  IOMMU_PAGE_RESP_SUCCESS = 0,
  IOMMU_PAGE_RESP_INVALID,
  IOMMU_PAGE_RESP_FAILURE,
};
struct iommu_page_response {
  __u32 argsz;
#define IOMMU_PAGE_RESP_VERSION_1 1
  __u32 version;
#define IOMMU_PAGE_RESP_PASID_VALID (1 << 0)
  __u32 flags;
  __u32 pasid;
  __u32 grpid;
  __u32 code;
};
enum iommu_inv_granularity {
  IOMMU_INV_GRANU_DOMAIN,
  IOMMU_INV_GRANU_PASID,
  IOMMU_INV_GRANU_ADDR,
  IOMMU_INV_GRANU_NR,
};
struct iommu_inv_addr_info {
#define IOMMU_INV_ADDR_FLAGS_PASID (1 << 0)
#define IOMMU_INV_ADDR_FLAGS_ARCHID (1 << 1)
#define IOMMU_INV_ADDR_FLAGS_LEAF (1 << 2)
  __u32 flags;
  __u32 archid;
  __u64 pasid;
  __u64 addr;
  __u64 granule_size;
  __u64 nb_granules;
};
struct iommu_inv_pasid_info {
#define IOMMU_INV_PASID_FLAGS_PASID (1 << 0)
#define IOMMU_INV_PASID_FLAGS_ARCHID (1 << 1)
  __u32 flags;
  __u32 archid;
  __u64 pasid;
};
struct iommu_cache_invalidate_info {
  __u32 argsz;
#define IOMMU_CACHE_INVALIDATE_INFO_VERSION_1 1
  __u32 version;
#define IOMMU_CACHE_INV_TYPE_IOTLB (1 << 0)
#define IOMMU_CACHE_INV_TYPE_DEV_IOTLB (1 << 1)
#define IOMMU_CACHE_INV_TYPE_PASID (1 << 2)
#define IOMMU_CACHE_INV_TYPE_NR (3)
  __u8 cache;
  __u8 granularity;
  __u8 padding[6];
  union {
    struct iommu_inv_pasid_info pasid_info;
    struct iommu_inv_addr_info addr_info;
  } granu;
};
struct iommu_gpasid_bind_data_vtd {
#define IOMMU_SVA_VTD_GPASID_SRE (1 << 0)
#define IOMMU_SVA_VTD_GPASID_EAFE (1 << 1)
#define IOMMU_SVA_VTD_GPASID_PCD (1 << 2)
#define IOMMU_SVA_VTD_GPASID_PWT (1 << 3)
#define IOMMU_SVA_VTD_GPASID_EMTE (1 << 4)
#define IOMMU_SVA_VTD_GPASID_CD (1 << 5)
#define IOMMU_SVA_VTD_GPASID_LAST (1 << 6)
  __u64 flags;
  __u32 pat;
  __u32 emt;
};
#define IOMMU_SVA_VTD_GPASID_MTS_MASK (IOMMU_SVA_VTD_GPASID_CD | IOMMU_SVA_VTD_GPASID_EMTE | IOMMU_SVA_VTD_GPASID_PCD | IOMMU_SVA_VTD_GPASID_PWT)
struct iommu_gpasid_bind_data {
  __u32 argsz;
#define IOMMU_GPASID_BIND_VERSION_1 1
  __u32 version;
#define IOMMU_PASID_FORMAT_INTEL_VTD 1
#define IOMMU_PASID_FORMAT_LAST 2
  __u32 format;
  __u32 addr_width;
#define IOMMU_SVA_GPASID_VAL (1 << 0)
  __u64 flags;
  __u64 gpgd;
  __u64 hpasid;
  __u64 gpasid;
  __u8 padding[8];
  union {
    struct iommu_gpasid_bind_data_vtd vtd;
  } vendor;
};
#endif