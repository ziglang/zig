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
#ifndef __ETNAVIV_DRM_H__
#define __ETNAVIV_DRM_H__
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
struct drm_etnaviv_timespec {
  __s64 tv_sec;
  __s64 tv_nsec;
};
#define ETNAVIV_PARAM_GPU_MODEL 0x01
#define ETNAVIV_PARAM_GPU_REVISION 0x02
#define ETNAVIV_PARAM_GPU_FEATURES_0 0x03
#define ETNAVIV_PARAM_GPU_FEATURES_1 0x04
#define ETNAVIV_PARAM_GPU_FEATURES_2 0x05
#define ETNAVIV_PARAM_GPU_FEATURES_3 0x06
#define ETNAVIV_PARAM_GPU_FEATURES_4 0x07
#define ETNAVIV_PARAM_GPU_FEATURES_5 0x08
#define ETNAVIV_PARAM_GPU_FEATURES_6 0x09
#define ETNAVIV_PARAM_GPU_FEATURES_7 0x0a
#define ETNAVIV_PARAM_GPU_FEATURES_8 0x0b
#define ETNAVIV_PARAM_GPU_FEATURES_9 0x0c
#define ETNAVIV_PARAM_GPU_FEATURES_10 0x0d
#define ETNAVIV_PARAM_GPU_FEATURES_11 0x0e
#define ETNAVIV_PARAM_GPU_FEATURES_12 0x0f
#define ETNAVIV_PARAM_GPU_STREAM_COUNT 0x10
#define ETNAVIV_PARAM_GPU_REGISTER_MAX 0x11
#define ETNAVIV_PARAM_GPU_THREAD_COUNT 0x12
#define ETNAVIV_PARAM_GPU_VERTEX_CACHE_SIZE 0x13
#define ETNAVIV_PARAM_GPU_SHADER_CORE_COUNT 0x14
#define ETNAVIV_PARAM_GPU_PIXEL_PIPES 0x15
#define ETNAVIV_PARAM_GPU_VERTEX_OUTPUT_BUFFER_SIZE 0x16
#define ETNAVIV_PARAM_GPU_BUFFER_SIZE 0x17
#define ETNAVIV_PARAM_GPU_INSTRUCTION_COUNT 0x18
#define ETNAVIV_PARAM_GPU_NUM_CONSTANTS 0x19
#define ETNAVIV_PARAM_GPU_NUM_VARYINGS 0x1a
#define ETNAVIV_PARAM_SOFTPIN_START_ADDR 0x1b
#define ETNA_MAX_PIPES 4
struct drm_etnaviv_param {
  __u32 pipe;
  __u32 param;
  __u64 value;
};
#define ETNA_BO_CACHE_MASK 0x000f0000
#define ETNA_BO_CACHED 0x00010000
#define ETNA_BO_WC 0x00020000
#define ETNA_BO_UNCACHED 0x00040000
#define ETNA_BO_FORCE_MMU 0x00100000
struct drm_etnaviv_gem_new {
  __u64 size;
  __u32 flags;
  __u32 handle;
};
struct drm_etnaviv_gem_info {
  __u32 handle;
  __u32 pad;
  __u64 offset;
};
#define ETNA_PREP_READ 0x01
#define ETNA_PREP_WRITE 0x02
#define ETNA_PREP_NOSYNC 0x04
struct drm_etnaviv_gem_cpu_prep {
  __u32 handle;
  __u32 op;
  struct drm_etnaviv_timespec timeout;
};
struct drm_etnaviv_gem_cpu_fini {
  __u32 handle;
  __u32 flags;
};
struct drm_etnaviv_gem_submit_reloc {
  __u32 submit_offset;
  __u32 reloc_idx;
  __u64 reloc_offset;
  __u32 flags;
};
#define ETNA_SUBMIT_BO_READ 0x0001
#define ETNA_SUBMIT_BO_WRITE 0x0002
struct drm_etnaviv_gem_submit_bo {
  __u32 flags;
  __u32 handle;
  __u64 presumed;
};
#define ETNA_PM_PROCESS_PRE 0x0001
#define ETNA_PM_PROCESS_POST 0x0002
struct drm_etnaviv_gem_submit_pmr {
  __u32 flags;
  __u8 domain;
  __u8 pad;
  __u16 signal;
  __u32 sequence;
  __u32 read_offset;
  __u32 read_idx;
};
#define ETNA_SUBMIT_NO_IMPLICIT 0x0001
#define ETNA_SUBMIT_FENCE_FD_IN 0x0002
#define ETNA_SUBMIT_FENCE_FD_OUT 0x0004
#define ETNA_SUBMIT_SOFTPIN 0x0008
#define ETNA_SUBMIT_FLAGS (ETNA_SUBMIT_NO_IMPLICIT | ETNA_SUBMIT_FENCE_FD_IN | ETNA_SUBMIT_FENCE_FD_OUT | ETNA_SUBMIT_SOFTPIN)
#define ETNA_PIPE_3D 0x00
#define ETNA_PIPE_2D 0x01
#define ETNA_PIPE_VG 0x02
struct drm_etnaviv_gem_submit {
  __u32 fence;
  __u32 pipe;
  __u32 exec_state;
  __u32 nr_bos;
  __u32 nr_relocs;
  __u32 stream_size;
  __u64 bos;
  __u64 relocs;
  __u64 stream;
  __u32 flags;
  __s32 fence_fd;
  __u64 pmrs;
  __u32 nr_pmrs;
  __u32 pad;
};
#define ETNA_WAIT_NONBLOCK 0x01
struct drm_etnaviv_wait_fence {
  __u32 pipe;
  __u32 fence;
  __u32 flags;
  __u32 pad;
  struct drm_etnaviv_timespec timeout;
};
#define ETNA_USERPTR_READ 0x01
#define ETNA_USERPTR_WRITE 0x02
struct drm_etnaviv_gem_userptr {
  __u64 user_ptr;
  __u64 user_size;
  __u32 flags;
  __u32 handle;
};
struct drm_etnaviv_gem_wait {
  __u32 pipe;
  __u32 handle;
  __u32 flags;
  __u32 pad;
  struct drm_etnaviv_timespec timeout;
};
struct drm_etnaviv_pm_domain {
  __u32 pipe;
  __u8 iter;
  __u8 id;
  __u16 nr_signals;
  char name[64];
};
struct drm_etnaviv_pm_signal {
  __u32 pipe;
  __u8 domain;
  __u8 pad;
  __u16 iter;
  __u16 id;
  char name[64];
};
#define DRM_ETNAVIV_GET_PARAM 0x00
#define DRM_ETNAVIV_GEM_NEW 0x02
#define DRM_ETNAVIV_GEM_INFO 0x03
#define DRM_ETNAVIV_GEM_CPU_PREP 0x04
#define DRM_ETNAVIV_GEM_CPU_FINI 0x05
#define DRM_ETNAVIV_GEM_SUBMIT 0x06
#define DRM_ETNAVIV_WAIT_FENCE 0x07
#define DRM_ETNAVIV_GEM_USERPTR 0x08
#define DRM_ETNAVIV_GEM_WAIT 0x09
#define DRM_ETNAVIV_PM_QUERY_DOM 0x0a
#define DRM_ETNAVIV_PM_QUERY_SIG 0x0b
#define DRM_ETNAVIV_NUM_IOCTLS 0x0c
#define DRM_IOCTL_ETNAVIV_GET_PARAM DRM_IOWR(DRM_COMMAND_BASE + DRM_ETNAVIV_GET_PARAM, struct drm_etnaviv_param)
#define DRM_IOCTL_ETNAVIV_GEM_NEW DRM_IOWR(DRM_COMMAND_BASE + DRM_ETNAVIV_GEM_NEW, struct drm_etnaviv_gem_new)
#define DRM_IOCTL_ETNAVIV_GEM_INFO DRM_IOWR(DRM_COMMAND_BASE + DRM_ETNAVIV_GEM_INFO, struct drm_etnaviv_gem_info)
#define DRM_IOCTL_ETNAVIV_GEM_CPU_PREP DRM_IOW(DRM_COMMAND_BASE + DRM_ETNAVIV_GEM_CPU_PREP, struct drm_etnaviv_gem_cpu_prep)
#define DRM_IOCTL_ETNAVIV_GEM_CPU_FINI DRM_IOW(DRM_COMMAND_BASE + DRM_ETNAVIV_GEM_CPU_FINI, struct drm_etnaviv_gem_cpu_fini)
#define DRM_IOCTL_ETNAVIV_GEM_SUBMIT DRM_IOWR(DRM_COMMAND_BASE + DRM_ETNAVIV_GEM_SUBMIT, struct drm_etnaviv_gem_submit)
#define DRM_IOCTL_ETNAVIV_WAIT_FENCE DRM_IOW(DRM_COMMAND_BASE + DRM_ETNAVIV_WAIT_FENCE, struct drm_etnaviv_wait_fence)
#define DRM_IOCTL_ETNAVIV_GEM_USERPTR DRM_IOWR(DRM_COMMAND_BASE + DRM_ETNAVIV_GEM_USERPTR, struct drm_etnaviv_gem_userptr)
#define DRM_IOCTL_ETNAVIV_GEM_WAIT DRM_IOW(DRM_COMMAND_BASE + DRM_ETNAVIV_GEM_WAIT, struct drm_etnaviv_gem_wait)
#define DRM_IOCTL_ETNAVIV_PM_QUERY_DOM DRM_IOWR(DRM_COMMAND_BASE + DRM_ETNAVIV_PM_QUERY_DOM, struct drm_etnaviv_pm_domain)
#define DRM_IOCTL_ETNAVIV_PM_QUERY_SIG DRM_IOWR(DRM_COMMAND_BASE + DRM_ETNAVIV_PM_QUERY_SIG, struct drm_etnaviv_pm_signal)
#ifdef __cplusplus
}
#endif
#endif