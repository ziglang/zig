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
#ifndef _VIA_DRM_H_
#define _VIA_DRM_H_
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#ifndef _VIA_DEFINES_
#define _VIA_DEFINES_
#define VIA_NR_SAREA_CLIPRECTS 8
#define VIA_NR_XVMC_PORTS 10
#define VIA_NR_XVMC_LOCKS 5
#define VIA_MAX_CACHELINE_SIZE 64
#define XVMCLOCKPTR(saPriv,lockNo) ((volatile struct drm_hw_lock *) (((((unsigned long) (saPriv)->XvMCLockArea) + (VIA_MAX_CACHELINE_SIZE - 1)) & ~(VIA_MAX_CACHELINE_SIZE - 1)) + VIA_MAX_CACHELINE_SIZE * (lockNo)))
#define VIA_NR_TEX_REGIONS 64
#define VIA_LOG_MIN_TEX_REGION_SIZE 16
#endif
#define VIA_UPLOAD_TEX0IMAGE 0x1
#define VIA_UPLOAD_TEX1IMAGE 0x2
#define VIA_UPLOAD_CTX 0x4
#define VIA_UPLOAD_BUFFERS 0x8
#define VIA_UPLOAD_TEX0 0x10
#define VIA_UPLOAD_TEX1 0x20
#define VIA_UPLOAD_CLIPRECTS 0x40
#define VIA_UPLOAD_ALL 0xff
#define DRM_VIA_ALLOCMEM 0x00
#define DRM_VIA_FREEMEM 0x01
#define DRM_VIA_AGP_INIT 0x02
#define DRM_VIA_FB_INIT 0x03
#define DRM_VIA_MAP_INIT 0x04
#define DRM_VIA_DEC_FUTEX 0x05
#define NOT_USED
#define DRM_VIA_DMA_INIT 0x07
#define DRM_VIA_CMDBUFFER 0x08
#define DRM_VIA_FLUSH 0x09
#define DRM_VIA_PCICMD 0x0a
#define DRM_VIA_CMDBUF_SIZE 0x0b
#define NOT_USED
#define DRM_VIA_WAIT_IRQ 0x0d
#define DRM_VIA_DMA_BLIT 0x0e
#define DRM_VIA_BLIT_SYNC 0x0f
#define DRM_IOCTL_VIA_ALLOCMEM DRM_IOWR(DRM_COMMAND_BASE + DRM_VIA_ALLOCMEM, drm_via_mem_t)
#define DRM_IOCTL_VIA_FREEMEM DRM_IOW(DRM_COMMAND_BASE + DRM_VIA_FREEMEM, drm_via_mem_t)
#define DRM_IOCTL_VIA_AGP_INIT DRM_IOWR(DRM_COMMAND_BASE + DRM_VIA_AGP_INIT, drm_via_agp_t)
#define DRM_IOCTL_VIA_FB_INIT DRM_IOWR(DRM_COMMAND_BASE + DRM_VIA_FB_INIT, drm_via_fb_t)
#define DRM_IOCTL_VIA_MAP_INIT DRM_IOWR(DRM_COMMAND_BASE + DRM_VIA_MAP_INIT, drm_via_init_t)
#define DRM_IOCTL_VIA_DEC_FUTEX DRM_IOW(DRM_COMMAND_BASE + DRM_VIA_DEC_FUTEX, drm_via_futex_t)
#define DRM_IOCTL_VIA_DMA_INIT DRM_IOWR(DRM_COMMAND_BASE + DRM_VIA_DMA_INIT, drm_via_dma_init_t)
#define DRM_IOCTL_VIA_CMDBUFFER DRM_IOW(DRM_COMMAND_BASE + DRM_VIA_CMDBUFFER, drm_via_cmdbuffer_t)
#define DRM_IOCTL_VIA_FLUSH DRM_IO(DRM_COMMAND_BASE + DRM_VIA_FLUSH)
#define DRM_IOCTL_VIA_PCICMD DRM_IOW(DRM_COMMAND_BASE + DRM_VIA_PCICMD, drm_via_cmdbuffer_t)
#define DRM_IOCTL_VIA_CMDBUF_SIZE DRM_IOWR(DRM_COMMAND_BASE + DRM_VIA_CMDBUF_SIZE, drm_via_cmdbuf_size_t)
#define DRM_IOCTL_VIA_WAIT_IRQ DRM_IOWR(DRM_COMMAND_BASE + DRM_VIA_WAIT_IRQ, drm_via_irqwait_t)
#define DRM_IOCTL_VIA_DMA_BLIT DRM_IOW(DRM_COMMAND_BASE + DRM_VIA_DMA_BLIT, drm_via_dmablit_t)
#define DRM_IOCTL_VIA_BLIT_SYNC DRM_IOW(DRM_COMMAND_BASE + DRM_VIA_BLIT_SYNC, drm_via_blitsync_t)
#define VIA_TEX_SETUP_SIZE 8
#define VIA_FRONT 0x1
#define VIA_BACK 0x2
#define VIA_DEPTH 0x4
#define VIA_STENCIL 0x8
#define VIA_MEM_VIDEO 0
#define VIA_MEM_AGP 1
#define VIA_MEM_SYSTEM 2
#define VIA_MEM_MIXED 3
#define VIA_MEM_UNKNOWN 4
typedef struct {
  __u32 offset;
  __u32 size;
} drm_via_agp_t;
typedef struct {
  __u32 offset;
  __u32 size;
} drm_via_fb_t;
typedef struct {
  __u32 context;
  __u32 type;
  __u32 size;
  unsigned long index;
  unsigned long offset;
} drm_via_mem_t;
typedef struct _drm_via_init {
  enum {
    VIA_INIT_MAP = 0x01,
    VIA_CLEANUP_MAP = 0x02
  } func;
  unsigned long sarea_priv_offset;
  unsigned long fb_offset;
  unsigned long mmio_offset;
  unsigned long agpAddr;
} drm_via_init_t;
typedef struct _drm_via_futex {
  enum {
    VIA_FUTEX_WAIT = 0x00,
    VIA_FUTEX_WAKE = 0X01
  } func;
  __u32 ms;
  __u32 lock;
  __u32 val;
} drm_via_futex_t;
typedef struct _drm_via_dma_init {
  enum {
    VIA_INIT_DMA = 0x01,
    VIA_CLEANUP_DMA = 0x02,
    VIA_DMA_INITIALIZED = 0x03
  } func;
  unsigned long offset;
  unsigned long size;
  unsigned long reg_pause_addr;
} drm_via_dma_init_t;
typedef struct _drm_via_cmdbuffer {
  char __user * buf;
  unsigned long size;
} drm_via_cmdbuffer_t;
typedef struct _drm_via_tex_region {
  unsigned char next, prev;
  unsigned char inUse;
  int age;
} drm_via_tex_region_t;
typedef struct _drm_via_sarea {
  unsigned int dirty;
  unsigned int nbox;
  struct drm_clip_rect boxes[VIA_NR_SAREA_CLIPRECTS];
  drm_via_tex_region_t texList[VIA_NR_TEX_REGIONS + 1];
  int texAge;
  int ctxOwner;
  int vertexPrim;
  char XvMCLockArea[VIA_MAX_CACHELINE_SIZE * (VIA_NR_XVMC_LOCKS + 1)];
  unsigned int XvMCDisplaying[VIA_NR_XVMC_PORTS];
  unsigned int XvMCSubPicOn[VIA_NR_XVMC_PORTS];
  unsigned int XvMCCtxNoGrabbed;
  unsigned int pfCurrentOffset;
} drm_via_sarea_t;
typedef struct _drm_via_cmdbuf_size {
  enum {
    VIA_CMDBUF_SPACE = 0x01,
    VIA_CMDBUF_LAG = 0x02
  } func;
  int wait;
  __u32 size;
} drm_via_cmdbuf_size_t;
typedef enum {
  VIA_IRQ_ABSOLUTE = 0x0,
  VIA_IRQ_RELATIVE = 0x1,
  VIA_IRQ_SIGNAL = 0x10000000,
  VIA_IRQ_FORCE_SEQUENCE = 0x20000000
} via_irq_seq_type_t;
#define VIA_IRQ_FLAGS_MASK 0xF0000000
enum drm_via_irqs {
  drm_via_irq_hqv0 = 0,
  drm_via_irq_hqv1,
  drm_via_irq_dma0_dd,
  drm_via_irq_dma0_td,
  drm_via_irq_dma1_dd,
  drm_via_irq_dma1_td,
  drm_via_irq_num
};
struct drm_via_wait_irq_request {
  unsigned irq;
  via_irq_seq_type_t type;
  __u32 sequence;
  __u32 signal;
};
typedef union drm_via_irqwait {
  struct drm_via_wait_irq_request request;
  struct drm_wait_vblank_reply reply;
} drm_via_irqwait_t;
typedef struct drm_via_blitsync {
  __u32 sync_handle;
  unsigned engine;
} drm_via_blitsync_t;
typedef struct drm_via_dmablit {
  __u32 num_lines;
  __u32 line_length;
  __u32 fb_addr;
  __u32 fb_stride;
  unsigned char * mem_addr;
  __u32 mem_stride;
  __u32 flags;
  int to_fb;
  drm_via_blitsync_t sync;
} drm_via_dmablit_t;
#ifdef __cplusplus
}
#endif
#endif