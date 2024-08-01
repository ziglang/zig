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
#ifndef _UAPI_TEGRA_DRM_H_
#define _UAPI_TEGRA_DRM_H_
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_TEGRA_GEM_CREATE_TILED (1 << 0)
#define DRM_TEGRA_GEM_CREATE_BOTTOM_UP (1 << 1)
struct drm_tegra_gem_create {
  __u64 size;
  __u32 flags;
  __u32 handle;
};
struct drm_tegra_gem_mmap {
  __u32 handle;
  __u32 pad;
  __u64 offset;
};
struct drm_tegra_syncpt_read {
  __u32 id;
  __u32 value;
};
struct drm_tegra_syncpt_incr {
  __u32 id;
  __u32 pad;
};
struct drm_tegra_syncpt_wait {
  __u32 id;
  __u32 thresh;
  __u32 timeout;
  __u32 value;
};
#define DRM_TEGRA_NO_TIMEOUT (0xffffffff)
struct drm_tegra_open_channel {
  __u32 client;
  __u32 pad;
  __u64 context;
};
struct drm_tegra_close_channel {
  __u64 context;
};
struct drm_tegra_get_syncpt {
  __u64 context;
  __u32 index;
  __u32 id;
};
struct drm_tegra_get_syncpt_base {
  __u64 context;
  __u32 syncpt;
  __u32 id;
};
struct drm_tegra_syncpt {
  __u32 id;
  __u32 incrs;
};
struct drm_tegra_cmdbuf {
  __u32 handle;
  __u32 offset;
  __u32 words;
  __u32 pad;
};
struct drm_tegra_reloc {
  struct {
    __u32 handle;
    __u32 offset;
  } cmdbuf;
  struct {
    __u32 handle;
    __u32 offset;
  } target;
  __u32 shift;
  __u32 pad;
};
struct drm_tegra_waitchk {
  __u32 handle;
  __u32 offset;
  __u32 syncpt;
  __u32 thresh;
};
struct drm_tegra_submit {
  __u64 context;
  __u32 num_syncpts;
  __u32 num_cmdbufs;
  __u32 num_relocs;
  __u32 num_waitchks;
  __u32 waitchk_mask;
  __u32 timeout;
  __u64 syncpts;
  __u64 cmdbufs;
  __u64 relocs;
  __u64 waitchks;
  __u32 fence;
  __u32 reserved[5];
};
#define DRM_TEGRA_GEM_TILING_MODE_PITCH 0
#define DRM_TEGRA_GEM_TILING_MODE_TILED 1
#define DRM_TEGRA_GEM_TILING_MODE_BLOCK 2
struct drm_tegra_gem_set_tiling {
  __u32 handle;
  __u32 mode;
  __u32 value;
  __u32 pad;
};
struct drm_tegra_gem_get_tiling {
  __u32 handle;
  __u32 mode;
  __u32 value;
  __u32 pad;
};
#define DRM_TEGRA_GEM_BOTTOM_UP (1 << 0)
#define DRM_TEGRA_GEM_FLAGS (DRM_TEGRA_GEM_BOTTOM_UP)
struct drm_tegra_gem_set_flags {
  __u32 handle;
  __u32 flags;
};
struct drm_tegra_gem_get_flags {
  __u32 handle;
  __u32 flags;
};
#define DRM_TEGRA_GEM_CREATE 0x00
#define DRM_TEGRA_GEM_MMAP 0x01
#define DRM_TEGRA_SYNCPT_READ 0x02
#define DRM_TEGRA_SYNCPT_INCR 0x03
#define DRM_TEGRA_SYNCPT_WAIT 0x04
#define DRM_TEGRA_OPEN_CHANNEL 0x05
#define DRM_TEGRA_CLOSE_CHANNEL 0x06
#define DRM_TEGRA_GET_SYNCPT 0x07
#define DRM_TEGRA_SUBMIT 0x08
#define DRM_TEGRA_GET_SYNCPT_BASE 0x09
#define DRM_TEGRA_GEM_SET_TILING 0x0a
#define DRM_TEGRA_GEM_GET_TILING 0x0b
#define DRM_TEGRA_GEM_SET_FLAGS 0x0c
#define DRM_TEGRA_GEM_GET_FLAGS 0x0d
#define DRM_IOCTL_TEGRA_GEM_CREATE DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_GEM_CREATE, struct drm_tegra_gem_create)
#define DRM_IOCTL_TEGRA_GEM_MMAP DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_GEM_MMAP, struct drm_tegra_gem_mmap)
#define DRM_IOCTL_TEGRA_SYNCPT_READ DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_SYNCPT_READ, struct drm_tegra_syncpt_read)
#define DRM_IOCTL_TEGRA_SYNCPT_INCR DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_SYNCPT_INCR, struct drm_tegra_syncpt_incr)
#define DRM_IOCTL_TEGRA_SYNCPT_WAIT DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_SYNCPT_WAIT, struct drm_tegra_syncpt_wait)
#define DRM_IOCTL_TEGRA_OPEN_CHANNEL DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_OPEN_CHANNEL, struct drm_tegra_open_channel)
#define DRM_IOCTL_TEGRA_CLOSE_CHANNEL DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_CLOSE_CHANNEL, struct drm_tegra_close_channel)
#define DRM_IOCTL_TEGRA_GET_SYNCPT DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_GET_SYNCPT, struct drm_tegra_get_syncpt)
#define DRM_IOCTL_TEGRA_SUBMIT DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_SUBMIT, struct drm_tegra_submit)
#define DRM_IOCTL_TEGRA_GET_SYNCPT_BASE DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_GET_SYNCPT_BASE, struct drm_tegra_get_syncpt_base)
#define DRM_IOCTL_TEGRA_GEM_SET_TILING DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_GEM_SET_TILING, struct drm_tegra_gem_set_tiling)
#define DRM_IOCTL_TEGRA_GEM_GET_TILING DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_GEM_GET_TILING, struct drm_tegra_gem_get_tiling)
#define DRM_IOCTL_TEGRA_GEM_SET_FLAGS DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_GEM_SET_FLAGS, struct drm_tegra_gem_set_flags)
#define DRM_IOCTL_TEGRA_GEM_GET_FLAGS DRM_IOWR(DRM_COMMAND_BASE + DRM_TEGRA_GEM_GET_FLAGS, struct drm_tegra_gem_get_flags)
#ifdef __cplusplus
}
#endif
#endif