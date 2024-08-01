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
#ifndef __MSM_DRM_H__
#define __MSM_DRM_H__
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define MSM_PIPE_NONE 0x00
#define MSM_PIPE_2D0 0x01
#define MSM_PIPE_2D1 0x02
#define MSM_PIPE_3D0 0x10
#define MSM_PIPE_ID_MASK 0xffff
#define MSM_PIPE_ID(x) ((x) & MSM_PIPE_ID_MASK)
#define MSM_PIPE_FLAGS(x) ((x) & ~MSM_PIPE_ID_MASK)
struct drm_msm_timespec {
  __s64 tv_sec;
  __s64 tv_nsec;
};
#define MSM_PARAM_GPU_ID 0x01
#define MSM_PARAM_GMEM_SIZE 0x02
#define MSM_PARAM_CHIP_ID 0x03
#define MSM_PARAM_MAX_FREQ 0x04
#define MSM_PARAM_TIMESTAMP 0x05
#define MSM_PARAM_GMEM_BASE 0x06
#define MSM_PARAM_NR_RINGS 0x07
#define MSM_PARAM_PP_PGTABLE 0x08
#define MSM_PARAM_FAULTS 0x09
struct drm_msm_param {
  __u32 pipe;
  __u32 param;
  __u64 value;
};
#define MSM_BO_SCANOUT 0x00000001
#define MSM_BO_GPU_READONLY 0x00000002
#define MSM_BO_CACHE_MASK 0x000f0000
#define MSM_BO_CACHED 0x00010000
#define MSM_BO_WC 0x00020000
#define MSM_BO_UNCACHED 0x00040000
#define MSM_BO_FLAGS (MSM_BO_SCANOUT | MSM_BO_GPU_READONLY | MSM_BO_CACHED | MSM_BO_WC | MSM_BO_UNCACHED)
struct drm_msm_gem_new {
  __u64 size;
  __u32 flags;
  __u32 handle;
};
#define MSM_INFO_GET_OFFSET 0x00
#define MSM_INFO_GET_IOVA 0x01
#define MSM_INFO_SET_NAME 0x02
#define MSM_INFO_GET_NAME 0x03
struct drm_msm_gem_info {
  __u32 handle;
  __u32 info;
  __u64 value;
  __u32 len;
  __u32 pad;
};
#define MSM_PREP_READ 0x01
#define MSM_PREP_WRITE 0x02
#define MSM_PREP_NOSYNC 0x04
#define MSM_PREP_FLAGS (MSM_PREP_READ | MSM_PREP_WRITE | MSM_PREP_NOSYNC)
struct drm_msm_gem_cpu_prep {
  __u32 handle;
  __u32 op;
  struct drm_msm_timespec timeout;
};
struct drm_msm_gem_cpu_fini {
  __u32 handle;
};
struct drm_msm_gem_submit_reloc {
  __u32 submit_offset;
  __u32 or;
  __s32 shift;
  __u32 reloc_idx;
  __u64 reloc_offset;
};
#define MSM_SUBMIT_CMD_BUF 0x0001
#define MSM_SUBMIT_CMD_IB_TARGET_BUF 0x0002
#define MSM_SUBMIT_CMD_CTX_RESTORE_BUF 0x0003
struct drm_msm_gem_submit_cmd {
  __u32 type;
  __u32 submit_idx;
  __u32 submit_offset;
  __u32 size;
  __u32 pad;
  __u32 nr_relocs;
  __u64 relocs;
};
#define MSM_SUBMIT_BO_READ 0x0001
#define MSM_SUBMIT_BO_WRITE 0x0002
#define MSM_SUBMIT_BO_DUMP 0x0004
#define MSM_SUBMIT_BO_FLAGS (MSM_SUBMIT_BO_READ | MSM_SUBMIT_BO_WRITE | MSM_SUBMIT_BO_DUMP)
struct drm_msm_gem_submit_bo {
  __u32 flags;
  __u32 handle;
  __u64 presumed;
};
#define MSM_SUBMIT_NO_IMPLICIT 0x80000000
#define MSM_SUBMIT_FENCE_FD_IN 0x40000000
#define MSM_SUBMIT_FENCE_FD_OUT 0x20000000
#define MSM_SUBMIT_SUDO 0x10000000
#define MSM_SUBMIT_SYNCOBJ_IN 0x08000000
#define MSM_SUBMIT_SYNCOBJ_OUT 0x04000000
#define MSM_SUBMIT_FLAGS (MSM_SUBMIT_NO_IMPLICIT | MSM_SUBMIT_FENCE_FD_IN | MSM_SUBMIT_FENCE_FD_OUT | MSM_SUBMIT_SUDO | MSM_SUBMIT_SYNCOBJ_IN | MSM_SUBMIT_SYNCOBJ_OUT | 0)
#define MSM_SUBMIT_SYNCOBJ_RESET 0x00000001
#define MSM_SUBMIT_SYNCOBJ_FLAGS (MSM_SUBMIT_SYNCOBJ_RESET | 0)
struct drm_msm_gem_submit_syncobj {
  __u32 handle;
  __u32 flags;
  __u64 point;
};
struct drm_msm_gem_submit {
  __u32 flags;
  __u32 fence;
  __u32 nr_bos;
  __u32 nr_cmds;
  __u64 bos;
  __u64 cmds;
  __s32 fence_fd;
  __u32 queueid;
  __u64 in_syncobjs;
  __u64 out_syncobjs;
  __u32 nr_in_syncobjs;
  __u32 nr_out_syncobjs;
  __u32 syncobj_stride;
  __u32 pad;
};
struct drm_msm_wait_fence {
  __u32 fence;
  __u32 pad;
  struct drm_msm_timespec timeout;
  __u32 queueid;
};
#define MSM_MADV_WILLNEED 0
#define MSM_MADV_DONTNEED 1
#define __MSM_MADV_PURGED 2
struct drm_msm_gem_madvise {
  __u32 handle;
  __u32 madv;
  __u32 retained;
};
#define MSM_SUBMITQUEUE_FLAGS (0)
struct drm_msm_submitqueue {
  __u32 flags;
  __u32 prio;
  __u32 id;
};
#define MSM_SUBMITQUEUE_PARAM_FAULTS 0
struct drm_msm_submitqueue_query {
  __u64 data;
  __u32 id;
  __u32 param;
  __u32 len;
  __u32 pad;
};
#define DRM_MSM_GET_PARAM 0x00
#define DRM_MSM_GEM_NEW 0x02
#define DRM_MSM_GEM_INFO 0x03
#define DRM_MSM_GEM_CPU_PREP 0x04
#define DRM_MSM_GEM_CPU_FINI 0x05
#define DRM_MSM_GEM_SUBMIT 0x06
#define DRM_MSM_WAIT_FENCE 0x07
#define DRM_MSM_GEM_MADVISE 0x08
#define DRM_MSM_SUBMITQUEUE_NEW 0x0A
#define DRM_MSM_SUBMITQUEUE_CLOSE 0x0B
#define DRM_MSM_SUBMITQUEUE_QUERY 0x0C
#define DRM_IOCTL_MSM_GET_PARAM DRM_IOWR(DRM_COMMAND_BASE + DRM_MSM_GET_PARAM, struct drm_msm_param)
#define DRM_IOCTL_MSM_GEM_NEW DRM_IOWR(DRM_COMMAND_BASE + DRM_MSM_GEM_NEW, struct drm_msm_gem_new)
#define DRM_IOCTL_MSM_GEM_INFO DRM_IOWR(DRM_COMMAND_BASE + DRM_MSM_GEM_INFO, struct drm_msm_gem_info)
#define DRM_IOCTL_MSM_GEM_CPU_PREP DRM_IOW(DRM_COMMAND_BASE + DRM_MSM_GEM_CPU_PREP, struct drm_msm_gem_cpu_prep)
#define DRM_IOCTL_MSM_GEM_CPU_FINI DRM_IOW(DRM_COMMAND_BASE + DRM_MSM_GEM_CPU_FINI, struct drm_msm_gem_cpu_fini)
#define DRM_IOCTL_MSM_GEM_SUBMIT DRM_IOWR(DRM_COMMAND_BASE + DRM_MSM_GEM_SUBMIT, struct drm_msm_gem_submit)
#define DRM_IOCTL_MSM_WAIT_FENCE DRM_IOW(DRM_COMMAND_BASE + DRM_MSM_WAIT_FENCE, struct drm_msm_wait_fence)
#define DRM_IOCTL_MSM_GEM_MADVISE DRM_IOWR(DRM_COMMAND_BASE + DRM_MSM_GEM_MADVISE, struct drm_msm_gem_madvise)
#define DRM_IOCTL_MSM_SUBMITQUEUE_NEW DRM_IOWR(DRM_COMMAND_BASE + DRM_MSM_SUBMITQUEUE_NEW, struct drm_msm_submitqueue)
#define DRM_IOCTL_MSM_SUBMITQUEUE_CLOSE DRM_IOW(DRM_COMMAND_BASE + DRM_MSM_SUBMITQUEUE_CLOSE, __u32)
#define DRM_IOCTL_MSM_SUBMITQUEUE_QUERY DRM_IOW(DRM_COMMAND_BASE + DRM_MSM_SUBMITQUEUE_QUERY, struct drm_msm_submitqueue_query)
#ifdef __cplusplus
}
#endif
#endif