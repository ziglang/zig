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
#ifndef _UAPI_EXYNOS_DRM_H_
#define _UAPI_EXYNOS_DRM_H_
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
struct drm_exynos_gem_create {
  __u64 size;
  __u32 flags;
  __u32 handle;
};
struct drm_exynos_gem_map {
  __u32 handle;
  __u32 reserved;
  __u64 offset;
};
struct drm_exynos_gem_info {
  __u32 handle;
  __u32 flags;
  __u64 size;
};
struct drm_exynos_vidi_connection {
  __u32 connection;
  __u32 extensions;
  __u64 edid;
};
enum e_drm_exynos_gem_mem_type {
  EXYNOS_BO_CONTIG = 0 << 0,
  EXYNOS_BO_NONCONTIG = 1 << 0,
  EXYNOS_BO_NONCACHABLE = 0 << 1,
  EXYNOS_BO_CACHABLE = 1 << 1,
  EXYNOS_BO_WC = 1 << 2,
  EXYNOS_BO_MASK = EXYNOS_BO_NONCONTIG | EXYNOS_BO_CACHABLE | EXYNOS_BO_WC
};
struct drm_exynos_g2d_get_ver {
  __u32 major;
  __u32 minor;
};
struct drm_exynos_g2d_cmd {
  __u32 offset;
  __u32 data;
};
enum drm_exynos_g2d_buf_type {
  G2D_BUF_USERPTR = 1 << 31,
};
enum drm_exynos_g2d_event_type {
  G2D_EVENT_NOT,
  G2D_EVENT_NONSTOP,
  G2D_EVENT_STOP,
};
struct drm_exynos_g2d_userptr {
  unsigned long userptr;
  unsigned long size;
};
struct drm_exynos_g2d_set_cmdlist {
  __u64 cmd;
  __u64 cmd_buf;
  __u32 cmd_nr;
  __u32 cmd_buf_nr;
  __u64 event_type;
  __u64 user_data;
};
struct drm_exynos_g2d_exec {
  __u64 async;
};
struct drm_exynos_ioctl_ipp_get_res {
  __u32 count_ipps;
  __u32 reserved;
  __u64 ipp_id_ptr;
};
enum drm_exynos_ipp_format_type {
  DRM_EXYNOS_IPP_FORMAT_SOURCE = 0x01,
  DRM_EXYNOS_IPP_FORMAT_DESTINATION = 0x02,
};
struct drm_exynos_ipp_format {
  __u32 fourcc;
  __u32 type;
  __u64 modifier;
};
enum drm_exynos_ipp_capability {
  DRM_EXYNOS_IPP_CAP_CROP = 0x01,
  DRM_EXYNOS_IPP_CAP_ROTATE = 0x02,
  DRM_EXYNOS_IPP_CAP_SCALE = 0x04,
  DRM_EXYNOS_IPP_CAP_CONVERT = 0x08,
};
struct drm_exynos_ioctl_ipp_get_caps {
  __u32 ipp_id;
  __u32 capabilities;
  __u32 reserved;
  __u32 formats_count;
  __u64 formats_ptr;
};
enum drm_exynos_ipp_limit_type {
  DRM_EXYNOS_IPP_LIMIT_TYPE_SIZE = 0x0001,
  DRM_EXYNOS_IPP_LIMIT_TYPE_SCALE = 0x0002,
  DRM_EXYNOS_IPP_LIMIT_SIZE_BUFFER = 0x0001 << 16,
  DRM_EXYNOS_IPP_LIMIT_SIZE_AREA = 0x0002 << 16,
  DRM_EXYNOS_IPP_LIMIT_SIZE_ROTATED = 0x0003 << 16,
  DRM_EXYNOS_IPP_LIMIT_TYPE_MASK = 0x000f,
  DRM_EXYNOS_IPP_LIMIT_SIZE_MASK = 0x000f << 16,
};
struct drm_exynos_ipp_limit_val {
  __u32 min;
  __u32 max;
  __u32 align;
  __u32 reserved;
};
struct drm_exynos_ipp_limit {
  __u32 type;
  __u32 reserved;
  struct drm_exynos_ipp_limit_val h;
  struct drm_exynos_ipp_limit_val v;
};
struct drm_exynos_ioctl_ipp_get_limits {
  __u32 ipp_id;
  __u32 fourcc;
  __u64 modifier;
  __u32 type;
  __u32 limits_count;
  __u64 limits_ptr;
};
enum drm_exynos_ipp_task_id {
  DRM_EXYNOS_IPP_TASK_BUFFER = 0x0001,
  DRM_EXYNOS_IPP_TASK_RECTANGLE = 0x0002,
  DRM_EXYNOS_IPP_TASK_TRANSFORM = 0x0003,
  DRM_EXYNOS_IPP_TASK_ALPHA = 0x0004,
  DRM_EXYNOS_IPP_TASK_TYPE_SOURCE = 0x0001 << 16,
  DRM_EXYNOS_IPP_TASK_TYPE_DESTINATION = 0x0002 << 16,
};
struct drm_exynos_ipp_task_buffer {
  __u32 id;
  __u32 fourcc;
  __u32 width, height;
  __u32 gem_id[4];
  __u32 offset[4];
  __u32 pitch[4];
  __u64 modifier;
};
struct drm_exynos_ipp_task_rect {
  __u32 id;
  __u32 reserved;
  __u32 x;
  __u32 y;
  __u32 w;
  __u32 h;
};
struct drm_exynos_ipp_task_transform {
  __u32 id;
  __u32 rotation;
};
struct drm_exynos_ipp_task_alpha {
  __u32 id;
  __u32 value;
};
enum drm_exynos_ipp_flag {
  DRM_EXYNOS_IPP_FLAG_EVENT = 0x01,
  DRM_EXYNOS_IPP_FLAG_TEST_ONLY = 0x02,
  DRM_EXYNOS_IPP_FLAG_NONBLOCK = 0x04,
};
#define DRM_EXYNOS_IPP_FLAGS (DRM_EXYNOS_IPP_FLAG_EVENT | DRM_EXYNOS_IPP_FLAG_TEST_ONLY | DRM_EXYNOS_IPP_FLAG_NONBLOCK)
struct drm_exynos_ioctl_ipp_commit {
  __u32 ipp_id;
  __u32 flags;
  __u32 reserved;
  __u32 params_size;
  __u64 params_ptr;
  __u64 user_data;
};
#define DRM_EXYNOS_GEM_CREATE 0x00
#define DRM_EXYNOS_GEM_MAP 0x01
#define DRM_EXYNOS_GEM_GET 0x04
#define DRM_EXYNOS_VIDI_CONNECTION 0x07
#define DRM_EXYNOS_G2D_GET_VER 0x20
#define DRM_EXYNOS_G2D_SET_CMDLIST 0x21
#define DRM_EXYNOS_G2D_EXEC 0x22
#define DRM_EXYNOS_IPP_GET_RESOURCES 0x40
#define DRM_EXYNOS_IPP_GET_CAPS 0x41
#define DRM_EXYNOS_IPP_GET_LIMITS 0x42
#define DRM_EXYNOS_IPP_COMMIT 0x43
#define DRM_IOCTL_EXYNOS_GEM_CREATE DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_GEM_CREATE, struct drm_exynos_gem_create)
#define DRM_IOCTL_EXYNOS_GEM_MAP DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_GEM_MAP, struct drm_exynos_gem_map)
#define DRM_IOCTL_EXYNOS_GEM_GET DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_GEM_GET, struct drm_exynos_gem_info)
#define DRM_IOCTL_EXYNOS_VIDI_CONNECTION DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_VIDI_CONNECTION, struct drm_exynos_vidi_connection)
#define DRM_IOCTL_EXYNOS_G2D_GET_VER DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_G2D_GET_VER, struct drm_exynos_g2d_get_ver)
#define DRM_IOCTL_EXYNOS_G2D_SET_CMDLIST DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_G2D_SET_CMDLIST, struct drm_exynos_g2d_set_cmdlist)
#define DRM_IOCTL_EXYNOS_G2D_EXEC DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_G2D_EXEC, struct drm_exynos_g2d_exec)
#define DRM_IOCTL_EXYNOS_IPP_GET_RESOURCES DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_IPP_GET_RESOURCES, struct drm_exynos_ioctl_ipp_get_res)
#define DRM_IOCTL_EXYNOS_IPP_GET_CAPS DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_IPP_GET_CAPS, struct drm_exynos_ioctl_ipp_get_caps)
#define DRM_IOCTL_EXYNOS_IPP_GET_LIMITS DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_IPP_GET_LIMITS, struct drm_exynos_ioctl_ipp_get_limits)
#define DRM_IOCTL_EXYNOS_IPP_COMMIT DRM_IOWR(DRM_COMMAND_BASE + DRM_EXYNOS_IPP_COMMIT, struct drm_exynos_ioctl_ipp_commit)
#define DRM_EXYNOS_G2D_EVENT 0x80000000
#define DRM_EXYNOS_IPP_EVENT 0x80000002
struct drm_exynos_g2d_event {
  struct drm_event base;
  __u64 user_data;
  __u32 tv_sec;
  __u32 tv_usec;
  __u32 cmdlist_no;
  __u32 reserved;
};
struct drm_exynos_ipp_event {
  struct drm_event base;
  __u64 user_data;
  __u32 tv_sec;
  __u32 tv_usec;
  __u32 ipp_id;
  __u32 sequence;
  __u64 reserved;
};
#ifdef __cplusplus
}
#endif
#endif