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
#ifndef _UAPI_VC4_DRM_H_
#define _UAPI_VC4_DRM_H_
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_VC4_SUBMIT_CL 0x00
#define DRM_VC4_WAIT_SEQNO 0x01
#define DRM_VC4_WAIT_BO 0x02
#define DRM_VC4_CREATE_BO 0x03
#define DRM_VC4_MMAP_BO 0x04
#define DRM_VC4_CREATE_SHADER_BO 0x05
#define DRM_VC4_GET_HANG_STATE 0x06
#define DRM_VC4_GET_PARAM 0x07
#define DRM_VC4_SET_TILING 0x08
#define DRM_VC4_GET_TILING 0x09
#define DRM_VC4_LABEL_BO 0x0a
#define DRM_VC4_GEM_MADVISE 0x0b
#define DRM_VC4_PERFMON_CREATE 0x0c
#define DRM_VC4_PERFMON_DESTROY 0x0d
#define DRM_VC4_PERFMON_GET_VALUES 0x0e
#define DRM_IOCTL_VC4_SUBMIT_CL DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_SUBMIT_CL, struct drm_vc4_submit_cl)
#define DRM_IOCTL_VC4_WAIT_SEQNO DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_WAIT_SEQNO, struct drm_vc4_wait_seqno)
#define DRM_IOCTL_VC4_WAIT_BO DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_WAIT_BO, struct drm_vc4_wait_bo)
#define DRM_IOCTL_VC4_CREATE_BO DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_CREATE_BO, struct drm_vc4_create_bo)
#define DRM_IOCTL_VC4_MMAP_BO DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_MMAP_BO, struct drm_vc4_mmap_bo)
#define DRM_IOCTL_VC4_CREATE_SHADER_BO DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_CREATE_SHADER_BO, struct drm_vc4_create_shader_bo)
#define DRM_IOCTL_VC4_GET_HANG_STATE DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_GET_HANG_STATE, struct drm_vc4_get_hang_state)
#define DRM_IOCTL_VC4_GET_PARAM DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_GET_PARAM, struct drm_vc4_get_param)
#define DRM_IOCTL_VC4_SET_TILING DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_SET_TILING, struct drm_vc4_set_tiling)
#define DRM_IOCTL_VC4_GET_TILING DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_GET_TILING, struct drm_vc4_get_tiling)
#define DRM_IOCTL_VC4_LABEL_BO DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_LABEL_BO, struct drm_vc4_label_bo)
#define DRM_IOCTL_VC4_GEM_MADVISE DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_GEM_MADVISE, struct drm_vc4_gem_madvise)
#define DRM_IOCTL_VC4_PERFMON_CREATE DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_PERFMON_CREATE, struct drm_vc4_perfmon_create)
#define DRM_IOCTL_VC4_PERFMON_DESTROY DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_PERFMON_DESTROY, struct drm_vc4_perfmon_destroy)
#define DRM_IOCTL_VC4_PERFMON_GET_VALUES DRM_IOWR(DRM_COMMAND_BASE + DRM_VC4_PERFMON_GET_VALUES, struct drm_vc4_perfmon_get_values)
struct drm_vc4_submit_rcl_surface {
  __u32 hindex;
  __u32 offset;
  __u16 bits;
#define VC4_SUBMIT_RCL_SURFACE_READ_IS_FULL_RES (1 << 0)
  __u16 flags;
};
struct drm_vc4_submit_cl {
  __u64 bin_cl;
  __u64 shader_rec;
  __u64 uniforms;
  __u64 bo_handles;
  __u32 bin_cl_size;
  __u32 shader_rec_size;
  __u32 shader_rec_count;
  __u32 uniforms_size;
  __u32 bo_handle_count;
  __u16 width;
  __u16 height;
  __u8 min_x_tile;
  __u8 min_y_tile;
  __u8 max_x_tile;
  __u8 max_y_tile;
  struct drm_vc4_submit_rcl_surface color_read;
  struct drm_vc4_submit_rcl_surface color_write;
  struct drm_vc4_submit_rcl_surface zs_read;
  struct drm_vc4_submit_rcl_surface zs_write;
  struct drm_vc4_submit_rcl_surface msaa_color_write;
  struct drm_vc4_submit_rcl_surface msaa_zs_write;
  __u32 clear_color[2];
  __u32 clear_z;
  __u8 clear_s;
  __u32 pad : 24;
#define VC4_SUBMIT_CL_USE_CLEAR_COLOR (1 << 0)
#define VC4_SUBMIT_CL_FIXED_RCL_ORDER (1 << 1)
#define VC4_SUBMIT_CL_RCL_ORDER_INCREASING_X (1 << 2)
#define VC4_SUBMIT_CL_RCL_ORDER_INCREASING_Y (1 << 3)
  __u32 flags;
  __u64 seqno;
  __u32 perfmonid;
  __u32 in_sync;
  __u32 out_sync;
  __u32 pad2;
};
struct drm_vc4_wait_seqno {
  __u64 seqno;
  __u64 timeout_ns;
};
struct drm_vc4_wait_bo {
  __u32 handle;
  __u32 pad;
  __u64 timeout_ns;
};
struct drm_vc4_create_bo {
  __u32 size;
  __u32 flags;
  __u32 handle;
  __u32 pad;
};
struct drm_vc4_mmap_bo {
  __u32 handle;
  __u32 flags;
  __u64 offset;
};
struct drm_vc4_create_shader_bo {
  __u32 size;
  __u32 flags;
  __u64 data;
  __u32 handle;
  __u32 pad;
};
struct drm_vc4_get_hang_state_bo {
  __u32 handle;
  __u32 paddr;
  __u32 size;
  __u32 pad;
};
struct drm_vc4_get_hang_state {
  __u64 bo;
  __u32 bo_count;
  __u32 start_bin, start_render;
  __u32 ct0ca, ct0ea;
  __u32 ct1ca, ct1ea;
  __u32 ct0cs, ct1cs;
  __u32 ct0ra0, ct1ra0;
  __u32 bpca, bpcs;
  __u32 bpoa, bpos;
  __u32 vpmbase;
  __u32 dbge;
  __u32 fdbgo;
  __u32 fdbgb;
  __u32 fdbgr;
  __u32 fdbgs;
  __u32 errstat;
  __u32 pad[16];
};
#define DRM_VC4_PARAM_V3D_IDENT0 0
#define DRM_VC4_PARAM_V3D_IDENT1 1
#define DRM_VC4_PARAM_V3D_IDENT2 2
#define DRM_VC4_PARAM_SUPPORTS_BRANCHES 3
#define DRM_VC4_PARAM_SUPPORTS_ETC1 4
#define DRM_VC4_PARAM_SUPPORTS_THREADED_FS 5
#define DRM_VC4_PARAM_SUPPORTS_FIXED_RCL_ORDER 6
#define DRM_VC4_PARAM_SUPPORTS_MADVISE 7
#define DRM_VC4_PARAM_SUPPORTS_PERFMON 8
struct drm_vc4_get_param {
  __u32 param;
  __u32 pad;
  __u64 value;
};
struct drm_vc4_get_tiling {
  __u32 handle;
  __u32 flags;
  __u64 modifier;
};
struct drm_vc4_set_tiling {
  __u32 handle;
  __u32 flags;
  __u64 modifier;
};
struct drm_vc4_label_bo {
  __u32 handle;
  __u32 len;
  __u64 name;
};
#define VC4_MADV_WILLNEED 0
#define VC4_MADV_DONTNEED 1
#define __VC4_MADV_PURGED 2
#define __VC4_MADV_NOTSUPP 3
struct drm_vc4_gem_madvise {
  __u32 handle;
  __u32 madv;
  __u32 retained;
  __u32 pad;
};
enum {
  VC4_PERFCNT_FEP_VALID_PRIMS_NO_RENDER,
  VC4_PERFCNT_FEP_VALID_PRIMS_RENDER,
  VC4_PERFCNT_FEP_CLIPPED_QUADS,
  VC4_PERFCNT_FEP_VALID_QUADS,
  VC4_PERFCNT_TLB_QUADS_NOT_PASSING_STENCIL,
  VC4_PERFCNT_TLB_QUADS_NOT_PASSING_Z_AND_STENCIL,
  VC4_PERFCNT_TLB_QUADS_PASSING_Z_AND_STENCIL,
  VC4_PERFCNT_TLB_QUADS_ZERO_COVERAGE,
  VC4_PERFCNT_TLB_QUADS_NON_ZERO_COVERAGE,
  VC4_PERFCNT_TLB_QUADS_WRITTEN_TO_COLOR_BUF,
  VC4_PERFCNT_PLB_PRIMS_OUTSIDE_VIEWPORT,
  VC4_PERFCNT_PLB_PRIMS_NEED_CLIPPING,
  VC4_PERFCNT_PSE_PRIMS_REVERSED,
  VC4_PERFCNT_QPU_TOTAL_IDLE_CYCLES,
  VC4_PERFCNT_QPU_TOTAL_CLK_CYCLES_VERTEX_COORD_SHADING,
  VC4_PERFCNT_QPU_TOTAL_CLK_CYCLES_FRAGMENT_SHADING,
  VC4_PERFCNT_QPU_TOTAL_CLK_CYCLES_EXEC_VALID_INST,
  VC4_PERFCNT_QPU_TOTAL_CLK_CYCLES_WAITING_TMUS,
  VC4_PERFCNT_QPU_TOTAL_CLK_CYCLES_WAITING_SCOREBOARD,
  VC4_PERFCNT_QPU_TOTAL_CLK_CYCLES_WAITING_VARYINGS,
  VC4_PERFCNT_QPU_TOTAL_INST_CACHE_HIT,
  VC4_PERFCNT_QPU_TOTAL_INST_CACHE_MISS,
  VC4_PERFCNT_QPU_TOTAL_UNIFORM_CACHE_HIT,
  VC4_PERFCNT_QPU_TOTAL_UNIFORM_CACHE_MISS,
  VC4_PERFCNT_TMU_TOTAL_TEXT_QUADS_PROCESSED,
  VC4_PERFCNT_TMU_TOTAL_TEXT_CACHE_MISS,
  VC4_PERFCNT_VPM_TOTAL_CLK_CYCLES_VDW_STALLED,
  VC4_PERFCNT_VPM_TOTAL_CLK_CYCLES_VCD_STALLED,
  VC4_PERFCNT_L2C_TOTAL_L2_CACHE_HIT,
  VC4_PERFCNT_L2C_TOTAL_L2_CACHE_MISS,
  VC4_PERFCNT_NUM_EVENTS,
};
#define DRM_VC4_MAX_PERF_COUNTERS 16
struct drm_vc4_perfmon_create {
  __u32 id;
  __u32 ncounters;
  __u8 events[DRM_VC4_MAX_PERF_COUNTERS];
};
struct drm_vc4_perfmon_destroy {
  __u32 id;
};
struct drm_vc4_perfmon_get_values {
  __u32 id;
  __u64 values_ptr;
};
#ifdef __cplusplus
}
#endif
#endif