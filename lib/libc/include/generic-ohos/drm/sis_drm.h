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
#ifndef __SIS_DRM_H__
#define __SIS_DRM_H__
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define NOT_USED_0_3
#define DRM_SIS_FB_ALLOC 0x04
#define DRM_SIS_FB_FREE 0x05
#define NOT_USED_6_12
#define DRM_SIS_AGP_INIT 0x13
#define DRM_SIS_AGP_ALLOC 0x14
#define DRM_SIS_AGP_FREE 0x15
#define DRM_SIS_FB_INIT 0x16
#define DRM_IOCTL_SIS_FB_ALLOC DRM_IOWR(DRM_COMMAND_BASE + DRM_SIS_FB_ALLOC, drm_sis_mem_t)
#define DRM_IOCTL_SIS_FB_FREE DRM_IOW(DRM_COMMAND_BASE + DRM_SIS_FB_FREE, drm_sis_mem_t)
#define DRM_IOCTL_SIS_AGP_INIT DRM_IOWR(DRM_COMMAND_BASE + DRM_SIS_AGP_INIT, drm_sis_agp_t)
#define DRM_IOCTL_SIS_AGP_ALLOC DRM_IOWR(DRM_COMMAND_BASE + DRM_SIS_AGP_ALLOC, drm_sis_mem_t)
#define DRM_IOCTL_SIS_AGP_FREE DRM_IOW(DRM_COMMAND_BASE + DRM_SIS_AGP_FREE, drm_sis_mem_t)
#define DRM_IOCTL_SIS_FB_INIT DRM_IOW(DRM_COMMAND_BASE + DRM_SIS_FB_INIT, drm_sis_fb_t)
typedef struct {
  int context;
  unsigned long offset;
  unsigned long size;
  unsigned long free;
} drm_sis_mem_t;
typedef struct {
  unsigned long offset, size;
} drm_sis_agp_t;
typedef struct {
  unsigned long offset, size;
} drm_sis_fb_t;
#ifdef __cplusplus
}
#endif
#endif