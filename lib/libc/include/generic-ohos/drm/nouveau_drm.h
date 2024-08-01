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
#ifndef __NOUVEAU_DRM_H__
#define __NOUVEAU_DRM_H__
#define DRM_NOUVEAU_EVENT_NVIF 0x80000000
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define NOUVEAU_GEM_DOMAIN_CPU (1 << 0)
#define NOUVEAU_GEM_DOMAIN_VRAM (1 << 1)
#define NOUVEAU_GEM_DOMAIN_GART (1 << 2)
#define NOUVEAU_GEM_DOMAIN_MAPPABLE (1 << 3)
#define NOUVEAU_GEM_DOMAIN_COHERENT (1 << 4)
#define NOUVEAU_GEM_TILE_COMP 0x00030000
#define NOUVEAU_GEM_TILE_LAYOUT_MASK 0x0000ff00
#define NOUVEAU_GEM_TILE_16BPP 0x00000001
#define NOUVEAU_GEM_TILE_32BPP 0x00000002
#define NOUVEAU_GEM_TILE_ZETA 0x00000004
#define NOUVEAU_GEM_TILE_NONCONTIG 0x00000008
struct drm_nouveau_gem_info {
  __u32 handle;
  __u32 domain;
  __u64 size;
  __u64 offset;
  __u64 map_handle;
  __u32 tile_mode;
  __u32 tile_flags;
};
struct drm_nouveau_gem_new {
  struct drm_nouveau_gem_info info;
  __u32 channel_hint;
  __u32 align;
};
#define NOUVEAU_GEM_MAX_BUFFERS 1024
struct drm_nouveau_gem_pushbuf_bo_presumed {
  __u32 valid;
  __u32 domain;
  __u64 offset;
};
struct drm_nouveau_gem_pushbuf_bo {
  __u64 user_priv;
  __u32 handle;
  __u32 read_domains;
  __u32 write_domains;
  __u32 valid_domains;
  struct drm_nouveau_gem_pushbuf_bo_presumed presumed;
};
#define NOUVEAU_GEM_RELOC_LOW (1 << 0)
#define NOUVEAU_GEM_RELOC_HIGH (1 << 1)
#define NOUVEAU_GEM_RELOC_OR (1 << 2)
#define NOUVEAU_GEM_MAX_RELOCS 1024
struct drm_nouveau_gem_pushbuf_reloc {
  __u32 reloc_bo_index;
  __u32 reloc_bo_offset;
  __u32 bo_index;
  __u32 flags;
  __u32 data;
  __u32 vor;
  __u32 tor;
};
#define NOUVEAU_GEM_MAX_PUSH 512
struct drm_nouveau_gem_pushbuf_push {
  __u32 bo_index;
  __u32 pad;
  __u64 offset;
  __u64 length;
};
struct drm_nouveau_gem_pushbuf {
  __u32 channel;
  __u32 nr_buffers;
  __u64 buffers;
  __u32 nr_relocs;
  __u32 nr_push;
  __u64 relocs;
  __u64 push;
  __u32 suffix0;
  __u32 suffix1;
#define NOUVEAU_GEM_PUSHBUF_SYNC (1ULL << 0)
  __u64 vram_available;
  __u64 gart_available;
};
#define NOUVEAU_GEM_CPU_PREP_NOWAIT 0x00000001
#define NOUVEAU_GEM_CPU_PREP_WRITE 0x00000004
struct drm_nouveau_gem_cpu_prep {
  __u32 handle;
  __u32 flags;
};
struct drm_nouveau_gem_cpu_fini {
  __u32 handle;
};
#define DRM_NOUVEAU_GETPARAM 0x00
#define DRM_NOUVEAU_SETPARAM 0x01
#define DRM_NOUVEAU_CHANNEL_ALLOC 0x02
#define DRM_NOUVEAU_CHANNEL_FREE 0x03
#define DRM_NOUVEAU_GROBJ_ALLOC 0x04
#define DRM_NOUVEAU_NOTIFIEROBJ_ALLOC 0x05
#define DRM_NOUVEAU_GPUOBJ_FREE 0x06
#define DRM_NOUVEAU_NVIF 0x07
#define DRM_NOUVEAU_SVM_INIT 0x08
#define DRM_NOUVEAU_SVM_BIND 0x09
#define DRM_NOUVEAU_GEM_NEW 0x40
#define DRM_NOUVEAU_GEM_PUSHBUF 0x41
#define DRM_NOUVEAU_GEM_CPU_PREP 0x42
#define DRM_NOUVEAU_GEM_CPU_FINI 0x43
#define DRM_NOUVEAU_GEM_INFO 0x44
struct drm_nouveau_svm_init {
  __u64 unmanaged_addr;
  __u64 unmanaged_size;
};
struct drm_nouveau_svm_bind {
  __u64 header;
  __u64 va_start;
  __u64 va_end;
  __u64 npages;
  __u64 stride;
  __u64 result;
  __u64 reserved0;
  __u64 reserved1;
};
#define NOUVEAU_SVM_BIND_COMMAND_SHIFT 0
#define NOUVEAU_SVM_BIND_COMMAND_BITS 8
#define NOUVEAU_SVM_BIND_COMMAND_MASK ((1 << 8) - 1)
#define NOUVEAU_SVM_BIND_PRIORITY_SHIFT 8
#define NOUVEAU_SVM_BIND_PRIORITY_BITS 8
#define NOUVEAU_SVM_BIND_PRIORITY_MASK ((1 << 8) - 1)
#define NOUVEAU_SVM_BIND_TARGET_SHIFT 16
#define NOUVEAU_SVM_BIND_TARGET_BITS 32
#define NOUVEAU_SVM_BIND_TARGET_MASK 0xffffffff
#define NOUVEAU_SVM_BIND_VALID_BITS 48
#define NOUVEAU_SVM_BIND_VALID_MASK ((1ULL << NOUVEAU_SVM_BIND_VALID_BITS) - 1)
#define NOUVEAU_SVM_BIND_COMMAND__MIGRATE 0
#define NOUVEAU_SVM_BIND_TARGET__GPU_VRAM (1UL << 31)
#define DRM_IOCTL_NOUVEAU_SVM_INIT DRM_IOWR(DRM_COMMAND_BASE + DRM_NOUVEAU_SVM_INIT, struct drm_nouveau_svm_init)
#define DRM_IOCTL_NOUVEAU_SVM_BIND DRM_IOWR(DRM_COMMAND_BASE + DRM_NOUVEAU_SVM_BIND, struct drm_nouveau_svm_bind)
#define DRM_IOCTL_NOUVEAU_GEM_NEW DRM_IOWR(DRM_COMMAND_BASE + DRM_NOUVEAU_GEM_NEW, struct drm_nouveau_gem_new)
#define DRM_IOCTL_NOUVEAU_GEM_PUSHBUF DRM_IOWR(DRM_COMMAND_BASE + DRM_NOUVEAU_GEM_PUSHBUF, struct drm_nouveau_gem_pushbuf)
#define DRM_IOCTL_NOUVEAU_GEM_CPU_PREP DRM_IOW(DRM_COMMAND_BASE + DRM_NOUVEAU_GEM_CPU_PREP, struct drm_nouveau_gem_cpu_prep)
#define DRM_IOCTL_NOUVEAU_GEM_CPU_FINI DRM_IOW(DRM_COMMAND_BASE + DRM_NOUVEAU_GEM_CPU_FINI, struct drm_nouveau_gem_cpu_fini)
#define DRM_IOCTL_NOUVEAU_GEM_INFO DRM_IOWR(DRM_COMMAND_BASE + DRM_NOUVEAU_GEM_INFO, struct drm_nouveau_gem_info)
#ifdef __cplusplus
}
#endif
#endif