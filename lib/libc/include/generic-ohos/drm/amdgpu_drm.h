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
#ifndef __AMDGPU_DRM_H__
#define __AMDGPU_DRM_H__
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_AMDGPU_GEM_CREATE 0x00
#define DRM_AMDGPU_GEM_MMAP 0x01
#define DRM_AMDGPU_CTX 0x02
#define DRM_AMDGPU_BO_LIST 0x03
#define DRM_AMDGPU_CS 0x04
#define DRM_AMDGPU_INFO 0x05
#define DRM_AMDGPU_GEM_METADATA 0x06
#define DRM_AMDGPU_GEM_WAIT_IDLE 0x07
#define DRM_AMDGPU_GEM_VA 0x08
#define DRM_AMDGPU_WAIT_CS 0x09
#define DRM_AMDGPU_GEM_OP 0x10
#define DRM_AMDGPU_GEM_USERPTR 0x11
#define DRM_AMDGPU_WAIT_FENCES 0x12
#define DRM_AMDGPU_VM 0x13
#define DRM_AMDGPU_FENCE_TO_HANDLE 0x14
#define DRM_AMDGPU_SCHED 0x15
#define DRM_IOCTL_AMDGPU_GEM_CREATE DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_GEM_CREATE, union drm_amdgpu_gem_create)
#define DRM_IOCTL_AMDGPU_GEM_MMAP DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_GEM_MMAP, union drm_amdgpu_gem_mmap)
#define DRM_IOCTL_AMDGPU_CTX DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_CTX, union drm_amdgpu_ctx)
#define DRM_IOCTL_AMDGPU_BO_LIST DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_BO_LIST, union drm_amdgpu_bo_list)
#define DRM_IOCTL_AMDGPU_CS DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_CS, union drm_amdgpu_cs)
#define DRM_IOCTL_AMDGPU_INFO DRM_IOW(DRM_COMMAND_BASE + DRM_AMDGPU_INFO, struct drm_amdgpu_info)
#define DRM_IOCTL_AMDGPU_GEM_METADATA DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_GEM_METADATA, struct drm_amdgpu_gem_metadata)
#define DRM_IOCTL_AMDGPU_GEM_WAIT_IDLE DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_GEM_WAIT_IDLE, union drm_amdgpu_gem_wait_idle)
#define DRM_IOCTL_AMDGPU_GEM_VA DRM_IOW(DRM_COMMAND_BASE + DRM_AMDGPU_GEM_VA, struct drm_amdgpu_gem_va)
#define DRM_IOCTL_AMDGPU_WAIT_CS DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_WAIT_CS, union drm_amdgpu_wait_cs)
#define DRM_IOCTL_AMDGPU_GEM_OP DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_GEM_OP, struct drm_amdgpu_gem_op)
#define DRM_IOCTL_AMDGPU_GEM_USERPTR DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_GEM_USERPTR, struct drm_amdgpu_gem_userptr)
#define DRM_IOCTL_AMDGPU_WAIT_FENCES DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_WAIT_FENCES, union drm_amdgpu_wait_fences)
#define DRM_IOCTL_AMDGPU_VM DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_VM, union drm_amdgpu_vm)
#define DRM_IOCTL_AMDGPU_FENCE_TO_HANDLE DRM_IOWR(DRM_COMMAND_BASE + DRM_AMDGPU_FENCE_TO_HANDLE, union drm_amdgpu_fence_to_handle)
#define DRM_IOCTL_AMDGPU_SCHED DRM_IOW(DRM_COMMAND_BASE + DRM_AMDGPU_SCHED, union drm_amdgpu_sched)
#define AMDGPU_GEM_DOMAIN_CPU 0x1
#define AMDGPU_GEM_DOMAIN_GTT 0x2
#define AMDGPU_GEM_DOMAIN_VRAM 0x4
#define AMDGPU_GEM_DOMAIN_GDS 0x8
#define AMDGPU_GEM_DOMAIN_GWS 0x10
#define AMDGPU_GEM_DOMAIN_OA 0x20
#define AMDGPU_GEM_DOMAIN_MASK (AMDGPU_GEM_DOMAIN_CPU | AMDGPU_GEM_DOMAIN_GTT | AMDGPU_GEM_DOMAIN_VRAM | AMDGPU_GEM_DOMAIN_GDS | AMDGPU_GEM_DOMAIN_GWS | AMDGPU_GEM_DOMAIN_OA)
#define AMDGPU_GEM_CREATE_CPU_ACCESS_REQUIRED (1 << 0)
#define AMDGPU_GEM_CREATE_NO_CPU_ACCESS (1 << 1)
#define AMDGPU_GEM_CREATE_CPU_GTT_USWC (1 << 2)
#define AMDGPU_GEM_CREATE_VRAM_CLEARED (1 << 3)
#define AMDGPU_GEM_CREATE_SHADOW (1 << 4)
#define AMDGPU_GEM_CREATE_VRAM_CONTIGUOUS (1 << 5)
#define AMDGPU_GEM_CREATE_VM_ALWAYS_VALID (1 << 6)
#define AMDGPU_GEM_CREATE_EXPLICIT_SYNC (1 << 7)
#define AMDGPU_GEM_CREATE_CP_MQD_GFX9 (1 << 8)
#define AMDGPU_GEM_CREATE_VRAM_WIPE_ON_RELEASE (1 << 9)
#define AMDGPU_GEM_CREATE_ENCRYPTED (1 << 10)
struct drm_amdgpu_gem_create_in {
  __u64 bo_size;
  __u64 alignment;
  __u64 domains;
  __u64 domain_flags;
};
struct drm_amdgpu_gem_create_out {
  __u32 handle;
  __u32 _pad;
};
union drm_amdgpu_gem_create {
  struct drm_amdgpu_gem_create_in in;
  struct drm_amdgpu_gem_create_out out;
};
#define AMDGPU_BO_LIST_OP_CREATE 0
#define AMDGPU_BO_LIST_OP_DESTROY 1
#define AMDGPU_BO_LIST_OP_UPDATE 2
struct drm_amdgpu_bo_list_in {
  __u32 operation;
  __u32 list_handle;
  __u32 bo_number;
  __u32 bo_info_size;
  __u64 bo_info_ptr;
};
struct drm_amdgpu_bo_list_entry {
  __u32 bo_handle;
  __u32 bo_priority;
};
struct drm_amdgpu_bo_list_out {
  __u32 list_handle;
  __u32 _pad;
};
union drm_amdgpu_bo_list {
  struct drm_amdgpu_bo_list_in in;
  struct drm_amdgpu_bo_list_out out;
};
#define AMDGPU_CTX_OP_ALLOC_CTX 1
#define AMDGPU_CTX_OP_FREE_CTX 2
#define AMDGPU_CTX_OP_QUERY_STATE 3
#define AMDGPU_CTX_OP_QUERY_STATE2 4
#define AMDGPU_CTX_NO_RESET 0
#define AMDGPU_CTX_GUILTY_RESET 1
#define AMDGPU_CTX_INNOCENT_RESET 2
#define AMDGPU_CTX_UNKNOWN_RESET 3
#define AMDGPU_CTX_QUERY2_FLAGS_RESET (1 << 0)
#define AMDGPU_CTX_QUERY2_FLAGS_VRAMLOST (1 << 1)
#define AMDGPU_CTX_QUERY2_FLAGS_GUILTY (1 << 2)
#define AMDGPU_CTX_QUERY2_FLAGS_RAS_CE (1 << 3)
#define AMDGPU_CTX_QUERY2_FLAGS_RAS_UE (1 << 4)
#define AMDGPU_CTX_PRIORITY_UNSET - 2048
#define AMDGPU_CTX_PRIORITY_VERY_LOW - 1023
#define AMDGPU_CTX_PRIORITY_LOW - 512
#define AMDGPU_CTX_PRIORITY_NORMAL 0
#define AMDGPU_CTX_PRIORITY_HIGH 512
#define AMDGPU_CTX_PRIORITY_VERY_HIGH 1023
struct drm_amdgpu_ctx_in {
  __u32 op;
  __u32 flags;
  __u32 ctx_id;
  __s32 priority;
};
union drm_amdgpu_ctx_out {
  struct {
    __u32 ctx_id;
    __u32 _pad;
  } alloc;
  struct {
    __u64 flags;
    __u32 hangs;
    __u32 reset_status;
  } state;
};
union drm_amdgpu_ctx {
  struct drm_amdgpu_ctx_in in;
  union drm_amdgpu_ctx_out out;
};
#define AMDGPU_VM_OP_RESERVE_VMID 1
#define AMDGPU_VM_OP_UNRESERVE_VMID 2
struct drm_amdgpu_vm_in {
  __u32 op;
  __u32 flags;
};
struct drm_amdgpu_vm_out {
  __u64 flags;
};
union drm_amdgpu_vm {
  struct drm_amdgpu_vm_in in;
  struct drm_amdgpu_vm_out out;
};
#define AMDGPU_SCHED_OP_PROCESS_PRIORITY_OVERRIDE 1
#define AMDGPU_SCHED_OP_CONTEXT_PRIORITY_OVERRIDE 2
struct drm_amdgpu_sched_in {
  __u32 op;
  __u32 fd;
  __s32 priority;
  __u32 ctx_id;
};
union drm_amdgpu_sched {
  struct drm_amdgpu_sched_in in;
};
#define AMDGPU_GEM_USERPTR_READONLY (1 << 0)
#define AMDGPU_GEM_USERPTR_ANONONLY (1 << 1)
#define AMDGPU_GEM_USERPTR_VALIDATE (1 << 2)
#define AMDGPU_GEM_USERPTR_REGISTER (1 << 3)
struct drm_amdgpu_gem_userptr {
  __u64 addr;
  __u64 size;
  __u32 flags;
  __u32 handle;
};
#define AMDGPU_TILING_ARRAY_MODE_SHIFT 0
#define AMDGPU_TILING_ARRAY_MODE_MASK 0xf
#define AMDGPU_TILING_PIPE_CONFIG_SHIFT 4
#define AMDGPU_TILING_PIPE_CONFIG_MASK 0x1f
#define AMDGPU_TILING_TILE_SPLIT_SHIFT 9
#define AMDGPU_TILING_TILE_SPLIT_MASK 0x7
#define AMDGPU_TILING_MICRO_TILE_MODE_SHIFT 12
#define AMDGPU_TILING_MICRO_TILE_MODE_MASK 0x7
#define AMDGPU_TILING_BANK_WIDTH_SHIFT 15
#define AMDGPU_TILING_BANK_WIDTH_MASK 0x3
#define AMDGPU_TILING_BANK_HEIGHT_SHIFT 17
#define AMDGPU_TILING_BANK_HEIGHT_MASK 0x3
#define AMDGPU_TILING_MACRO_TILE_ASPECT_SHIFT 19
#define AMDGPU_TILING_MACRO_TILE_ASPECT_MASK 0x3
#define AMDGPU_TILING_NUM_BANKS_SHIFT 21
#define AMDGPU_TILING_NUM_BANKS_MASK 0x3
#define AMDGPU_TILING_SWIZZLE_MODE_SHIFT 0
#define AMDGPU_TILING_SWIZZLE_MODE_MASK 0x1f
#define AMDGPU_TILING_DCC_OFFSET_256B_SHIFT 5
#define AMDGPU_TILING_DCC_OFFSET_256B_MASK 0xFFFFFF
#define AMDGPU_TILING_DCC_PITCH_MAX_SHIFT 29
#define AMDGPU_TILING_DCC_PITCH_MAX_MASK 0x3FFF
#define AMDGPU_TILING_DCC_INDEPENDENT_64B_SHIFT 43
#define AMDGPU_TILING_DCC_INDEPENDENT_64B_MASK 0x1
#define AMDGPU_TILING_DCC_INDEPENDENT_128B_SHIFT 44
#define AMDGPU_TILING_DCC_INDEPENDENT_128B_MASK 0x1
#define AMDGPU_TILING_SCANOUT_SHIFT 63
#define AMDGPU_TILING_SCANOUT_MASK 0x1
#define AMDGPU_TILING_SET(field,value) (((__u64) (value) & AMDGPU_TILING_ ##field ##_MASK) << AMDGPU_TILING_ ##field ##_SHIFT)
#define AMDGPU_TILING_GET(value,field) (((__u64) (value) >> AMDGPU_TILING_ ##field ##_SHIFT) & AMDGPU_TILING_ ##field ##_MASK)
#define AMDGPU_GEM_METADATA_OP_SET_METADATA 1
#define AMDGPU_GEM_METADATA_OP_GET_METADATA 2
struct drm_amdgpu_gem_metadata {
  __u32 handle;
  __u32 op;
  struct {
    __u64 flags;
    __u64 tiling_info;
    __u32 data_size_bytes;
    __u32 data[64];
  } data;
};
struct drm_amdgpu_gem_mmap_in {
  __u32 handle;
  __u32 _pad;
};
struct drm_amdgpu_gem_mmap_out {
  __u64 addr_ptr;
};
union drm_amdgpu_gem_mmap {
  struct drm_amdgpu_gem_mmap_in in;
  struct drm_amdgpu_gem_mmap_out out;
};
struct drm_amdgpu_gem_wait_idle_in {
  __u32 handle;
  __u32 flags;
  __u64 timeout;
};
struct drm_amdgpu_gem_wait_idle_out {
  __u32 status;
  __u32 domain;
};
union drm_amdgpu_gem_wait_idle {
  struct drm_amdgpu_gem_wait_idle_in in;
  struct drm_amdgpu_gem_wait_idle_out out;
};
struct drm_amdgpu_wait_cs_in {
  __u64 handle;
  __u64 timeout;
  __u32 ip_type;
  __u32 ip_instance;
  __u32 ring;
  __u32 ctx_id;
};
struct drm_amdgpu_wait_cs_out {
  __u64 status;
};
union drm_amdgpu_wait_cs {
  struct drm_amdgpu_wait_cs_in in;
  struct drm_amdgpu_wait_cs_out out;
};
struct drm_amdgpu_fence {
  __u32 ctx_id;
  __u32 ip_type;
  __u32 ip_instance;
  __u32 ring;
  __u64 seq_no;
};
struct drm_amdgpu_wait_fences_in {
  __u64 fences;
  __u32 fence_count;
  __u32 wait_all;
  __u64 timeout_ns;
};
struct drm_amdgpu_wait_fences_out {
  __u32 status;
  __u32 first_signaled;
};
union drm_amdgpu_wait_fences {
  struct drm_amdgpu_wait_fences_in in;
  struct drm_amdgpu_wait_fences_out out;
};
#define AMDGPU_GEM_OP_GET_GEM_CREATE_INFO 0
#define AMDGPU_GEM_OP_SET_PLACEMENT 1
struct drm_amdgpu_gem_op {
  __u32 handle;
  __u32 op;
  __u64 value;
};
#define AMDGPU_VA_OP_MAP 1
#define AMDGPU_VA_OP_UNMAP 2
#define AMDGPU_VA_OP_CLEAR 3
#define AMDGPU_VA_OP_REPLACE 4
#define AMDGPU_VM_DELAY_UPDATE (1 << 0)
#define AMDGPU_VM_PAGE_READABLE (1 << 1)
#define AMDGPU_VM_PAGE_WRITEABLE (1 << 2)
#define AMDGPU_VM_PAGE_EXECUTABLE (1 << 3)
#define AMDGPU_VM_PAGE_PRT (1 << 4)
#define AMDGPU_VM_MTYPE_MASK (0xf << 5)
#define AMDGPU_VM_MTYPE_DEFAULT (0 << 5)
#define AMDGPU_VM_MTYPE_NC (1 << 5)
#define AMDGPU_VM_MTYPE_WC (2 << 5)
#define AMDGPU_VM_MTYPE_CC (3 << 5)
#define AMDGPU_VM_MTYPE_UC (4 << 5)
#define AMDGPU_VM_MTYPE_RW (5 << 5)
struct drm_amdgpu_gem_va {
  __u32 handle;
  __u32 _pad;
  __u32 operation;
  __u32 flags;
  __u64 va_address;
  __u64 offset_in_bo;
  __u64 map_size;
};
#define AMDGPU_HW_IP_GFX 0
#define AMDGPU_HW_IP_COMPUTE 1
#define AMDGPU_HW_IP_DMA 2
#define AMDGPU_HW_IP_UVD 3
#define AMDGPU_HW_IP_VCE 4
#define AMDGPU_HW_IP_UVD_ENC 5
#define AMDGPU_HW_IP_VCN_DEC 6
#define AMDGPU_HW_IP_VCN_ENC 7
#define AMDGPU_HW_IP_VCN_JPEG 8
#define AMDGPU_HW_IP_NUM 9
#define AMDGPU_HW_IP_INSTANCE_MAX_COUNT 1
#define AMDGPU_CHUNK_ID_IB 0x01
#define AMDGPU_CHUNK_ID_FENCE 0x02
#define AMDGPU_CHUNK_ID_DEPENDENCIES 0x03
#define AMDGPU_CHUNK_ID_SYNCOBJ_IN 0x04
#define AMDGPU_CHUNK_ID_SYNCOBJ_OUT 0x05
#define AMDGPU_CHUNK_ID_BO_HANDLES 0x06
#define AMDGPU_CHUNK_ID_SCHEDULED_DEPENDENCIES 0x07
#define AMDGPU_CHUNK_ID_SYNCOBJ_TIMELINE_WAIT 0x08
#define AMDGPU_CHUNK_ID_SYNCOBJ_TIMELINE_SIGNAL 0x09
struct drm_amdgpu_cs_chunk {
  __u32 chunk_id;
  __u32 length_dw;
  __u64 chunk_data;
};
struct drm_amdgpu_cs_in {
  __u32 ctx_id;
  __u32 bo_list_handle;
  __u32 num_chunks;
  __u32 flags;
  __u64 chunks;
};
struct drm_amdgpu_cs_out {
  __u64 handle;
};
union drm_amdgpu_cs {
  struct drm_amdgpu_cs_in in;
  struct drm_amdgpu_cs_out out;
};
#define AMDGPU_IB_FLAG_CE (1 << 0)
#define AMDGPU_IB_FLAG_PREAMBLE (1 << 1)
#define AMDGPU_IB_FLAG_PREEMPT (1 << 2)
#define AMDGPU_IB_FLAG_TC_WB_NOT_INVALIDATE (1 << 3)
#define AMDGPU_IB_FLAG_RESET_GDS_MAX_WAVE_ID (1 << 4)
#define AMDGPU_IB_FLAGS_SECURE (1 << 5)
#define AMDGPU_IB_FLAG_EMIT_MEM_SYNC (1 << 6)
struct drm_amdgpu_cs_chunk_ib {
  __u32 _pad;
  __u32 flags;
  __u64 va_start;
  __u32 ib_bytes;
  __u32 ip_type;
  __u32 ip_instance;
  __u32 ring;
};
struct drm_amdgpu_cs_chunk_dep {
  __u32 ip_type;
  __u32 ip_instance;
  __u32 ring;
  __u32 ctx_id;
  __u64 handle;
};
struct drm_amdgpu_cs_chunk_fence {
  __u32 handle;
  __u32 offset;
};
struct drm_amdgpu_cs_chunk_sem {
  __u32 handle;
};
struct drm_amdgpu_cs_chunk_syncobj {
  __u32 handle;
  __u32 flags;
  __u64 point;
};
#define AMDGPU_FENCE_TO_HANDLE_GET_SYNCOBJ 0
#define AMDGPU_FENCE_TO_HANDLE_GET_SYNCOBJ_FD 1
#define AMDGPU_FENCE_TO_HANDLE_GET_SYNC_FILE_FD 2
union drm_amdgpu_fence_to_handle {
  struct {
    struct drm_amdgpu_fence fence;
    __u32 what;
    __u32 pad;
  } in;
  struct {
    __u32 handle;
  } out;
};
struct drm_amdgpu_cs_chunk_data {
  union {
    struct drm_amdgpu_cs_chunk_ib ib_data;
    struct drm_amdgpu_cs_chunk_fence fence_data;
  };
};
#define AMDGPU_IDS_FLAGS_FUSION 0x1
#define AMDGPU_IDS_FLAGS_PREEMPTION 0x2
#define AMDGPU_IDS_FLAGS_TMZ 0x4
#define AMDGPU_INFO_ACCEL_WORKING 0x00
#define AMDGPU_INFO_CRTC_FROM_ID 0x01
#define AMDGPU_INFO_HW_IP_INFO 0x02
#define AMDGPU_INFO_HW_IP_COUNT 0x03
#define AMDGPU_INFO_TIMESTAMP 0x05
#define AMDGPU_INFO_FW_VERSION 0x0e
#define AMDGPU_INFO_FW_VCE 0x1
#define AMDGPU_INFO_FW_UVD 0x2
#define AMDGPU_INFO_FW_GMC 0x03
#define AMDGPU_INFO_FW_GFX_ME 0x04
#define AMDGPU_INFO_FW_GFX_PFP 0x05
#define AMDGPU_INFO_FW_GFX_CE 0x06
#define AMDGPU_INFO_FW_GFX_RLC 0x07
#define AMDGPU_INFO_FW_GFX_MEC 0x08
#define AMDGPU_INFO_FW_SMC 0x0a
#define AMDGPU_INFO_FW_SDMA 0x0b
#define AMDGPU_INFO_FW_SOS 0x0c
#define AMDGPU_INFO_FW_ASD 0x0d
#define AMDGPU_INFO_FW_VCN 0x0e
#define AMDGPU_INFO_FW_GFX_RLC_RESTORE_LIST_CNTL 0x0f
#define AMDGPU_INFO_FW_GFX_RLC_RESTORE_LIST_GPM_MEM 0x10
#define AMDGPU_INFO_FW_GFX_RLC_RESTORE_LIST_SRM_MEM 0x11
#define AMDGPU_INFO_FW_DMCU 0x12
#define AMDGPU_INFO_FW_TA 0x13
#define AMDGPU_INFO_FW_DMCUB 0x14
#define AMDGPU_INFO_NUM_BYTES_MOVED 0x0f
#define AMDGPU_INFO_VRAM_USAGE 0x10
#define AMDGPU_INFO_GTT_USAGE 0x11
#define AMDGPU_INFO_GDS_CONFIG 0x13
#define AMDGPU_INFO_VRAM_GTT 0x14
#define AMDGPU_INFO_READ_MMR_REG 0x15
#define AMDGPU_INFO_DEV_INFO 0x16
#define AMDGPU_INFO_VIS_VRAM_USAGE 0x17
#define AMDGPU_INFO_NUM_EVICTIONS 0x18
#define AMDGPU_INFO_MEMORY 0x19
#define AMDGPU_INFO_VCE_CLOCK_TABLE 0x1A
#define AMDGPU_INFO_VBIOS 0x1B
#define AMDGPU_INFO_VBIOS_SIZE 0x1
#define AMDGPU_INFO_VBIOS_IMAGE 0x2
#define AMDGPU_INFO_NUM_HANDLES 0x1C
#define AMDGPU_INFO_SENSOR 0x1D
#define AMDGPU_INFO_SENSOR_GFX_SCLK 0x1
#define AMDGPU_INFO_SENSOR_GFX_MCLK 0x2
#define AMDGPU_INFO_SENSOR_GPU_TEMP 0x3
#define AMDGPU_INFO_SENSOR_GPU_LOAD 0x4
#define AMDGPU_INFO_SENSOR_GPU_AVG_POWER 0x5
#define AMDGPU_INFO_SENSOR_VDDNB 0x6
#define AMDGPU_INFO_SENSOR_VDDGFX 0x7
#define AMDGPU_INFO_SENSOR_STABLE_PSTATE_GFX_SCLK 0x8
#define AMDGPU_INFO_SENSOR_STABLE_PSTATE_GFX_MCLK 0x9
#define AMDGPU_INFO_NUM_VRAM_CPU_PAGE_FAULTS 0x1E
#define AMDGPU_INFO_VRAM_LOST_COUNTER 0x1F
#define AMDGPU_INFO_RAS_ENABLED_FEATURES 0x20
#define AMDGPU_INFO_RAS_ENABLED_UMC (1 << 0)
#define AMDGPU_INFO_RAS_ENABLED_SDMA (1 << 1)
#define AMDGPU_INFO_RAS_ENABLED_GFX (1 << 2)
#define AMDGPU_INFO_RAS_ENABLED_MMHUB (1 << 3)
#define AMDGPU_INFO_RAS_ENABLED_ATHUB (1 << 4)
#define AMDGPU_INFO_RAS_ENABLED_PCIE (1 << 5)
#define AMDGPU_INFO_RAS_ENABLED_HDP (1 << 6)
#define AMDGPU_INFO_RAS_ENABLED_XGMI (1 << 7)
#define AMDGPU_INFO_RAS_ENABLED_DF (1 << 8)
#define AMDGPU_INFO_RAS_ENABLED_SMN (1 << 9)
#define AMDGPU_INFO_RAS_ENABLED_SEM (1 << 10)
#define AMDGPU_INFO_RAS_ENABLED_MP0 (1 << 11)
#define AMDGPU_INFO_RAS_ENABLED_MP1 (1 << 12)
#define AMDGPU_INFO_RAS_ENABLED_FUSE (1 << 13)
#define AMDGPU_INFO_MMR_SE_INDEX_SHIFT 0
#define AMDGPU_INFO_MMR_SE_INDEX_MASK 0xff
#define AMDGPU_INFO_MMR_SH_INDEX_SHIFT 8
#define AMDGPU_INFO_MMR_SH_INDEX_MASK 0xff
struct drm_amdgpu_query_fw {
  __u32 fw_type;
  __u32 ip_instance;
  __u32 index;
  __u32 _pad;
};
struct drm_amdgpu_info {
  __u64 return_pointer;
  __u32 return_size;
  __u32 query;
  union {
    struct {
      __u32 id;
      __u32 _pad;
    } mode_crtc;
    struct {
      __u32 type;
      __u32 ip_instance;
    } query_hw_ip;
    struct {
      __u32 dword_offset;
      __u32 count;
      __u32 instance;
      __u32 flags;
    } read_mmr_reg;
    struct drm_amdgpu_query_fw query_fw;
    struct {
      __u32 type;
      __u32 offset;
    } vbios_info;
    struct {
      __u32 type;
    } sensor_info;
  };
};
struct drm_amdgpu_info_gds {
  __u32 gds_gfx_partition_size;
  __u32 compute_partition_size;
  __u32 gds_total_size;
  __u32 gws_per_gfx_partition;
  __u32 gws_per_compute_partition;
  __u32 oa_per_gfx_partition;
  __u32 oa_per_compute_partition;
  __u32 _pad;
};
struct drm_amdgpu_info_vram_gtt {
  __u64 vram_size;
  __u64 vram_cpu_accessible_size;
  __u64 gtt_size;
};
struct drm_amdgpu_heap_info {
  __u64 total_heap_size;
  __u64 usable_heap_size;
  __u64 heap_usage;
  __u64 max_allocation;
};
struct drm_amdgpu_memory_info {
  struct drm_amdgpu_heap_info vram;
  struct drm_amdgpu_heap_info cpu_accessible_vram;
  struct drm_amdgpu_heap_info gtt;
};
struct drm_amdgpu_info_firmware {
  __u32 ver;
  __u32 feature;
};
#define AMDGPU_VRAM_TYPE_UNKNOWN 0
#define AMDGPU_VRAM_TYPE_GDDR1 1
#define AMDGPU_VRAM_TYPE_DDR2 2
#define AMDGPU_VRAM_TYPE_GDDR3 3
#define AMDGPU_VRAM_TYPE_GDDR4 4
#define AMDGPU_VRAM_TYPE_GDDR5 5
#define AMDGPU_VRAM_TYPE_HBM 6
#define AMDGPU_VRAM_TYPE_DDR3 7
#define AMDGPU_VRAM_TYPE_DDR4 8
#define AMDGPU_VRAM_TYPE_GDDR6 9
struct drm_amdgpu_info_device {
  __u32 device_id;
  __u32 chip_rev;
  __u32 external_rev;
  __u32 pci_rev;
  __u32 family;
  __u32 num_shader_engines;
  __u32 num_shader_arrays_per_engine;
  __u32 gpu_counter_freq;
  __u64 max_engine_clock;
  __u64 max_memory_clock;
  __u32 cu_active_number;
  __u32 cu_ao_mask;
  __u32 cu_bitmap[4][4];
  __u32 enabled_rb_pipes_mask;
  __u32 num_rb_pipes;
  __u32 num_hw_gfx_contexts;
  __u32 _pad;
  __u64 ids_flags;
  __u64 virtual_address_offset;
  __u64 virtual_address_max;
  __u32 virtual_address_alignment;
  __u32 pte_fragment_size;
  __u32 gart_page_size;
  __u32 ce_ram_size;
  __u32 vram_type;
  __u32 vram_bit_width;
  __u32 vce_harvest_config;
  __u32 gc_double_offchip_lds_buf;
  __u64 prim_buf_gpu_addr;
  __u64 pos_buf_gpu_addr;
  __u64 cntl_sb_buf_gpu_addr;
  __u64 param_buf_gpu_addr;
  __u32 prim_buf_size;
  __u32 pos_buf_size;
  __u32 cntl_sb_buf_size;
  __u32 param_buf_size;
  __u32 wave_front_size;
  __u32 num_shader_visible_vgprs;
  __u32 num_cu_per_sh;
  __u32 num_tcc_blocks;
  __u32 gs_vgt_table_depth;
  __u32 gs_prim_buffer_depth;
  __u32 max_gs_waves_per_vgt;
  __u32 _pad1;
  __u32 cu_ao_bitmap[4][4];
  __u64 high_va_offset;
  __u64 high_va_max;
  __u32 pa_sc_tile_steering_override;
  __u64 tcc_disabled_mask;
};
struct drm_amdgpu_info_hw_ip {
  __u32 hw_ip_version_major;
  __u32 hw_ip_version_minor;
  __u64 capabilities_flags;
  __u32 ib_start_alignment;
  __u32 ib_size_alignment;
  __u32 available_rings;
  __u32 _pad;
};
struct drm_amdgpu_info_num_handles {
  __u32 uvd_max_handles;
  __u32 uvd_used_handles;
};
#define AMDGPU_VCE_CLOCK_TABLE_ENTRIES 6
struct drm_amdgpu_info_vce_clock_table_entry {
  __u32 sclk;
  __u32 mclk;
  __u32 eclk;
  __u32 pad;
};
struct drm_amdgpu_info_vce_clock_table {
  struct drm_amdgpu_info_vce_clock_table_entry entries[AMDGPU_VCE_CLOCK_TABLE_ENTRIES];
  __u32 num_valid_entries;
  __u32 pad;
};
#define AMDGPU_FAMILY_UNKNOWN 0
#define AMDGPU_FAMILY_SI 110
#define AMDGPU_FAMILY_CI 120
#define AMDGPU_FAMILY_KV 125
#define AMDGPU_FAMILY_VI 130
#define AMDGPU_FAMILY_CZ 135
#define AMDGPU_FAMILY_AI 141
#define AMDGPU_FAMILY_RV 142
#define AMDGPU_FAMILY_NV 143
#ifdef __cplusplus
}
#endif
#endif