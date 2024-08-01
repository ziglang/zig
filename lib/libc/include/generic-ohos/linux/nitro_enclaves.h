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
#ifndef _UAPI_LINUX_NITRO_ENCLAVES_H_
#define _UAPI_LINUX_NITRO_ENCLAVES_H_
#include <linux/types.h>
#define NE_CREATE_VM _IOR(0xAE, 0x20, __u64)
#define NE_ADD_VCPU _IOWR(0xAE, 0x21, __u32)
#define NE_GET_IMAGE_LOAD_INFO _IOWR(0xAE, 0x22, struct ne_image_load_info)
#define NE_SET_USER_MEMORY_REGION _IOW(0xAE, 0x23, struct ne_user_memory_region)
#define NE_START_ENCLAVE _IOWR(0xAE, 0x24, struct ne_enclave_start_info)
#define NE_ERR_VCPU_ALREADY_USED (256)
#define NE_ERR_VCPU_NOT_IN_CPU_POOL (257)
#define NE_ERR_VCPU_INVALID_CPU_CORE (258)
#define NE_ERR_INVALID_MEM_REGION_SIZE (259)
#define NE_ERR_INVALID_MEM_REGION_ADDR (260)
#define NE_ERR_UNALIGNED_MEM_REGION_ADDR (261)
#define NE_ERR_MEM_REGION_ALREADY_USED (262)
#define NE_ERR_MEM_NOT_HUGE_PAGE (263)
#define NE_ERR_MEM_DIFFERENT_NUMA_NODE (264)
#define NE_ERR_MEM_MAX_REGIONS (265)
#define NE_ERR_NO_MEM_REGIONS_ADDED (266)
#define NE_ERR_NO_VCPUS_ADDED (267)
#define NE_ERR_ENCLAVE_MEM_MIN_SIZE (268)
#define NE_ERR_FULL_CORES_NOT_USED (269)
#define NE_ERR_NOT_IN_INIT_STATE (270)
#define NE_ERR_INVALID_VCPU (271)
#define NE_ERR_NO_CPUS_AVAIL_IN_POOL (272)
#define NE_ERR_INVALID_PAGE_SIZE (273)
#define NE_ERR_INVALID_FLAG_VALUE (274)
#define NE_ERR_INVALID_ENCLAVE_CID (275)
#define NE_EIF_IMAGE (0x01)
#define NE_IMAGE_LOAD_MAX_FLAG_VAL (0x02)
struct ne_image_load_info {
  __u64 flags;
  __u64 memory_offset;
};
#define NE_DEFAULT_MEMORY_REGION (0x00)
#define NE_MEMORY_REGION_MAX_FLAG_VAL (0x01)
struct ne_user_memory_region {
  __u64 flags;
  __u64 memory_size;
  __u64 userspace_addr;
};
#define NE_ENCLAVE_PRODUCTION_MODE (0x00)
#define NE_ENCLAVE_DEBUG_MODE (0x01)
#define NE_ENCLAVE_START_MAX_FLAG_VAL (0x02)
struct ne_enclave_start_info {
  __u64 flags;
  __u64 enclave_cid;
};
#endif