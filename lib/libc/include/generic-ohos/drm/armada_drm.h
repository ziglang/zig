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
#ifndef DRM_ARMADA_IOCTL_H
#define DRM_ARMADA_IOCTL_H
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_ARMADA_GEM_CREATE 0x00
#define DRM_ARMADA_GEM_MMAP 0x02
#define DRM_ARMADA_GEM_PWRITE 0x03
#define ARMADA_IOCTL(dir,name,str) DRM_ ##dir(DRM_COMMAND_BASE + DRM_ARMADA_ ##name, struct drm_armada_ ##str)
struct drm_armada_gem_create {
  __u32 handle;
  __u32 size;
};
#define DRM_IOCTL_ARMADA_GEM_CREATE ARMADA_IOCTL(IOWR, GEM_CREATE, gem_create)
struct drm_armada_gem_mmap {
  __u32 handle;
  __u32 pad;
  __u64 offset;
  __u64 size;
  __u64 addr;
};
#define DRM_IOCTL_ARMADA_GEM_MMAP ARMADA_IOCTL(IOWR, GEM_MMAP, gem_mmap)
struct drm_armada_gem_pwrite {
  __u64 ptr;
  __u32 handle;
  __u32 offset;
  __u32 size;
};
#define DRM_IOCTL_ARMADA_GEM_PWRITE ARMADA_IOCTL(IOW, GEM_PWRITE, gem_pwrite)
#ifdef __cplusplus
}
#endif
#endif