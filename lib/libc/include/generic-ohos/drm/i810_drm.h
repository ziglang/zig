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
#ifndef _I810_DRM_H_
#define _I810_DRM_H_
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#ifndef _I810_DEFINES_
#define _I810_DEFINES_
#define I810_DMA_BUF_ORDER 12
#define I810_DMA_BUF_SZ (1 << I810_DMA_BUF_ORDER)
#define I810_DMA_BUF_NR 256
#define I810_NR_SAREA_CLIPRECTS 8
#define I810_NR_TEX_REGIONS 64
#define I810_LOG_MIN_TEX_REGION_SIZE 16
#endif
#define I810_UPLOAD_TEX0IMAGE 0x1
#define I810_UPLOAD_TEX1IMAGE 0x2
#define I810_UPLOAD_CTX 0x4
#define I810_UPLOAD_BUFFERS 0x8
#define I810_UPLOAD_TEX0 0x10
#define I810_UPLOAD_TEX1 0x20
#define I810_UPLOAD_CLIPRECTS 0x40
#define I810_DESTREG_DI0 0
#define I810_DESTREG_DI1 1
#define I810_DESTREG_DV0 2
#define I810_DESTREG_DV1 3
#define I810_DESTREG_DR0 4
#define I810_DESTREG_DR1 5
#define I810_DESTREG_DR2 6
#define I810_DESTREG_DR3 7
#define I810_DESTREG_DR4 8
#define I810_DEST_SETUP_SIZE 10
#define I810_CTXREG_CF0 0
#define I810_CTXREG_CF1 1
#define I810_CTXREG_ST0 2
#define I810_CTXREG_ST1 3
#define I810_CTXREG_VF 4
#define I810_CTXREG_MT 5
#define I810_CTXREG_MC0 6
#define I810_CTXREG_MC1 7
#define I810_CTXREG_MC2 8
#define I810_CTXREG_MA0 9
#define I810_CTXREG_MA1 10
#define I810_CTXREG_MA2 11
#define I810_CTXREG_SDM 12
#define I810_CTXREG_FOG 13
#define I810_CTXREG_B1 14
#define I810_CTXREG_B2 15
#define I810_CTXREG_LCS 16
#define I810_CTXREG_PV 17
#define I810_CTXREG_ZA 18
#define I810_CTXREG_AA 19
#define I810_CTX_SETUP_SIZE 20
#define I810_TEXREG_MI0 0
#define I810_TEXREG_MI1 1
#define I810_TEXREG_MI2 2
#define I810_TEXREG_MI3 3
#define I810_TEXREG_MF 4
#define I810_TEXREG_MLC 5
#define I810_TEXREG_MLL 6
#define I810_TEXREG_MCS 7
#define I810_TEX_SETUP_SIZE 8
#define I810_FRONT 0x1
#define I810_BACK 0x2
#define I810_DEPTH 0x4
typedef enum _drm_i810_init_func {
  I810_INIT_DMA = 0x01,
  I810_CLEANUP_DMA = 0x02,
  I810_INIT_DMA_1_4 = 0x03
} drm_i810_init_func_t;
typedef struct _drm_i810_init {
  drm_i810_init_func_t func;
  unsigned int mmio_offset;
  unsigned int buffers_offset;
  int sarea_priv_offset;
  unsigned int ring_start;
  unsigned int ring_end;
  unsigned int ring_size;
  unsigned int front_offset;
  unsigned int back_offset;
  unsigned int depth_offset;
  unsigned int overlay_offset;
  unsigned int overlay_physical;
  unsigned int w;
  unsigned int h;
  unsigned int pitch;
  unsigned int pitch_bits;
} drm_i810_init_t;
typedef struct _drm_i810_pre12_init {
  drm_i810_init_func_t func;
  unsigned int mmio_offset;
  unsigned int buffers_offset;
  int sarea_priv_offset;
  unsigned int ring_start;
  unsigned int ring_end;
  unsigned int ring_size;
  unsigned int front_offset;
  unsigned int back_offset;
  unsigned int depth_offset;
  unsigned int w;
  unsigned int h;
  unsigned int pitch;
  unsigned int pitch_bits;
} drm_i810_pre12_init_t;
typedef struct _drm_i810_tex_region {
  unsigned char next, prev;
  unsigned char in_use;
  int age;
} drm_i810_tex_region_t;
typedef struct _drm_i810_sarea {
  unsigned int ContextState[I810_CTX_SETUP_SIZE];
  unsigned int BufferState[I810_DEST_SETUP_SIZE];
  unsigned int TexState[2][I810_TEX_SETUP_SIZE];
  unsigned int dirty;
  unsigned int nbox;
  struct drm_clip_rect boxes[I810_NR_SAREA_CLIPRECTS];
  drm_i810_tex_region_t texList[I810_NR_TEX_REGIONS + 1];
  int texAge;
  int last_enqueue;
  int last_dispatch;
  int last_quiescent;
  int ctxOwner;
  int vertex_prim;
  int pf_enabled;
  int pf_active;
  int pf_current_page;
} drm_i810_sarea_t;
#define DRM_I810_INIT 0x00
#define DRM_I810_VERTEX 0x01
#define DRM_I810_CLEAR 0x02
#define DRM_I810_FLUSH 0x03
#define DRM_I810_GETAGE 0x04
#define DRM_I810_GETBUF 0x05
#define DRM_I810_SWAP 0x06
#define DRM_I810_COPY 0x07
#define DRM_I810_DOCOPY 0x08
#define DRM_I810_OV0INFO 0x09
#define DRM_I810_FSTATUS 0x0a
#define DRM_I810_OV0FLIP 0x0b
#define DRM_I810_MC 0x0c
#define DRM_I810_RSTATUS 0x0d
#define DRM_I810_FLIP 0x0e
#define DRM_IOCTL_I810_INIT DRM_IOW(DRM_COMMAND_BASE + DRM_I810_INIT, drm_i810_init_t)
#define DRM_IOCTL_I810_VERTEX DRM_IOW(DRM_COMMAND_BASE + DRM_I810_VERTEX, drm_i810_vertex_t)
#define DRM_IOCTL_I810_CLEAR DRM_IOW(DRM_COMMAND_BASE + DRM_I810_CLEAR, drm_i810_clear_t)
#define DRM_IOCTL_I810_FLUSH DRM_IO(DRM_COMMAND_BASE + DRM_I810_FLUSH)
#define DRM_IOCTL_I810_GETAGE DRM_IO(DRM_COMMAND_BASE + DRM_I810_GETAGE)
#define DRM_IOCTL_I810_GETBUF DRM_IOWR(DRM_COMMAND_BASE + DRM_I810_GETBUF, drm_i810_dma_t)
#define DRM_IOCTL_I810_SWAP DRM_IO(DRM_COMMAND_BASE + DRM_I810_SWAP)
#define DRM_IOCTL_I810_COPY DRM_IOW(DRM_COMMAND_BASE + DRM_I810_COPY, drm_i810_copy_t)
#define DRM_IOCTL_I810_DOCOPY DRM_IO(DRM_COMMAND_BASE + DRM_I810_DOCOPY)
#define DRM_IOCTL_I810_OV0INFO DRM_IOR(DRM_COMMAND_BASE + DRM_I810_OV0INFO, drm_i810_overlay_t)
#define DRM_IOCTL_I810_FSTATUS DRM_IO(DRM_COMMAND_BASE + DRM_I810_FSTATUS)
#define DRM_IOCTL_I810_OV0FLIP DRM_IO(DRM_COMMAND_BASE + DRM_I810_OV0FLIP)
#define DRM_IOCTL_I810_MC DRM_IOW(DRM_COMMAND_BASE + DRM_I810_MC, drm_i810_mc_t)
#define DRM_IOCTL_I810_RSTATUS DRM_IO(DRM_COMMAND_BASE + DRM_I810_RSTATUS)
#define DRM_IOCTL_I810_FLIP DRM_IO(DRM_COMMAND_BASE + DRM_I810_FLIP)
typedef struct _drm_i810_clear {
  int clear_color;
  int clear_depth;
  int flags;
} drm_i810_clear_t;
typedef struct _drm_i810_vertex {
  int idx;
  int used;
  int discard;
} drm_i810_vertex_t;
typedef struct _drm_i810_copy_t {
  int idx;
  int used;
  void * address;
} drm_i810_copy_t;
#define PR_TRIANGLES (0x0 << 18)
#define PR_TRISTRIP_0 (0x1 << 18)
#define PR_TRISTRIP_1 (0x2 << 18)
#define PR_TRIFAN (0x3 << 18)
#define PR_POLYGON (0x4 << 18)
#define PR_LINES (0x5 << 18)
#define PR_LINESTRIP (0x6 << 18)
#define PR_RECTS (0x7 << 18)
#define PR_MASK (0x7 << 18)
typedef struct drm_i810_dma {
  void * __linux_virtual;
  int request_idx;
  int request_size;
  int granted;
} drm_i810_dma_t;
typedef struct _drm_i810_overlay_t {
  unsigned int offset;
  unsigned int physical;
} drm_i810_overlay_t;
typedef struct _drm_i810_mc {
  int idx;
  int used;
  int num_blocks;
  int * length;
  unsigned int last_render;
} drm_i810_mc_t;
#ifdef __cplusplus
}
#endif
#endif