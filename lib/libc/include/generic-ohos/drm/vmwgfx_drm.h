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
#ifndef __VMWGFX_DRM_H__
#define __VMWGFX_DRM_H__
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_VMW_MAX_SURFACE_FACES 6
#define DRM_VMW_MAX_MIP_LEVELS 24
#define DRM_VMW_GET_PARAM 0
#define DRM_VMW_ALLOC_DMABUF 1
#define DRM_VMW_ALLOC_BO 1
#define DRM_VMW_UNREF_DMABUF 2
#define DRM_VMW_HANDLE_CLOSE 2
#define DRM_VMW_CURSOR_BYPASS 3
#define DRM_VMW_CONTROL_STREAM 4
#define DRM_VMW_CLAIM_STREAM 5
#define DRM_VMW_UNREF_STREAM 6
#define DRM_VMW_CREATE_CONTEXT 7
#define DRM_VMW_UNREF_CONTEXT 8
#define DRM_VMW_CREATE_SURFACE 9
#define DRM_VMW_UNREF_SURFACE 10
#define DRM_VMW_REF_SURFACE 11
#define DRM_VMW_EXECBUF 12
#define DRM_VMW_GET_3D_CAP 13
#define DRM_VMW_FENCE_WAIT 14
#define DRM_VMW_FENCE_SIGNALED 15
#define DRM_VMW_FENCE_UNREF 16
#define DRM_VMW_FENCE_EVENT 17
#define DRM_VMW_PRESENT 18
#define DRM_VMW_PRESENT_READBACK 19
#define DRM_VMW_UPDATE_LAYOUT 20
#define DRM_VMW_CREATE_SHADER 21
#define DRM_VMW_UNREF_SHADER 22
#define DRM_VMW_GB_SURFACE_CREATE 23
#define DRM_VMW_GB_SURFACE_REF 24
#define DRM_VMW_SYNCCPU 25
#define DRM_VMW_CREATE_EXTENDED_CONTEXT 26
#define DRM_VMW_GB_SURFACE_CREATE_EXT 27
#define DRM_VMW_GB_SURFACE_REF_EXT 28
#define DRM_VMW_MSG 29
#define DRM_VMW_PARAM_NUM_STREAMS 0
#define DRM_VMW_PARAM_NUM_FREE_STREAMS 1
#define DRM_VMW_PARAM_3D 2
#define DRM_VMW_PARAM_HW_CAPS 3
#define DRM_VMW_PARAM_FIFO_CAPS 4
#define DRM_VMW_PARAM_MAX_FB_SIZE 5
#define DRM_VMW_PARAM_FIFO_HW_VERSION 6
#define DRM_VMW_PARAM_MAX_SURF_MEMORY 7
#define DRM_VMW_PARAM_3D_CAPS_SIZE 8
#define DRM_VMW_PARAM_MAX_MOB_MEMORY 9
#define DRM_VMW_PARAM_MAX_MOB_SIZE 10
#define DRM_VMW_PARAM_SCREEN_TARGET 11
#define DRM_VMW_PARAM_DX 12
#define DRM_VMW_PARAM_HW_CAPS2 13
#define DRM_VMW_PARAM_SM4_1 14
#define DRM_VMW_PARAM_SM5 15
enum drm_vmw_handle_type {
  DRM_VMW_HANDLE_LEGACY = 0,
  DRM_VMW_HANDLE_PRIME = 1
};
struct drm_vmw_getparam_arg {
  __u64 value;
  __u32 param;
  __u32 pad64;
};
struct drm_vmw_context_arg {
  __s32 cid;
  __u32 pad64;
};
struct drm_vmw_surface_create_req {
  __u32 flags;
  __u32 format;
  __u32 mip_levels[DRM_VMW_MAX_SURFACE_FACES];
  __u64 size_addr;
  __s32 shareable;
  __s32 scanout;
};
struct drm_vmw_surface_arg {
  __s32 sid;
  enum drm_vmw_handle_type handle_type;
};
struct drm_vmw_size {
  __u32 width;
  __u32 height;
  __u32 depth;
  __u32 pad64;
};
union drm_vmw_surface_create_arg {
  struct drm_vmw_surface_arg rep;
  struct drm_vmw_surface_create_req req;
};
union drm_vmw_surface_reference_arg {
  struct drm_vmw_surface_create_req rep;
  struct drm_vmw_surface_arg req;
};
#define DRM_VMW_EXECBUF_VERSION 2
#define DRM_VMW_EXECBUF_FLAG_IMPORT_FENCE_FD (1 << 0)
#define DRM_VMW_EXECBUF_FLAG_EXPORT_FENCE_FD (1 << 1)
struct drm_vmw_execbuf_arg {
  __u64 commands;
  __u32 command_size;
  __u32 throttle_us;
  __u64 fence_rep;
  __u32 version;
  __u32 flags;
  __u32 context_handle;
  __s32 imported_fence_fd;
};
struct drm_vmw_fence_rep {
  __u32 handle;
  __u32 mask;
  __u32 seqno;
  __u32 passed_seqno;
  __s32 fd;
  __s32 error;
};
struct drm_vmw_alloc_bo_req {
  __u32 size;
  __u32 pad64;
};
#define drm_vmw_alloc_dmabuf_req drm_vmw_alloc_bo_req
struct drm_vmw_bo_rep {
  __u64 map_handle;
  __u32 handle;
  __u32 cur_gmr_id;
  __u32 cur_gmr_offset;
  __u32 pad64;
};
#define drm_vmw_dmabuf_rep drm_vmw_bo_rep
union drm_vmw_alloc_bo_arg {
  struct drm_vmw_alloc_bo_req req;
  struct drm_vmw_bo_rep rep;
};
#define drm_vmw_alloc_dmabuf_arg drm_vmw_alloc_bo_arg
struct drm_vmw_rect {
  __s32 x;
  __s32 y;
  __u32 w;
  __u32 h;
};
struct drm_vmw_control_stream_arg {
  __u32 stream_id;
  __u32 enabled;
  __u32 flags;
  __u32 color_key;
  __u32 handle;
  __u32 offset;
  __s32 format;
  __u32 size;
  __u32 width;
  __u32 height;
  __u32 pitch[3];
  __u32 pad64;
  struct drm_vmw_rect src;
  struct drm_vmw_rect dst;
};
#define DRM_VMW_CURSOR_BYPASS_ALL (1 << 0)
#define DRM_VMW_CURSOR_BYPASS_FLAGS (1)
struct drm_vmw_cursor_bypass_arg {
  __u32 flags;
  __u32 crtc_id;
  __s32 xpos;
  __s32 ypos;
  __s32 xhot;
  __s32 yhot;
};
struct drm_vmw_stream_arg {
  __u32 stream_id;
  __u32 pad64;
};
struct drm_vmw_get_3d_cap_arg {
  __u64 buffer;
  __u32 max_size;
  __u32 pad64;
};
#define DRM_VMW_FENCE_FLAG_EXEC (1 << 0)
#define DRM_VMW_FENCE_FLAG_QUERY (1 << 1)
#define DRM_VMW_WAIT_OPTION_UNREF (1 << 0)
struct drm_vmw_fence_wait_arg {
  __u32 handle;
  __s32 cookie_valid;
  __u64 kernel_cookie;
  __u64 timeout_us;
  __s32 lazy;
  __s32 flags;
  __s32 wait_options;
  __s32 pad64;
};
struct drm_vmw_fence_signaled_arg {
  __u32 handle;
  __u32 flags;
  __s32 signaled;
  __u32 passed_seqno;
  __u32 signaled_flags;
  __u32 pad64;
};
struct drm_vmw_fence_arg {
  __u32 handle;
  __u32 pad64;
};
#define DRM_VMW_EVENT_FENCE_SIGNALED 0x80000000
struct drm_vmw_event_fence {
  struct drm_event base;
  __u64 user_data;
  __u32 tv_sec;
  __u32 tv_usec;
};
#define DRM_VMW_FE_FLAG_REQ_TIME (1 << 0)
struct drm_vmw_fence_event_arg {
  __u64 fence_rep;
  __u64 user_data;
  __u32 handle;
  __u32 flags;
};
struct drm_vmw_present_arg {
  __u32 fb_id;
  __u32 sid;
  __s32 dest_x;
  __s32 dest_y;
  __u64 clips_ptr;
  __u32 num_clips;
  __u32 pad64;
};
struct drm_vmw_present_readback_arg {
  __u32 fb_id;
  __u32 num_clips;
  __u64 clips_ptr;
  __u64 fence_rep;
};
struct drm_vmw_update_layout_arg {
  __u32 num_outputs;
  __u32 pad64;
  __u64 rects;
};
enum drm_vmw_shader_type {
  drm_vmw_shader_type_vs = 0,
  drm_vmw_shader_type_ps,
};
struct drm_vmw_shader_create_arg {
  enum drm_vmw_shader_type shader_type;
  __u32 size;
  __u32 buffer_handle;
  __u32 shader_handle;
  __u64 offset;
};
struct drm_vmw_shader_arg {
  __u32 handle;
  __u32 pad64;
};
enum drm_vmw_surface_flags {
  drm_vmw_surface_flag_shareable = (1 << 0),
  drm_vmw_surface_flag_scanout = (1 << 1),
  drm_vmw_surface_flag_create_buffer = (1 << 2),
  drm_vmw_surface_flag_coherent = (1 << 3),
};
struct drm_vmw_gb_surface_create_req {
  __u32 svga3d_flags;
  __u32 format;
  __u32 mip_levels;
  enum drm_vmw_surface_flags drm_surface_flags;
  __u32 multisample_count;
  __u32 autogen_filter;
  __u32 buffer_handle;
  __u32 array_size;
  struct drm_vmw_size base_size;
};
struct drm_vmw_gb_surface_create_rep {
  __u32 handle;
  __u32 backup_size;
  __u32 buffer_handle;
  __u32 buffer_size;
  __u64 buffer_map_handle;
};
union drm_vmw_gb_surface_create_arg {
  struct drm_vmw_gb_surface_create_rep rep;
  struct drm_vmw_gb_surface_create_req req;
};
struct drm_vmw_gb_surface_ref_rep {
  struct drm_vmw_gb_surface_create_req creq;
  struct drm_vmw_gb_surface_create_rep crep;
};
union drm_vmw_gb_surface_reference_arg {
  struct drm_vmw_gb_surface_ref_rep rep;
  struct drm_vmw_surface_arg req;
};
enum drm_vmw_synccpu_flags {
  drm_vmw_synccpu_read = (1 << 0),
  drm_vmw_synccpu_write = (1 << 1),
  drm_vmw_synccpu_dontblock = (1 << 2),
  drm_vmw_synccpu_allow_cs = (1 << 3)
};
enum drm_vmw_synccpu_op {
  drm_vmw_synccpu_grab,
  drm_vmw_synccpu_release
};
struct drm_vmw_synccpu_arg {
  enum drm_vmw_synccpu_op op;
  enum drm_vmw_synccpu_flags flags;
  __u32 handle;
  __u32 pad64;
};
enum drm_vmw_extended_context {
  drm_vmw_context_legacy,
  drm_vmw_context_dx
};
union drm_vmw_extended_context_arg {
  enum drm_vmw_extended_context req;
  struct drm_vmw_context_arg rep;
};
struct drm_vmw_handle_close_arg {
  __u32 handle;
  __u32 pad64;
};
#define drm_vmw_unref_dmabuf_arg drm_vmw_handle_close_arg
enum drm_vmw_surface_version {
  drm_vmw_gb_surface_v1,
};
struct drm_vmw_gb_surface_create_ext_req {
  struct drm_vmw_gb_surface_create_req base;
  enum drm_vmw_surface_version version;
  __u32 svga3d_flags_upper_32_bits;
  __u32 multisample_pattern;
  __u32 quality_level;
  __u32 buffer_byte_stride;
  __u32 must_be_zero;
};
union drm_vmw_gb_surface_create_ext_arg {
  struct drm_vmw_gb_surface_create_rep rep;
  struct drm_vmw_gb_surface_create_ext_req req;
};
struct drm_vmw_gb_surface_ref_ext_rep {
  struct drm_vmw_gb_surface_create_ext_req creq;
  struct drm_vmw_gb_surface_create_rep crep;
};
union drm_vmw_gb_surface_reference_ext_arg {
  struct drm_vmw_gb_surface_ref_ext_rep rep;
  struct drm_vmw_surface_arg req;
};
struct drm_vmw_msg_arg {
  __u64 send;
  __u64 receive;
  __s32 send_only;
  __u32 receive_len;
};
#ifdef __cplusplus
}
#endif
#endif