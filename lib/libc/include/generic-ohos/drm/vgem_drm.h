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
#ifndef _UAPI_VGEM_DRM_H_
#define _UAPI_VGEM_DRM_H_
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_VGEM_FENCE_ATTACH 0x1
#define DRM_VGEM_FENCE_SIGNAL 0x2
#define DRM_IOCTL_VGEM_FENCE_ATTACH DRM_IOWR(DRM_COMMAND_BASE + DRM_VGEM_FENCE_ATTACH, struct drm_vgem_fence_attach)
#define DRM_IOCTL_VGEM_FENCE_SIGNAL DRM_IOW(DRM_COMMAND_BASE + DRM_VGEM_FENCE_SIGNAL, struct drm_vgem_fence_signal)
struct drm_vgem_fence_attach {
  __u32 handle;
  __u32 flags;
#define VGEM_FENCE_WRITE 0x1
  __u32 out_fence;
  __u32 pad;
};
struct drm_vgem_fence_signal {
  __u32 fence;
  __u32 flags;
};
#ifdef __cplusplus
}
#endif
#endif