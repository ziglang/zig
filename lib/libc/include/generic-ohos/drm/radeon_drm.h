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
#ifndef __RADEON_DRM_H__
#define __RADEON_DRM_H__
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#ifndef __RADEON_SAREA_DEFINES__
#define __RADEON_SAREA_DEFINES__
#define RADEON_UPLOAD_CONTEXT 0x00000001
#define RADEON_UPLOAD_VERTFMT 0x00000002
#define RADEON_UPLOAD_LINE 0x00000004
#define RADEON_UPLOAD_BUMPMAP 0x00000008
#define RADEON_UPLOAD_MASKS 0x00000010
#define RADEON_UPLOAD_VIEWPORT 0x00000020
#define RADEON_UPLOAD_SETUP 0x00000040
#define RADEON_UPLOAD_TCL 0x00000080
#define RADEON_UPLOAD_MISC 0x00000100
#define RADEON_UPLOAD_TEX0 0x00000200
#define RADEON_UPLOAD_TEX1 0x00000400
#define RADEON_UPLOAD_TEX2 0x00000800
#define RADEON_UPLOAD_TEX0IMAGES 0x00001000
#define RADEON_UPLOAD_TEX1IMAGES 0x00002000
#define RADEON_UPLOAD_TEX2IMAGES 0x00004000
#define RADEON_UPLOAD_CLIPRECTS 0x00008000
#define RADEON_REQUIRE_QUIESCENCE 0x00010000
#define RADEON_UPLOAD_ZBIAS 0x00020000
#define RADEON_UPLOAD_ALL 0x003effff
#define RADEON_UPLOAD_CONTEXT_ALL 0x003e01ff
#define RADEON_EMIT_PP_MISC 0
#define RADEON_EMIT_PP_CNTL 1
#define RADEON_EMIT_RB3D_COLORPITCH 2
#define RADEON_EMIT_RE_LINE_PATTERN 3
#define RADEON_EMIT_SE_LINE_WIDTH 4
#define RADEON_EMIT_PP_LUM_MATRIX 5
#define RADEON_EMIT_PP_ROT_MATRIX_0 6
#define RADEON_EMIT_RB3D_STENCILREFMASK 7
#define RADEON_EMIT_SE_VPORT_XSCALE 8
#define RADEON_EMIT_SE_CNTL 9
#define RADEON_EMIT_SE_CNTL_STATUS 10
#define RADEON_EMIT_RE_MISC 11
#define RADEON_EMIT_PP_TXFILTER_0 12
#define RADEON_EMIT_PP_BORDER_COLOR_0 13
#define RADEON_EMIT_PP_TXFILTER_1 14
#define RADEON_EMIT_PP_BORDER_COLOR_1 15
#define RADEON_EMIT_PP_TXFILTER_2 16
#define RADEON_EMIT_PP_BORDER_COLOR_2 17
#define RADEON_EMIT_SE_ZBIAS_FACTOR 18
#define RADEON_EMIT_SE_TCL_OUTPUT_VTX_FMT 19
#define RADEON_EMIT_SE_TCL_MATERIAL_EMMISSIVE_RED 20
#define R200_EMIT_PP_TXCBLEND_0 21
#define R200_EMIT_PP_TXCBLEND_1 22
#define R200_EMIT_PP_TXCBLEND_2 23
#define R200_EMIT_PP_TXCBLEND_3 24
#define R200_EMIT_PP_TXCBLEND_4 25
#define R200_EMIT_PP_TXCBLEND_5 26
#define R200_EMIT_PP_TXCBLEND_6 27
#define R200_EMIT_PP_TXCBLEND_7 28
#define R200_EMIT_TCL_LIGHT_MODEL_CTL_0 29
#define R200_EMIT_TFACTOR_0 30
#define R200_EMIT_VTX_FMT_0 31
#define R200_EMIT_VAP_CTL 32
#define R200_EMIT_MATRIX_SELECT_0 33
#define R200_EMIT_TEX_PROC_CTL_2 34
#define R200_EMIT_TCL_UCP_VERT_BLEND_CTL 35
#define R200_EMIT_PP_TXFILTER_0 36
#define R200_EMIT_PP_TXFILTER_1 37
#define R200_EMIT_PP_TXFILTER_2 38
#define R200_EMIT_PP_TXFILTER_3 39
#define R200_EMIT_PP_TXFILTER_4 40
#define R200_EMIT_PP_TXFILTER_5 41
#define R200_EMIT_PP_TXOFFSET_0 42
#define R200_EMIT_PP_TXOFFSET_1 43
#define R200_EMIT_PP_TXOFFSET_2 44
#define R200_EMIT_PP_TXOFFSET_3 45
#define R200_EMIT_PP_TXOFFSET_4 46
#define R200_EMIT_PP_TXOFFSET_5 47
#define R200_EMIT_VTE_CNTL 48
#define R200_EMIT_OUTPUT_VTX_COMP_SEL 49
#define R200_EMIT_PP_TAM_DEBUG3 50
#define R200_EMIT_PP_CNTL_X 51
#define R200_EMIT_RB3D_DEPTHXY_OFFSET 52
#define R200_EMIT_RE_AUX_SCISSOR_CNTL 53
#define R200_EMIT_RE_SCISSOR_TL_0 54
#define R200_EMIT_RE_SCISSOR_TL_1 55
#define R200_EMIT_RE_SCISSOR_TL_2 56
#define R200_EMIT_SE_VAP_CNTL_STATUS 57
#define R200_EMIT_SE_VTX_STATE_CNTL 58
#define R200_EMIT_RE_POINTSIZE 59
#define R200_EMIT_TCL_INPUT_VTX_VECTOR_ADDR_0 60
#define R200_EMIT_PP_CUBIC_FACES_0 61
#define R200_EMIT_PP_CUBIC_OFFSETS_0 62
#define R200_EMIT_PP_CUBIC_FACES_1 63
#define R200_EMIT_PP_CUBIC_OFFSETS_1 64
#define R200_EMIT_PP_CUBIC_FACES_2 65
#define R200_EMIT_PP_CUBIC_OFFSETS_2 66
#define R200_EMIT_PP_CUBIC_FACES_3 67
#define R200_EMIT_PP_CUBIC_OFFSETS_3 68
#define R200_EMIT_PP_CUBIC_FACES_4 69
#define R200_EMIT_PP_CUBIC_OFFSETS_4 70
#define R200_EMIT_PP_CUBIC_FACES_5 71
#define R200_EMIT_PP_CUBIC_OFFSETS_5 72
#define RADEON_EMIT_PP_TEX_SIZE_0 73
#define RADEON_EMIT_PP_TEX_SIZE_1 74
#define RADEON_EMIT_PP_TEX_SIZE_2 75
#define R200_EMIT_RB3D_BLENDCOLOR 76
#define R200_EMIT_TCL_POINT_SPRITE_CNTL 77
#define RADEON_EMIT_PP_CUBIC_FACES_0 78
#define RADEON_EMIT_PP_CUBIC_OFFSETS_T0 79
#define RADEON_EMIT_PP_CUBIC_FACES_1 80
#define RADEON_EMIT_PP_CUBIC_OFFSETS_T1 81
#define RADEON_EMIT_PP_CUBIC_FACES_2 82
#define RADEON_EMIT_PP_CUBIC_OFFSETS_T2 83
#define R200_EMIT_PP_TRI_PERF_CNTL 84
#define R200_EMIT_PP_AFS_0 85
#define R200_EMIT_PP_AFS_1 86
#define R200_EMIT_ATF_TFACTOR 87
#define R200_EMIT_PP_TXCTLALL_0 88
#define R200_EMIT_PP_TXCTLALL_1 89
#define R200_EMIT_PP_TXCTLALL_2 90
#define R200_EMIT_PP_TXCTLALL_3 91
#define R200_EMIT_PP_TXCTLALL_4 92
#define R200_EMIT_PP_TXCTLALL_5 93
#define R200_EMIT_VAP_PVS_CNTL 94
#define RADEON_MAX_STATE_PACKETS 95
#define RADEON_CMD_PACKET 1
#define RADEON_CMD_SCALARS 2
#define RADEON_CMD_VECTORS 3
#define RADEON_CMD_DMA_DISCARD 4
#define RADEON_CMD_PACKET3 5
#define RADEON_CMD_PACKET3_CLIP 6
#define RADEON_CMD_SCALARS2 7
#define RADEON_CMD_WAIT 8
#define RADEON_CMD_VECLINEAR 9
typedef union {
  int i;
  struct {
    unsigned char cmd_type, pad0, pad1, pad2;
  } header;
  struct {
    unsigned char cmd_type, packet_id, pad0, pad1;
  } packet;
  struct {
    unsigned char cmd_type, offset, stride, count;
  } scalars;
  struct {
    unsigned char cmd_type, offset, stride, count;
  } vectors;
  struct {
    unsigned char cmd_type, addr_lo, addr_hi, count;
  } veclinear;
  struct {
    unsigned char cmd_type, buf_idx, pad0, pad1;
  } dma;
  struct {
    unsigned char cmd_type, flags, pad0, pad1;
  } wait;
} drm_radeon_cmd_header_t;
#define RADEON_WAIT_2D 0x1
#define RADEON_WAIT_3D 0x2
#define R300_CMD_PACKET3_CLEAR 0
#define R300_CMD_PACKET3_RAW 1
#define R300_CMD_PACKET0 1
#define R300_CMD_VPU 2
#define R300_CMD_PACKET3 3
#define R300_CMD_END3D 4
#define R300_CMD_CP_DELAY 5
#define R300_CMD_DMA_DISCARD 6
#define R300_CMD_WAIT 7
#define R300_WAIT_2D 0x1
#define R300_WAIT_3D 0x2
#define R300_WAIT_2D_CLEAN 0x3
#define R300_WAIT_3D_CLEAN 0x4
#define R300_NEW_WAIT_2D_3D 0x3
#define R300_NEW_WAIT_2D_2D_CLEAN 0x4
#define R300_NEW_WAIT_3D_3D_CLEAN 0x6
#define R300_NEW_WAIT_2D_2D_CLEAN_3D_3D_CLEAN 0x8
#define R300_CMD_SCRATCH 8
#define R300_CMD_R500FP 9
typedef union {
  unsigned int u;
  struct {
    unsigned char cmd_type, pad0, pad1, pad2;
  } header;
  struct {
    unsigned char cmd_type, count, reglo, reghi;
  } packet0;
  struct {
    unsigned char cmd_type, count, adrlo, adrhi;
  } vpu;
  struct {
    unsigned char cmd_type, packet, pad0, pad1;
  } packet3;
  struct {
    unsigned char cmd_type, packet;
    unsigned short count;
  } delay;
  struct {
    unsigned char cmd_type, buf_idx, pad0, pad1;
  } dma;
  struct {
    unsigned char cmd_type, flags, pad0, pad1;
  } wait;
  struct {
    unsigned char cmd_type, reg, n_bufs, flags;
  } scratch;
  struct {
    unsigned char cmd_type, count, adrlo, adrhi_flags;
  } r500fp;
} drm_r300_cmd_header_t;
#define RADEON_FRONT 0x1
#define RADEON_BACK 0x2
#define RADEON_DEPTH 0x4
#define RADEON_STENCIL 0x8
#define RADEON_CLEAR_FASTZ 0x80000000
#define RADEON_USE_HIERZ 0x40000000
#define RADEON_USE_COMP_ZBUF 0x20000000
#define R500FP_CONSTANT_TYPE (1 << 1)
#define R500FP_CONSTANT_CLAMP (1 << 2)
#define RADEON_POINTS 0x1
#define RADEON_LINES 0x2
#define RADEON_LINE_STRIP 0x3
#define RADEON_TRIANGLES 0x4
#define RADEON_TRIANGLE_FAN 0x5
#define RADEON_TRIANGLE_STRIP 0x6
#define RADEON_BUFFER_SIZE 65536
#define RADEON_INDEX_PRIM_OFFSET 20
#define RADEON_SCRATCH_REG_OFFSET 32
#define R600_SCRATCH_REG_OFFSET 256
#define RADEON_NR_SAREA_CLIPRECTS 12
#define RADEON_LOCAL_TEX_HEAP 0
#define RADEON_GART_TEX_HEAP 1
#define RADEON_NR_TEX_HEAPS 2
#define RADEON_NR_TEX_REGIONS 64
#define RADEON_LOG_TEX_GRANULARITY 16
#define RADEON_MAX_TEXTURE_LEVELS 12
#define RADEON_MAX_TEXTURE_UNITS 3
#define RADEON_MAX_SURFACES 8
#define RADEON_OFFSET_SHIFT 10
#define RADEON_OFFSET_ALIGN (1 << RADEON_OFFSET_SHIFT)
#define RADEON_OFFSET_MASK (RADEON_OFFSET_ALIGN - 1)
#endif
typedef struct {
  unsigned int red;
  unsigned int green;
  unsigned int blue;
  unsigned int alpha;
} radeon_color_regs_t;
typedef struct {
  unsigned int pp_misc;
  unsigned int pp_fog_color;
  unsigned int re_solid_color;
  unsigned int rb3d_blendcntl;
  unsigned int rb3d_depthoffset;
  unsigned int rb3d_depthpitch;
  unsigned int rb3d_zstencilcntl;
  unsigned int pp_cntl;
  unsigned int rb3d_cntl;
  unsigned int rb3d_coloroffset;
  unsigned int re_width_height;
  unsigned int rb3d_colorpitch;
  unsigned int se_cntl;
  unsigned int se_coord_fmt;
  unsigned int re_line_pattern;
  unsigned int re_line_state;
  unsigned int se_line_width;
  unsigned int pp_lum_matrix;
  unsigned int pp_rot_matrix_0;
  unsigned int pp_rot_matrix_1;
  unsigned int rb3d_stencilrefmask;
  unsigned int rb3d_ropcntl;
  unsigned int rb3d_planemask;
  unsigned int se_vport_xscale;
  unsigned int se_vport_xoffset;
  unsigned int se_vport_yscale;
  unsigned int se_vport_yoffset;
  unsigned int se_vport_zscale;
  unsigned int se_vport_zoffset;
  unsigned int se_cntl_status;
  unsigned int re_top_left;
  unsigned int re_misc;
} drm_radeon_context_regs_t;
typedef struct {
  unsigned int se_zbias_factor;
  unsigned int se_zbias_constant;
} drm_radeon_context2_regs_t;
typedef struct {
  unsigned int pp_txfilter;
  unsigned int pp_txformat;
  unsigned int pp_txoffset;
  unsigned int pp_txcblend;
  unsigned int pp_txablend;
  unsigned int pp_tfactor;
  unsigned int pp_border_color;
} drm_radeon_texture_regs_t;
typedef struct {
  unsigned int start;
  unsigned int finish;
  unsigned int prim : 8;
  unsigned int stateidx : 8;
  unsigned int numverts : 16;
  unsigned int vc_format;
} drm_radeon_prim_t;
typedef struct {
  drm_radeon_context_regs_t context;
  drm_radeon_texture_regs_t tex[RADEON_MAX_TEXTURE_UNITS];
  drm_radeon_context2_regs_t context2;
  unsigned int dirty;
} drm_radeon_state_t;
typedef struct {
  drm_radeon_context_regs_t context_state;
  drm_radeon_texture_regs_t tex_state[RADEON_MAX_TEXTURE_UNITS];
  unsigned int dirty;
  unsigned int vertsize;
  unsigned int vc_format;
  struct drm_clip_rect boxes[RADEON_NR_SAREA_CLIPRECTS];
  unsigned int nbox;
  unsigned int last_frame;
  unsigned int last_dispatch;
  unsigned int last_clear;
  struct drm_tex_region tex_list[RADEON_NR_TEX_HEAPS][RADEON_NR_TEX_REGIONS + 1];
  unsigned int tex_age[RADEON_NR_TEX_HEAPS];
  int ctx_owner;
  int pfState;
  int pfCurrentPage;
  int crtc2_base;
  int tiling_enabled;
} drm_radeon_sarea_t;
#define DRM_RADEON_CP_INIT 0x00
#define DRM_RADEON_CP_START 0x01
#define DRM_RADEON_CP_STOP 0x02
#define DRM_RADEON_CP_RESET 0x03
#define DRM_RADEON_CP_IDLE 0x04
#define DRM_RADEON_RESET 0x05
#define DRM_RADEON_FULLSCREEN 0x06
#define DRM_RADEON_SWAP 0x07
#define DRM_RADEON_CLEAR 0x08
#define DRM_RADEON_VERTEX 0x09
#define DRM_RADEON_INDICES 0x0A
#define DRM_RADEON_NOT_USED
#define DRM_RADEON_STIPPLE 0x0C
#define DRM_RADEON_INDIRECT 0x0D
#define DRM_RADEON_TEXTURE 0x0E
#define DRM_RADEON_VERTEX2 0x0F
#define DRM_RADEON_CMDBUF 0x10
#define DRM_RADEON_GETPARAM 0x11
#define DRM_RADEON_FLIP 0x12
#define DRM_RADEON_ALLOC 0x13
#define DRM_RADEON_FREE 0x14
#define DRM_RADEON_INIT_HEAP 0x15
#define DRM_RADEON_IRQ_EMIT 0x16
#define DRM_RADEON_IRQ_WAIT 0x17
#define DRM_RADEON_CP_RESUME 0x18
#define DRM_RADEON_SETPARAM 0x19
#define DRM_RADEON_SURF_ALLOC 0x1a
#define DRM_RADEON_SURF_FREE 0x1b
#define DRM_RADEON_GEM_INFO 0x1c
#define DRM_RADEON_GEM_CREATE 0x1d
#define DRM_RADEON_GEM_MMAP 0x1e
#define DRM_RADEON_GEM_PREAD 0x21
#define DRM_RADEON_GEM_PWRITE 0x22
#define DRM_RADEON_GEM_SET_DOMAIN 0x23
#define DRM_RADEON_GEM_WAIT_IDLE 0x24
#define DRM_RADEON_CS 0x26
#define DRM_RADEON_INFO 0x27
#define DRM_RADEON_GEM_SET_TILING 0x28
#define DRM_RADEON_GEM_GET_TILING 0x29
#define DRM_RADEON_GEM_BUSY 0x2a
#define DRM_RADEON_GEM_VA 0x2b
#define DRM_RADEON_GEM_OP 0x2c
#define DRM_RADEON_GEM_USERPTR 0x2d
#define DRM_IOCTL_RADEON_CP_INIT DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_CP_INIT, drm_radeon_init_t)
#define DRM_IOCTL_RADEON_CP_START DRM_IO(DRM_COMMAND_BASE + DRM_RADEON_CP_START)
#define DRM_IOCTL_RADEON_CP_STOP DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_CP_STOP, drm_radeon_cp_stop_t)
#define DRM_IOCTL_RADEON_CP_RESET DRM_IO(DRM_COMMAND_BASE + DRM_RADEON_CP_RESET)
#define DRM_IOCTL_RADEON_CP_IDLE DRM_IO(DRM_COMMAND_BASE + DRM_RADEON_CP_IDLE)
#define DRM_IOCTL_RADEON_RESET DRM_IO(DRM_COMMAND_BASE + DRM_RADEON_RESET)
#define DRM_IOCTL_RADEON_FULLSCREEN DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_FULLSCREEN, drm_radeon_fullscreen_t)
#define DRM_IOCTL_RADEON_SWAP DRM_IO(DRM_COMMAND_BASE + DRM_RADEON_SWAP)
#define DRM_IOCTL_RADEON_CLEAR DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_CLEAR, drm_radeon_clear_t)
#define DRM_IOCTL_RADEON_VERTEX DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_VERTEX, drm_radeon_vertex_t)
#define DRM_IOCTL_RADEON_INDICES DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_INDICES, drm_radeon_indices_t)
#define DRM_IOCTL_RADEON_STIPPLE DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_STIPPLE, drm_radeon_stipple_t)
#define DRM_IOCTL_RADEON_INDIRECT DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_INDIRECT, drm_radeon_indirect_t)
#define DRM_IOCTL_RADEON_TEXTURE DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_TEXTURE, drm_radeon_texture_t)
#define DRM_IOCTL_RADEON_VERTEX2 DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_VERTEX2, drm_radeon_vertex2_t)
#define DRM_IOCTL_RADEON_CMDBUF DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_CMDBUF, drm_radeon_cmd_buffer_t)
#define DRM_IOCTL_RADEON_GETPARAM DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GETPARAM, drm_radeon_getparam_t)
#define DRM_IOCTL_RADEON_FLIP DRM_IO(DRM_COMMAND_BASE + DRM_RADEON_FLIP)
#define DRM_IOCTL_RADEON_ALLOC DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_ALLOC, drm_radeon_mem_alloc_t)
#define DRM_IOCTL_RADEON_FREE DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_FREE, drm_radeon_mem_free_t)
#define DRM_IOCTL_RADEON_INIT_HEAP DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_INIT_HEAP, drm_radeon_mem_init_heap_t)
#define DRM_IOCTL_RADEON_IRQ_EMIT DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_IRQ_EMIT, drm_radeon_irq_emit_t)
#define DRM_IOCTL_RADEON_IRQ_WAIT DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_IRQ_WAIT, drm_radeon_irq_wait_t)
#define DRM_IOCTL_RADEON_CP_RESUME DRM_IO(DRM_COMMAND_BASE + DRM_RADEON_CP_RESUME)
#define DRM_IOCTL_RADEON_SETPARAM DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_SETPARAM, drm_radeon_setparam_t)
#define DRM_IOCTL_RADEON_SURF_ALLOC DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_SURF_ALLOC, drm_radeon_surface_alloc_t)
#define DRM_IOCTL_RADEON_SURF_FREE DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_SURF_FREE, drm_radeon_surface_free_t)
#define DRM_IOCTL_RADEON_GEM_INFO DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_INFO, struct drm_radeon_gem_info)
#define DRM_IOCTL_RADEON_GEM_CREATE DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_CREATE, struct drm_radeon_gem_create)
#define DRM_IOCTL_RADEON_GEM_MMAP DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_MMAP, struct drm_radeon_gem_mmap)
#define DRM_IOCTL_RADEON_GEM_PREAD DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_PREAD, struct drm_radeon_gem_pread)
#define DRM_IOCTL_RADEON_GEM_PWRITE DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_PWRITE, struct drm_radeon_gem_pwrite)
#define DRM_IOCTL_RADEON_GEM_SET_DOMAIN DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_SET_DOMAIN, struct drm_radeon_gem_set_domain)
#define DRM_IOCTL_RADEON_GEM_WAIT_IDLE DRM_IOW(DRM_COMMAND_BASE + DRM_RADEON_GEM_WAIT_IDLE, struct drm_radeon_gem_wait_idle)
#define DRM_IOCTL_RADEON_CS DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_CS, struct drm_radeon_cs)
#define DRM_IOCTL_RADEON_INFO DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_INFO, struct drm_radeon_info)
#define DRM_IOCTL_RADEON_GEM_SET_TILING DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_SET_TILING, struct drm_radeon_gem_set_tiling)
#define DRM_IOCTL_RADEON_GEM_GET_TILING DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_GET_TILING, struct drm_radeon_gem_get_tiling)
#define DRM_IOCTL_RADEON_GEM_BUSY DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_BUSY, struct drm_radeon_gem_busy)
#define DRM_IOCTL_RADEON_GEM_VA DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_VA, struct drm_radeon_gem_va)
#define DRM_IOCTL_RADEON_GEM_OP DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_OP, struct drm_radeon_gem_op)
#define DRM_IOCTL_RADEON_GEM_USERPTR DRM_IOWR(DRM_COMMAND_BASE + DRM_RADEON_GEM_USERPTR, struct drm_radeon_gem_userptr)
typedef struct drm_radeon_init {
  enum {
    RADEON_INIT_CP = 0x01,
    RADEON_CLEANUP_CP = 0x02,
    RADEON_INIT_R200_CP = 0x03,
    RADEON_INIT_R300_CP = 0x04,
    RADEON_INIT_R600_CP = 0x05
  } func;
  unsigned long sarea_priv_offset;
  int is_pci;
  int cp_mode;
  int gart_size;
  int ring_size;
  int usec_timeout;
  unsigned int fb_bpp;
  unsigned int front_offset, front_pitch;
  unsigned int back_offset, back_pitch;
  unsigned int depth_bpp;
  unsigned int depth_offset, depth_pitch;
  unsigned long fb_offset;
  unsigned long mmio_offset;
  unsigned long ring_offset;
  unsigned long ring_rptr_offset;
  unsigned long buffers_offset;
  unsigned long gart_textures_offset;
} drm_radeon_init_t;
typedef struct drm_radeon_cp_stop {
  int flush;
  int idle;
} drm_radeon_cp_stop_t;
typedef struct drm_radeon_fullscreen {
  enum {
    RADEON_INIT_FULLSCREEN = 0x01,
    RADEON_CLEANUP_FULLSCREEN = 0x02
  } func;
} drm_radeon_fullscreen_t;
#define CLEAR_X1 0
#define CLEAR_Y1 1
#define CLEAR_X2 2
#define CLEAR_Y2 3
#define CLEAR_DEPTH 4
typedef union drm_radeon_clear_rect {
  float f[5];
  unsigned int ui[5];
} drm_radeon_clear_rect_t;
typedef struct drm_radeon_clear {
  unsigned int flags;
  unsigned int clear_color;
  unsigned int clear_depth;
  unsigned int color_mask;
  unsigned int depth_mask;
  drm_radeon_clear_rect_t __user * depth_boxes;
} drm_radeon_clear_t;
typedef struct drm_radeon_vertex {
  int prim;
  int idx;
  int count;
  int discard;
} drm_radeon_vertex_t;
typedef struct drm_radeon_indices {
  int prim;
  int idx;
  int start;
  int end;
  int discard;
} drm_radeon_indices_t;
typedef struct drm_radeon_vertex2 {
  int idx;
  int discard;
  int nr_states;
  drm_radeon_state_t __user * state;
  int nr_prims;
  drm_radeon_prim_t __user * prim;
} drm_radeon_vertex2_t;
typedef struct drm_radeon_cmd_buffer {
  int bufsz;
  char __user * buf;
  int nbox;
  struct drm_clip_rect __user * boxes;
} drm_radeon_cmd_buffer_t;
typedef struct drm_radeon_tex_image {
  unsigned int x, y;
  unsigned int width, height;
  const void __user * data;
} drm_radeon_tex_image_t;
typedef struct drm_radeon_texture {
  unsigned int offset;
  int pitch;
  int format;
  int width;
  int height;
  drm_radeon_tex_image_t __user * image;
} drm_radeon_texture_t;
typedef struct drm_radeon_stipple {
  unsigned int __user * mask;
} drm_radeon_stipple_t;
typedef struct drm_radeon_indirect {
  int idx;
  int start;
  int end;
  int discard;
} drm_radeon_indirect_t;
#define RADEON_CARD_PCI 0
#define RADEON_CARD_AGP 1
#define RADEON_CARD_PCIE 2
#define RADEON_PARAM_GART_BUFFER_OFFSET 1
#define RADEON_PARAM_LAST_FRAME 2
#define RADEON_PARAM_LAST_DISPATCH 3
#define RADEON_PARAM_LAST_CLEAR 4
#define RADEON_PARAM_IRQ_NR 5
#define RADEON_PARAM_GART_BASE 6
#define RADEON_PARAM_REGISTER_HANDLE 7
#define RADEON_PARAM_STATUS_HANDLE 8
#define RADEON_PARAM_SAREA_HANDLE 9
#define RADEON_PARAM_GART_TEX_HANDLE 10
#define RADEON_PARAM_SCRATCH_OFFSET 11
#define RADEON_PARAM_CARD_TYPE 12
#define RADEON_PARAM_VBLANK_CRTC 13
#define RADEON_PARAM_FB_LOCATION 14
#define RADEON_PARAM_NUM_GB_PIPES 15
#define RADEON_PARAM_DEVICE_ID 16
#define RADEON_PARAM_NUM_Z_PIPES 17
typedef struct drm_radeon_getparam {
  int param;
  void __user * value;
} drm_radeon_getparam_t;
#define RADEON_MEM_REGION_GART 1
#define RADEON_MEM_REGION_FB 2
typedef struct drm_radeon_mem_alloc {
  int region;
  int alignment;
  int size;
  int __user * region_offset;
} drm_radeon_mem_alloc_t;
typedef struct drm_radeon_mem_free {
  int region;
  int region_offset;
} drm_radeon_mem_free_t;
typedef struct drm_radeon_mem_init_heap {
  int region;
  int size;
  int start;
} drm_radeon_mem_init_heap_t;
typedef struct drm_radeon_irq_emit {
  int __user * irq_seq;
} drm_radeon_irq_emit_t;
typedef struct drm_radeon_irq_wait {
  int irq_seq;
} drm_radeon_irq_wait_t;
typedef struct drm_radeon_setparam {
  unsigned int param;
  __s64 value;
} drm_radeon_setparam_t;
#define RADEON_SETPARAM_FB_LOCATION 1
#define RADEON_SETPARAM_SWITCH_TILING 2
#define RADEON_SETPARAM_PCIGART_LOCATION 3
#define RADEON_SETPARAM_NEW_MEMMAP 4
#define RADEON_SETPARAM_PCIGART_TABLE_SIZE 5
#define RADEON_SETPARAM_VBLANK_CRTC 6
typedef struct drm_radeon_surface_alloc {
  unsigned int address;
  unsigned int size;
  unsigned int flags;
} drm_radeon_surface_alloc_t;
typedef struct drm_radeon_surface_free {
  unsigned int address;
} drm_radeon_surface_free_t;
#define DRM_RADEON_VBLANK_CRTC1 1
#define DRM_RADEON_VBLANK_CRTC2 2
#define RADEON_GEM_DOMAIN_CPU 0x1
#define RADEON_GEM_DOMAIN_GTT 0x2
#define RADEON_GEM_DOMAIN_VRAM 0x4
struct drm_radeon_gem_info {
  __u64 gart_size;
  __u64 vram_size;
  __u64 vram_visible;
};
#define RADEON_GEM_NO_BACKING_STORE (1 << 0)
#define RADEON_GEM_GTT_UC (1 << 1)
#define RADEON_GEM_GTT_WC (1 << 2)
#define RADEON_GEM_CPU_ACCESS (1 << 3)
#define RADEON_GEM_NO_CPU_ACCESS (1 << 4)
struct drm_radeon_gem_create {
  __u64 size;
  __u64 alignment;
  __u32 handle;
  __u32 initial_domain;
  __u32 flags;
};
#define RADEON_GEM_USERPTR_READONLY (1 << 0)
#define RADEON_GEM_USERPTR_ANONONLY (1 << 1)
#define RADEON_GEM_USERPTR_VALIDATE (1 << 2)
#define RADEON_GEM_USERPTR_REGISTER (1 << 3)
struct drm_radeon_gem_userptr {
  __u64 addr;
  __u64 size;
  __u32 flags;
  __u32 handle;
};
#define RADEON_TILING_MACRO 0x1
#define RADEON_TILING_MICRO 0x2
#define RADEON_TILING_SWAP_16BIT 0x4
#define RADEON_TILING_SWAP_32BIT 0x8
#define RADEON_TILING_SURFACE 0x10
#define RADEON_TILING_MICRO_SQUARE 0x20
#define RADEON_TILING_EG_BANKW_SHIFT 8
#define RADEON_TILING_EG_BANKW_MASK 0xf
#define RADEON_TILING_EG_BANKH_SHIFT 12
#define RADEON_TILING_EG_BANKH_MASK 0xf
#define RADEON_TILING_EG_MACRO_TILE_ASPECT_SHIFT 16
#define RADEON_TILING_EG_MACRO_TILE_ASPECT_MASK 0xf
#define RADEON_TILING_EG_TILE_SPLIT_SHIFT 24
#define RADEON_TILING_EG_TILE_SPLIT_MASK 0xf
#define RADEON_TILING_EG_STENCIL_TILE_SPLIT_SHIFT 28
#define RADEON_TILING_EG_STENCIL_TILE_SPLIT_MASK 0xf
struct drm_radeon_gem_set_tiling {
  __u32 handle;
  __u32 tiling_flags;
  __u32 pitch;
};
struct drm_radeon_gem_get_tiling {
  __u32 handle;
  __u32 tiling_flags;
  __u32 pitch;
};
struct drm_radeon_gem_mmap {
  __u32 handle;
  __u32 pad;
  __u64 offset;
  __u64 size;
  __u64 addr_ptr;
};
struct drm_radeon_gem_set_domain {
  __u32 handle;
  __u32 read_domains;
  __u32 write_domain;
};
struct drm_radeon_gem_wait_idle {
  __u32 handle;
  __u32 pad;
};
struct drm_radeon_gem_busy {
  __u32 handle;
  __u32 domain;
};
struct drm_radeon_gem_pread {
  __u32 handle;
  __u32 pad;
  __u64 offset;
  __u64 size;
  __u64 data_ptr;
};
struct drm_radeon_gem_pwrite {
  __u32 handle;
  __u32 pad;
  __u64 offset;
  __u64 size;
  __u64 data_ptr;
};
struct drm_radeon_gem_op {
  __u32 handle;
  __u32 op;
  __u64 value;
};
#define RADEON_GEM_OP_GET_INITIAL_DOMAIN 0
#define RADEON_GEM_OP_SET_INITIAL_DOMAIN 1
#define RADEON_VA_MAP 1
#define RADEON_VA_UNMAP 2
#define RADEON_VA_RESULT_OK 0
#define RADEON_VA_RESULT_ERROR 1
#define RADEON_VA_RESULT_VA_EXIST 2
#define RADEON_VM_PAGE_VALID (1 << 0)
#define RADEON_VM_PAGE_READABLE (1 << 1)
#define RADEON_VM_PAGE_WRITEABLE (1 << 2)
#define RADEON_VM_PAGE_SYSTEM (1 << 3)
#define RADEON_VM_PAGE_SNOOPED (1 << 4)
struct drm_radeon_gem_va {
  __u32 handle;
  __u32 operation;
  __u32 vm_id;
  __u32 flags;
  __u64 offset;
};
#define RADEON_CHUNK_ID_RELOCS 0x01
#define RADEON_CHUNK_ID_IB 0x02
#define RADEON_CHUNK_ID_FLAGS 0x03
#define RADEON_CHUNK_ID_CONST_IB 0x04
#define RADEON_CS_KEEP_TILING_FLAGS 0x01
#define RADEON_CS_USE_VM 0x02
#define RADEON_CS_END_OF_FRAME 0x04
#define RADEON_CS_RING_GFX 0
#define RADEON_CS_RING_COMPUTE 1
#define RADEON_CS_RING_DMA 2
#define RADEON_CS_RING_UVD 3
#define RADEON_CS_RING_VCE 4
struct drm_radeon_cs_chunk {
  __u32 chunk_id;
  __u32 length_dw;
  __u64 chunk_data;
};
#define RADEON_RELOC_PRIO_MASK (0xf << 0)
struct drm_radeon_cs_reloc {
  __u32 handle;
  __u32 read_domains;
  __u32 write_domain;
  __u32 flags;
};
struct drm_radeon_cs {
  __u32 num_chunks;
  __u32 cs_id;
  __u64 chunks;
  __u64 gart_limit;
  __u64 vram_limit;
};
#define RADEON_INFO_DEVICE_ID 0x00
#define RADEON_INFO_NUM_GB_PIPES 0x01
#define RADEON_INFO_NUM_Z_PIPES 0x02
#define RADEON_INFO_ACCEL_WORKING 0x03
#define RADEON_INFO_CRTC_FROM_ID 0x04
#define RADEON_INFO_ACCEL_WORKING2 0x05
#define RADEON_INFO_TILING_CONFIG 0x06
#define RADEON_INFO_WANT_HYPERZ 0x07
#define RADEON_INFO_WANT_CMASK 0x08
#define RADEON_INFO_CLOCK_CRYSTAL_FREQ 0x09
#define RADEON_INFO_NUM_BACKENDS 0x0a
#define RADEON_INFO_NUM_TILE_PIPES 0x0b
#define RADEON_INFO_FUSION_GART_WORKING 0x0c
#define RADEON_INFO_BACKEND_MAP 0x0d
#define RADEON_INFO_VA_START 0x0e
#define RADEON_INFO_IB_VM_MAX_SIZE 0x0f
#define RADEON_INFO_MAX_PIPES 0x10
#define RADEON_INFO_TIMESTAMP 0x11
#define RADEON_INFO_MAX_SE 0x12
#define RADEON_INFO_MAX_SH_PER_SE 0x13
#define RADEON_INFO_FASTFB_WORKING 0x14
#define RADEON_INFO_RING_WORKING 0x15
#define RADEON_INFO_SI_TILE_MODE_ARRAY 0x16
#define RADEON_INFO_SI_CP_DMA_COMPUTE 0x17
#define RADEON_INFO_CIK_MACROTILE_MODE_ARRAY 0x18
#define RADEON_INFO_SI_BACKEND_ENABLED_MASK 0x19
#define RADEON_INFO_MAX_SCLK 0x1a
#define RADEON_INFO_VCE_FW_VERSION 0x1b
#define RADEON_INFO_VCE_FB_VERSION 0x1c
#define RADEON_INFO_NUM_BYTES_MOVED 0x1d
#define RADEON_INFO_VRAM_USAGE 0x1e
#define RADEON_INFO_GTT_USAGE 0x1f
#define RADEON_INFO_ACTIVE_CU_COUNT 0x20
#define RADEON_INFO_CURRENT_GPU_TEMP 0x21
#define RADEON_INFO_CURRENT_GPU_SCLK 0x22
#define RADEON_INFO_CURRENT_GPU_MCLK 0x23
#define RADEON_INFO_READ_REG 0x24
#define RADEON_INFO_VA_UNMAP_WORKING 0x25
#define RADEON_INFO_GPU_RESET_COUNTER 0x26
struct drm_radeon_info {
  __u32 request;
  __u32 pad;
  __u64 value;
};
#define SI_TILE_MODE_COLOR_LINEAR_ALIGNED 8
#define SI_TILE_MODE_COLOR_1D 13
#define SI_TILE_MODE_COLOR_1D_SCANOUT 9
#define SI_TILE_MODE_COLOR_2D_8BPP 14
#define SI_TILE_MODE_COLOR_2D_16BPP 15
#define SI_TILE_MODE_COLOR_2D_32BPP 16
#define SI_TILE_MODE_COLOR_2D_64BPP 17
#define SI_TILE_MODE_COLOR_2D_SCANOUT_16BPP 11
#define SI_TILE_MODE_COLOR_2D_SCANOUT_32BPP 12
#define SI_TILE_MODE_DEPTH_STENCIL_1D 4
#define SI_TILE_MODE_DEPTH_STENCIL_2D 0
#define SI_TILE_MODE_DEPTH_STENCIL_2D_2AA 3
#define SI_TILE_MODE_DEPTH_STENCIL_2D_4AA 3
#define SI_TILE_MODE_DEPTH_STENCIL_2D_8AA 2
#define CIK_TILE_MODE_DEPTH_STENCIL_1D 5
#ifdef __cplusplus
}
#endif
#endif