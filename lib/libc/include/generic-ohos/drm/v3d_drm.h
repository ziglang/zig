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
#ifndef _V3D_DRM_H_
#define _V3D_DRM_H_
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_V3D_SUBMIT_CL 0x00
#define DRM_V3D_WAIT_BO 0x01
#define DRM_V3D_CREATE_BO 0x02
#define DRM_V3D_MMAP_BO 0x03
#define DRM_V3D_GET_PARAM 0x04
#define DRM_V3D_GET_BO_OFFSET 0x05
#define DRM_V3D_SUBMIT_TFU 0x06
#define DRM_V3D_SUBMIT_CSD 0x07
#define DRM_IOCTL_V3D_SUBMIT_CL DRM_IOWR(DRM_COMMAND_BASE + DRM_V3D_SUBMIT_CL, struct drm_v3d_submit_cl)
#define DRM_IOCTL_V3D_WAIT_BO DRM_IOWR(DRM_COMMAND_BASE + DRM_V3D_WAIT_BO, struct drm_v3d_wait_bo)
#define DRM_IOCTL_V3D_CREATE_BO DRM_IOWR(DRM_COMMAND_BASE + DRM_V3D_CREATE_BO, struct drm_v3d_create_bo)
#define DRM_IOCTL_V3D_MMAP_BO DRM_IOWR(DRM_COMMAND_BASE + DRM_V3D_MMAP_BO, struct drm_v3d_mmap_bo)
#define DRM_IOCTL_V3D_GET_PARAM DRM_IOWR(DRM_COMMAND_BASE + DRM_V3D_GET_PARAM, struct drm_v3d_get_param)
#define DRM_IOCTL_V3D_GET_BO_OFFSET DRM_IOWR(DRM_COMMAND_BASE + DRM_V3D_GET_BO_OFFSET, struct drm_v3d_get_bo_offset)
#define DRM_IOCTL_V3D_SUBMIT_TFU DRM_IOW(DRM_COMMAND_BASE + DRM_V3D_SUBMIT_TFU, struct drm_v3d_submit_tfu)
#define DRM_IOCTL_V3D_SUBMIT_CSD DRM_IOW(DRM_COMMAND_BASE + DRM_V3D_SUBMIT_CSD, struct drm_v3d_submit_csd)
#define DRM_V3D_SUBMIT_CL_FLUSH_CACHE 0x01
struct drm_v3d_submit_cl {
  __u32 bcl_start;
  __u32 bcl_end;
  __u32 rcl_start;
  __u32 rcl_end;
  __u32 in_sync_bcl;
  __u32 in_sync_rcl;
  __u32 out_sync;
  __u32 qma;
  __u32 qms;
  __u32 qts;
  __u64 bo_handles;
  __u32 bo_handle_count;
  __u32 flags;
};
struct drm_v3d_wait_bo {
  __u32 handle;
  __u32 pad;
  __u64 timeout_ns;
};
struct drm_v3d_create_bo {
  __u32 size;
  __u32 flags;
  __u32 handle;
  __u32 offset;
};
struct drm_v3d_mmap_bo {
  __u32 handle;
  __u32 flags;
  __u64 offset;
};
enum drm_v3d_param {
  DRM_V3D_PARAM_V3D_UIFCFG,
  DRM_V3D_PARAM_V3D_HUB_IDENT1,
  DRM_V3D_PARAM_V3D_HUB_IDENT2,
  DRM_V3D_PARAM_V3D_HUB_IDENT3,
  DRM_V3D_PARAM_V3D_CORE0_IDENT0,
  DRM_V3D_PARAM_V3D_CORE0_IDENT1,
  DRM_V3D_PARAM_V3D_CORE0_IDENT2,
  DRM_V3D_PARAM_SUPPORTS_TFU,
  DRM_V3D_PARAM_SUPPORTS_CSD,
  DRM_V3D_PARAM_SUPPORTS_CACHE_FLUSH,
};
struct drm_v3d_get_param {
  __u32 param;
  __u32 pad;
  __u64 value;
};
struct drm_v3d_get_bo_offset {
  __u32 handle;
  __u32 offset;
};
struct drm_v3d_submit_tfu {
  __u32 icfg;
  __u32 iia;
  __u32 iis;
  __u32 ica;
  __u32 iua;
  __u32 ioa;
  __u32 ios;
  __u32 coef[4];
  __u32 bo_handles[4];
  __u32 in_sync;
  __u32 out_sync;
};
struct drm_v3d_submit_csd {
  __u32 cfg[7];
  __u32 coef[4];
  __u64 bo_handles;
  __u32 bo_handle_count;
  __u32 in_sync;
  __u32 out_sync;
};
#ifdef __cplusplus
}
#endif
#endif