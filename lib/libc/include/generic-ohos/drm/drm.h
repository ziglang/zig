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
#ifndef _DRM_H_
#define _DRM_H_
#ifdef __linux__
#include <linux/types.h>
#include <asm/ioctl.h>
typedef unsigned int drm_handle_t;
#else
#include <stdint.h>
#include <sys/ioccom.h>
#include <sys/types.h>
typedef int8_t __s8;
typedef uint8_t __u8;
typedef int16_t __s16;
typedef uint16_t __u16;
typedef int32_t __s32;
typedef uint32_t __u32;
typedef int64_t __s64;
typedef uint64_t __u64;
typedef size_t __kernel_size_t;
typedef unsigned long drm_handle_t;
#endif
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_NAME "drm"
#define DRM_MIN_ORDER 5
#define DRM_MAX_ORDER 22
#define DRM_RAM_PERCENT 10
#define _DRM_LOCK_HELD 0x80000000U
#define _DRM_LOCK_CONT 0x40000000U
#define _DRM_LOCK_IS_HELD(lock) ((lock) & _DRM_LOCK_HELD)
#define _DRM_LOCK_IS_CONT(lock) ((lock) & _DRM_LOCK_CONT)
#define _DRM_LOCKING_CONTEXT(lock) ((lock) & ~(_DRM_LOCK_HELD | _DRM_LOCK_CONT))
typedef unsigned int drm_context_t;
typedef unsigned int drm_drawable_t;
typedef unsigned int drm_magic_t;
struct drm_clip_rect {
  unsigned short x1;
  unsigned short y1;
  unsigned short x2;
  unsigned short y2;
};
struct drm_drawable_info {
  unsigned int num_rects;
  struct drm_clip_rect * rects;
};
struct drm_tex_region {
  unsigned char next;
  unsigned char prev;
  unsigned char in_use;
  unsigned char padding;
  unsigned int age;
};
struct drm_hw_lock {
  __volatile__ unsigned int lock;
  char padding[60];
};
struct drm_version {
  int version_major;
  int version_minor;
  int version_patchlevel;
  __kernel_size_t name_len;
  char __user * name;
  __kernel_size_t date_len;
  char __user * date;
  __kernel_size_t desc_len;
  char __user * desc;
};
struct drm_unique {
  __kernel_size_t unique_len;
  char __user * unique;
};
struct drm_list {
  int count;
  struct drm_version __user * version;
};
struct drm_block {
  int unused;
};
struct drm_control {
  enum {
    DRM_ADD_COMMAND,
    DRM_RM_COMMAND,
    DRM_INST_HANDLER,
    DRM_UNINST_HANDLER
  } func;
  int irq;
};
enum drm_map_type {
  _DRM_FRAME_BUFFER = 0,
  _DRM_REGISTERS = 1,
  _DRM_SHM = 2,
  _DRM_AGP = 3,
  _DRM_SCATTER_GATHER = 4,
  _DRM_CONSISTENT = 5
};
enum drm_map_flags {
  _DRM_RESTRICTED = 0x01,
  _DRM_READ_ONLY = 0x02,
  _DRM_LOCKED = 0x04,
  _DRM_KERNEL = 0x08,
  _DRM_WRITE_COMBINING = 0x10,
  _DRM_CONTAINS_LOCK = 0x20,
  _DRM_REMOVABLE = 0x40,
  _DRM_DRIVER = 0x80
};
struct drm_ctx_priv_map {
  unsigned int ctx_id;
  void * handle;
};
struct drm_map {
  unsigned long offset;
  unsigned long size;
  enum drm_map_type type;
  enum drm_map_flags flags;
  void * handle;
  int mtrr;
};
struct drm_client {
  int idx;
  int auth;
  unsigned long pid;
  unsigned long uid;
  unsigned long magic;
  unsigned long iocs;
};
enum drm_stat_type {
  _DRM_STAT_LOCK,
  _DRM_STAT_OPENS,
  _DRM_STAT_CLOSES,
  _DRM_STAT_IOCTLS,
  _DRM_STAT_LOCKS,
  _DRM_STAT_UNLOCKS,
  _DRM_STAT_VALUE,
  _DRM_STAT_BYTE,
  _DRM_STAT_COUNT,
  _DRM_STAT_IRQ,
  _DRM_STAT_PRIMARY,
  _DRM_STAT_SECONDARY,
  _DRM_STAT_DMA,
  _DRM_STAT_SPECIAL,
  _DRM_STAT_MISSED
};
struct drm_stats {
  unsigned long count;
  struct {
    unsigned long value;
    enum drm_stat_type type;
  } data[15];
};
enum drm_lock_flags {
  _DRM_LOCK_READY = 0x01,
  _DRM_LOCK_QUIESCENT = 0x02,
  _DRM_LOCK_FLUSH = 0x04,
  _DRM_LOCK_FLUSH_ALL = 0x08,
  _DRM_HALT_ALL_QUEUES = 0x10,
  _DRM_HALT_CUR_QUEUES = 0x20
};
struct drm_lock {
  int context;
  enum drm_lock_flags flags;
};
enum drm_dma_flags {
  _DRM_DMA_BLOCK = 0x01,
  _DRM_DMA_WHILE_LOCKED = 0x02,
  _DRM_DMA_PRIORITY = 0x04,
  _DRM_DMA_WAIT = 0x10,
  _DRM_DMA_SMALLER_OK = 0x20,
  _DRM_DMA_LARGER_OK = 0x40
};
struct drm_buf_desc {
  int count;
  int size;
  int low_mark;
  int high_mark;
  enum {
    _DRM_PAGE_ALIGN = 0x01,
    _DRM_AGP_BUFFER = 0x02,
    _DRM_SG_BUFFER = 0x04,
    _DRM_FB_BUFFER = 0x08,
    _DRM_PCI_BUFFER_RO = 0x10
  } flags;
  unsigned long agp_start;
};
struct drm_buf_info {
  int count;
  struct drm_buf_desc __user * list;
};
struct drm_buf_free {
  int count;
  int __user * list;
};
struct drm_buf_pub {
  int idx;
  int total;
  int used;
  void __user * address;
};
struct drm_buf_map {
  int count;
#ifdef __cplusplus
  void __user * virt;
#else
  void __user * __linux_virtual;
#endif
  struct drm_buf_pub __user * list;
};
struct drm_dma {
  int context;
  int send_count;
  int __user * send_indices;
  int __user * send_sizes;
  enum drm_dma_flags flags;
  int request_count;
  int request_size;
  int __user * request_indices;
  int __user * request_sizes;
  int granted_count;
};
enum drm_ctx_flags {
  _DRM_CONTEXT_PRESERVED = 0x01,
  _DRM_CONTEXT_2DONLY = 0x02
};
struct drm_ctx {
  drm_context_t handle;
  enum drm_ctx_flags flags;
};
struct drm_ctx_res {
  int count;
  struct drm_ctx __user * contexts;
};
struct drm_draw {
  drm_drawable_t handle;
};
typedef enum {
  DRM_DRAWABLE_CLIPRECTS
} drm_drawable_info_type_t;
struct drm_update_draw {
  drm_drawable_t handle;
  unsigned int type;
  unsigned int num;
  unsigned long long data;
};
struct drm_auth {
  drm_magic_t magic;
};
struct drm_irq_busid {
  int irq;
  int busnum;
  int devnum;
  int funcnum;
};
enum drm_vblank_seq_type {
  _DRM_VBLANK_ABSOLUTE = 0x0,
  _DRM_VBLANK_RELATIVE = 0x1,
  _DRM_VBLANK_HIGH_CRTC_MASK = 0x0000003e,
  _DRM_VBLANK_EVENT = 0x4000000,
  _DRM_VBLANK_FLIP = 0x8000000,
  _DRM_VBLANK_NEXTONMISS = 0x10000000,
  _DRM_VBLANK_SECONDARY = 0x20000000,
  _DRM_VBLANK_SIGNAL = 0x40000000
};
#define _DRM_VBLANK_HIGH_CRTC_SHIFT 1
#define _DRM_VBLANK_TYPES_MASK (_DRM_VBLANK_ABSOLUTE | _DRM_VBLANK_RELATIVE)
#define _DRM_VBLANK_FLAGS_MASK (_DRM_VBLANK_EVENT | _DRM_VBLANK_SIGNAL | _DRM_VBLANK_SECONDARY | _DRM_VBLANK_NEXTONMISS)
struct drm_wait_vblank_request {
  enum drm_vblank_seq_type type;
  unsigned int sequence;
  unsigned long signal;
};
struct drm_wait_vblank_reply {
  enum drm_vblank_seq_type type;
  unsigned int sequence;
  long tval_sec;
  long tval_usec;
};
union drm_wait_vblank {
  struct drm_wait_vblank_request request;
  struct drm_wait_vblank_reply reply;
};
#define _DRM_PRE_MODESET 1
#define _DRM_POST_MODESET 2
struct drm_modeset_ctl {
  __u32 crtc;
  __u32 cmd;
};
struct drm_agp_mode {
  unsigned long mode;
};
struct drm_agp_buffer {
  unsigned long size;
  unsigned long handle;
  unsigned long type;
  unsigned long physical;
};
struct drm_agp_binding {
  unsigned long handle;
  unsigned long offset;
};
struct drm_agp_info {
  int agp_version_major;
  int agp_version_minor;
  unsigned long mode;
  unsigned long aperture_base;
  unsigned long aperture_size;
  unsigned long memory_allowed;
  unsigned long memory_used;
  unsigned short id_vendor;
  unsigned short id_device;
};
struct drm_scatter_gather {
  unsigned long size;
  unsigned long handle;
};
struct drm_set_version {
  int drm_di_major;
  int drm_di_minor;
  int drm_dd_major;
  int drm_dd_minor;
};
struct drm_gem_close {
  __u32 handle;
  __u32 pad;
};
struct drm_gem_flink {
  __u32 handle;
  __u32 name;
};
struct drm_gem_open {
  __u32 name;
  __u32 handle;
  __u64 size;
};
#define DRM_CAP_DUMB_BUFFER 0x1
#define DRM_CAP_VBLANK_HIGH_CRTC 0x2
#define DRM_CAP_DUMB_PREFERRED_DEPTH 0x3
#define DRM_CAP_DUMB_PREFER_SHADOW 0x4
#define DRM_CAP_PRIME 0x5
#define DRM_PRIME_CAP_IMPORT 0x1
#define DRM_PRIME_CAP_EXPORT 0x2
#define DRM_CAP_TIMESTAMP_MONOTONIC 0x6
#define DRM_CAP_ASYNC_PAGE_FLIP 0x7
#define DRM_CAP_CURSOR_WIDTH 0x8
#define DRM_CAP_CURSOR_HEIGHT 0x9
#define DRM_CAP_ADDFB2_MODIFIERS 0x10
#define DRM_CAP_PAGE_FLIP_TARGET 0x11
#define DRM_CAP_CRTC_IN_VBLANK_EVENT 0x12
#define DRM_CAP_SYNCOBJ 0x13
#define DRM_CAP_SYNCOBJ_TIMELINE 0x14
struct drm_get_cap {
  __u64 capability;
  __u64 value;
};
#define DRM_CLIENT_CAP_STEREO_3D 1
#define DRM_CLIENT_CAP_UNIVERSAL_PLANES 2
#define DRM_CLIENT_CAP_ATOMIC 3
#define DRM_CLIENT_CAP_ASPECT_RATIO 4
#define DRM_CLIENT_CAP_WRITEBACK_CONNECTORS 5
struct drm_set_client_cap {
  __u64 capability;
  __u64 value;
};
#define DRM_RDWR O_RDWR
#define DRM_CLOEXEC O_CLOEXEC
struct drm_prime_handle {
  __u32 handle;
  __u32 flags;
  __s32 fd;
};
struct drm_syncobj_create {
  __u32 handle;
#define DRM_SYNCOBJ_CREATE_SIGNALED (1 << 0)
  __u32 flags;
};
struct drm_syncobj_destroy {
  __u32 handle;
  __u32 pad;
};
#define DRM_SYNCOBJ_FD_TO_HANDLE_FLAGS_IMPORT_SYNC_FILE (1 << 0)
#define DRM_SYNCOBJ_HANDLE_TO_FD_FLAGS_EXPORT_SYNC_FILE (1 << 0)
struct drm_syncobj_handle {
  __u32 handle;
  __u32 flags;
  __s32 fd;
  __u32 pad;
};
struct drm_syncobj_transfer {
  __u32 src_handle;
  __u32 dst_handle;
  __u64 src_point;
  __u64 dst_point;
  __u32 flags;
  __u32 pad;
};
#define DRM_SYNCOBJ_WAIT_FLAGS_WAIT_ALL (1 << 0)
#define DRM_SYNCOBJ_WAIT_FLAGS_WAIT_FOR_SUBMIT (1 << 1)
#define DRM_SYNCOBJ_WAIT_FLAGS_WAIT_AVAILABLE (1 << 2)
struct drm_syncobj_wait {
  __u64 handles;
  __s64 timeout_nsec;
  __u32 count_handles;
  __u32 flags;
  __u32 first_signaled;
  __u32 pad;
};
struct drm_syncobj_timeline_wait {
  __u64 handles;
  __u64 points;
  __s64 timeout_nsec;
  __u32 count_handles;
  __u32 flags;
  __u32 first_signaled;
  __u32 pad;
};
struct drm_syncobj_array {
  __u64 handles;
  __u32 count_handles;
  __u32 pad;
};
#define DRM_SYNCOBJ_QUERY_FLAGS_LAST_SUBMITTED (1 << 0)
struct drm_syncobj_timeline_array {
  __u64 handles;
  __u64 points;
  __u32 count_handles;
  __u32 flags;
};
struct drm_crtc_get_sequence {
  __u32 crtc_id;
  __u32 active;
  __u64 sequence;
  __s64 sequence_ns;
};
#define DRM_CRTC_SEQUENCE_RELATIVE 0x00000001
#define DRM_CRTC_SEQUENCE_NEXT_ON_MISS 0x00000002
struct drm_crtc_queue_sequence {
  __u32 crtc_id;
  __u32 flags;
  __u64 sequence;
  __u64 user_data;
};
#ifdef __cplusplus
}
#endif
#include "drm_mode.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_IOCTL_BASE 'd'
#define DRM_IO(nr) _IO(DRM_IOCTL_BASE, nr)
#define DRM_IOR(nr,type) _IOR(DRM_IOCTL_BASE, nr, type)
#define DRM_IOW(nr,type) _IOW(DRM_IOCTL_BASE, nr, type)
#define DRM_IOWR(nr,type) _IOWR(DRM_IOCTL_BASE, nr, type)
#define DRM_IOCTL_VERSION DRM_IOWR(0x00, struct drm_version)
#define DRM_IOCTL_GET_UNIQUE DRM_IOWR(0x01, struct drm_unique)
#define DRM_IOCTL_GET_MAGIC DRM_IOR(0x02, struct drm_auth)
#define DRM_IOCTL_IRQ_BUSID DRM_IOWR(0x03, struct drm_irq_busid)
#define DRM_IOCTL_GET_MAP DRM_IOWR(0x04, struct drm_map)
#define DRM_IOCTL_GET_CLIENT DRM_IOWR(0x05, struct drm_client)
#define DRM_IOCTL_GET_STATS DRM_IOR(0x06, struct drm_stats)
#define DRM_IOCTL_SET_VERSION DRM_IOWR(0x07, struct drm_set_version)
#define DRM_IOCTL_MODESET_CTL DRM_IOW(0x08, struct drm_modeset_ctl)
#define DRM_IOCTL_GEM_CLOSE DRM_IOW(0x09, struct drm_gem_close)
#define DRM_IOCTL_GEM_FLINK DRM_IOWR(0x0a, struct drm_gem_flink)
#define DRM_IOCTL_GEM_OPEN DRM_IOWR(0x0b, struct drm_gem_open)
#define DRM_IOCTL_GET_CAP DRM_IOWR(0x0c, struct drm_get_cap)
#define DRM_IOCTL_SET_CLIENT_CAP DRM_IOW(0x0d, struct drm_set_client_cap)
#define DRM_IOCTL_SET_UNIQUE DRM_IOW(0x10, struct drm_unique)
#define DRM_IOCTL_AUTH_MAGIC DRM_IOW(0x11, struct drm_auth)
#define DRM_IOCTL_BLOCK DRM_IOWR(0x12, struct drm_block)
#define DRM_IOCTL_UNBLOCK DRM_IOWR(0x13, struct drm_block)
#define DRM_IOCTL_CONTROL DRM_IOW(0x14, struct drm_control)
#define DRM_IOCTL_ADD_MAP DRM_IOWR(0x15, struct drm_map)
#define DRM_IOCTL_ADD_BUFS DRM_IOWR(0x16, struct drm_buf_desc)
#define DRM_IOCTL_MARK_BUFS DRM_IOW(0x17, struct drm_buf_desc)
#define DRM_IOCTL_INFO_BUFS DRM_IOWR(0x18, struct drm_buf_info)
#define DRM_IOCTL_MAP_BUFS DRM_IOWR(0x19, struct drm_buf_map)
#define DRM_IOCTL_FREE_BUFS DRM_IOW(0x1a, struct drm_buf_free)
#define DRM_IOCTL_RM_MAP DRM_IOW(0x1b, struct drm_map)
#define DRM_IOCTL_SET_SAREA_CTX DRM_IOW(0x1c, struct drm_ctx_priv_map)
#define DRM_IOCTL_GET_SAREA_CTX DRM_IOWR(0x1d, struct drm_ctx_priv_map)
#define DRM_IOCTL_SET_MASTER DRM_IO(0x1e)
#define DRM_IOCTL_DROP_MASTER DRM_IO(0x1f)
#define DRM_IOCTL_ADD_CTX DRM_IOWR(0x20, struct drm_ctx)
#define DRM_IOCTL_RM_CTX DRM_IOWR(0x21, struct drm_ctx)
#define DRM_IOCTL_MOD_CTX DRM_IOW(0x22, struct drm_ctx)
#define DRM_IOCTL_GET_CTX DRM_IOWR(0x23, struct drm_ctx)
#define DRM_IOCTL_SWITCH_CTX DRM_IOW(0x24, struct drm_ctx)
#define DRM_IOCTL_NEW_CTX DRM_IOW(0x25, struct drm_ctx)
#define DRM_IOCTL_RES_CTX DRM_IOWR(0x26, struct drm_ctx_res)
#define DRM_IOCTL_ADD_DRAW DRM_IOWR(0x27, struct drm_draw)
#define DRM_IOCTL_RM_DRAW DRM_IOWR(0x28, struct drm_draw)
#define DRM_IOCTL_DMA DRM_IOWR(0x29, struct drm_dma)
#define DRM_IOCTL_LOCK DRM_IOW(0x2a, struct drm_lock)
#define DRM_IOCTL_UNLOCK DRM_IOW(0x2b, struct drm_lock)
#define DRM_IOCTL_FINISH DRM_IOW(0x2c, struct drm_lock)
#define DRM_IOCTL_PRIME_HANDLE_TO_FD DRM_IOWR(0x2d, struct drm_prime_handle)
#define DRM_IOCTL_PRIME_FD_TO_HANDLE DRM_IOWR(0x2e, struct drm_prime_handle)
#define DRM_IOCTL_AGP_ACQUIRE DRM_IO(0x30)
#define DRM_IOCTL_AGP_RELEASE DRM_IO(0x31)
#define DRM_IOCTL_AGP_ENABLE DRM_IOW(0x32, struct drm_agp_mode)
#define DRM_IOCTL_AGP_INFO DRM_IOR(0x33, struct drm_agp_info)
#define DRM_IOCTL_AGP_ALLOC DRM_IOWR(0x34, struct drm_agp_buffer)
#define DRM_IOCTL_AGP_FREE DRM_IOW(0x35, struct drm_agp_buffer)
#define DRM_IOCTL_AGP_BIND DRM_IOW(0x36, struct drm_agp_binding)
#define DRM_IOCTL_AGP_UNBIND DRM_IOW(0x37, struct drm_agp_binding)
#define DRM_IOCTL_SG_ALLOC DRM_IOWR(0x38, struct drm_scatter_gather)
#define DRM_IOCTL_SG_FREE DRM_IOW(0x39, struct drm_scatter_gather)
#define DRM_IOCTL_WAIT_VBLANK DRM_IOWR(0x3a, union drm_wait_vblank)
#define DRM_IOCTL_CRTC_GET_SEQUENCE DRM_IOWR(0x3b, struct drm_crtc_get_sequence)
#define DRM_IOCTL_CRTC_QUEUE_SEQUENCE DRM_IOWR(0x3c, struct drm_crtc_queue_sequence)
#define DRM_IOCTL_UPDATE_DRAW DRM_IOW(0x3f, struct drm_update_draw)
#define DRM_IOCTL_MODE_GETRESOURCES DRM_IOWR(0xA0, struct drm_mode_card_res)
#define DRM_IOCTL_MODE_GETCRTC DRM_IOWR(0xA1, struct drm_mode_crtc)
#define DRM_IOCTL_MODE_SETCRTC DRM_IOWR(0xA2, struct drm_mode_crtc)
#define DRM_IOCTL_MODE_CURSOR DRM_IOWR(0xA3, struct drm_mode_cursor)
#define DRM_IOCTL_MODE_GETGAMMA DRM_IOWR(0xA4, struct drm_mode_crtc_lut)
#define DRM_IOCTL_MODE_SETGAMMA DRM_IOWR(0xA5, struct drm_mode_crtc_lut)
#define DRM_IOCTL_MODE_GETENCODER DRM_IOWR(0xA6, struct drm_mode_get_encoder)
#define DRM_IOCTL_MODE_GETCONNECTOR DRM_IOWR(0xA7, struct drm_mode_get_connector)
#define DRM_IOCTL_MODE_ATTACHMODE DRM_IOWR(0xA8, struct drm_mode_mode_cmd)
#define DRM_IOCTL_MODE_DETACHMODE DRM_IOWR(0xA9, struct drm_mode_mode_cmd)
#define DRM_IOCTL_MODE_GETPROPERTY DRM_IOWR(0xAA, struct drm_mode_get_property)
#define DRM_IOCTL_MODE_SETPROPERTY DRM_IOWR(0xAB, struct drm_mode_connector_set_property)
#define DRM_IOCTL_MODE_GETPROPBLOB DRM_IOWR(0xAC, struct drm_mode_get_blob)
#define DRM_IOCTL_MODE_GETFB DRM_IOWR(0xAD, struct drm_mode_fb_cmd)
#define DRM_IOCTL_MODE_ADDFB DRM_IOWR(0xAE, struct drm_mode_fb_cmd)
#define DRM_IOCTL_MODE_RMFB DRM_IOWR(0xAF, unsigned int)
#define DRM_IOCTL_MODE_PAGE_FLIP DRM_IOWR(0xB0, struct drm_mode_crtc_page_flip)
#define DRM_IOCTL_MODE_DIRTYFB DRM_IOWR(0xB1, struct drm_mode_fb_dirty_cmd)
#define DRM_IOCTL_MODE_CREATE_DUMB DRM_IOWR(0xB2, struct drm_mode_create_dumb)
#define DRM_IOCTL_MODE_MAP_DUMB DRM_IOWR(0xB3, struct drm_mode_map_dumb)
#define DRM_IOCTL_MODE_DESTROY_DUMB DRM_IOWR(0xB4, struct drm_mode_destroy_dumb)
#define DRM_IOCTL_MODE_GETPLANERESOURCES DRM_IOWR(0xB5, struct drm_mode_get_plane_res)
#define DRM_IOCTL_MODE_GETPLANE DRM_IOWR(0xB6, struct drm_mode_get_plane)
#define DRM_IOCTL_MODE_SETPLANE DRM_IOWR(0xB7, struct drm_mode_set_plane)
#define DRM_IOCTL_MODE_ADDFB2 DRM_IOWR(0xB8, struct drm_mode_fb_cmd2)
#define DRM_IOCTL_MODE_OBJ_GETPROPERTIES DRM_IOWR(0xB9, struct drm_mode_obj_get_properties)
#define DRM_IOCTL_MODE_OBJ_SETPROPERTY DRM_IOWR(0xBA, struct drm_mode_obj_set_property)
#define DRM_IOCTL_MODE_CURSOR2 DRM_IOWR(0xBB, struct drm_mode_cursor2)
#define DRM_IOCTL_MODE_ATOMIC DRM_IOWR(0xBC, struct drm_mode_atomic)
#define DRM_IOCTL_MODE_CREATEPROPBLOB DRM_IOWR(0xBD, struct drm_mode_create_blob)
#define DRM_IOCTL_MODE_DESTROYPROPBLOB DRM_IOWR(0xBE, struct drm_mode_destroy_blob)
#define DRM_IOCTL_SYNCOBJ_CREATE DRM_IOWR(0xBF, struct drm_syncobj_create)
#define DRM_IOCTL_SYNCOBJ_DESTROY DRM_IOWR(0xC0, struct drm_syncobj_destroy)
#define DRM_IOCTL_SYNCOBJ_HANDLE_TO_FD DRM_IOWR(0xC1, struct drm_syncobj_handle)
#define DRM_IOCTL_SYNCOBJ_FD_TO_HANDLE DRM_IOWR(0xC2, struct drm_syncobj_handle)
#define DRM_IOCTL_SYNCOBJ_WAIT DRM_IOWR(0xC3, struct drm_syncobj_wait)
#define DRM_IOCTL_SYNCOBJ_RESET DRM_IOWR(0xC4, struct drm_syncobj_array)
#define DRM_IOCTL_SYNCOBJ_SIGNAL DRM_IOWR(0xC5, struct drm_syncobj_array)
#define DRM_IOCTL_MODE_CREATE_LEASE DRM_IOWR(0xC6, struct drm_mode_create_lease)
#define DRM_IOCTL_MODE_LIST_LESSEES DRM_IOWR(0xC7, struct drm_mode_list_lessees)
#define DRM_IOCTL_MODE_GET_LEASE DRM_IOWR(0xC8, struct drm_mode_get_lease)
#define DRM_IOCTL_MODE_REVOKE_LEASE DRM_IOWR(0xC9, struct drm_mode_revoke_lease)
#define DRM_IOCTL_SYNCOBJ_TIMELINE_WAIT DRM_IOWR(0xCA, struct drm_syncobj_timeline_wait)
#define DRM_IOCTL_SYNCOBJ_QUERY DRM_IOWR(0xCB, struct drm_syncobj_timeline_array)
#define DRM_IOCTL_SYNCOBJ_TRANSFER DRM_IOWR(0xCC, struct drm_syncobj_transfer)
#define DRM_IOCTL_SYNCOBJ_TIMELINE_SIGNAL DRM_IOWR(0xCD, struct drm_syncobj_timeline_array)
#define DRM_IOCTL_MODE_GETFB2 DRM_IOWR(0xCE, struct drm_mode_fb_cmd2)
#define DRM_COMMAND_BASE 0x40
#define DRM_COMMAND_END 0xA0
struct drm_event {
  __u32 type;
  __u32 length;
};
#define DRM_EVENT_VBLANK 0x01
#define DRM_EVENT_FLIP_COMPLETE 0x02
#define DRM_EVENT_CRTC_SEQUENCE 0x03
struct drm_event_vblank {
  struct drm_event base;
  __u64 user_data;
  __u32 tv_sec;
  __u32 tv_usec;
  __u32 sequence;
  __u32 crtc_id;
};
struct drm_event_crtc_sequence {
  struct drm_event base;
  __u64 user_data;
  __s64 time_ns;
  __u64 sequence;
};
typedef struct drm_clip_rect drm_clip_rect_t;
typedef struct drm_drawable_info drm_drawable_info_t;
typedef struct drm_tex_region drm_tex_region_t;
typedef struct drm_hw_lock drm_hw_lock_t;
typedef struct drm_version drm_version_t;
typedef struct drm_unique drm_unique_t;
typedef struct drm_list drm_list_t;
typedef struct drm_block drm_block_t;
typedef struct drm_control drm_control_t;
typedef enum drm_map_type drm_map_type_t;
typedef enum drm_map_flags drm_map_flags_t;
typedef struct drm_ctx_priv_map drm_ctx_priv_map_t;
typedef struct drm_map drm_map_t;
typedef struct drm_client drm_client_t;
typedef enum drm_stat_type drm_stat_type_t;
typedef struct drm_stats drm_stats_t;
typedef enum drm_lock_flags drm_lock_flags_t;
typedef struct drm_lock drm_lock_t;
typedef enum drm_dma_flags drm_dma_flags_t;
typedef struct drm_buf_desc drm_buf_desc_t;
typedef struct drm_buf_info drm_buf_info_t;
typedef struct drm_buf_free drm_buf_free_t;
typedef struct drm_buf_pub drm_buf_pub_t;
typedef struct drm_buf_map drm_buf_map_t;
typedef struct drm_dma drm_dma_t;
typedef union drm_wait_vblank drm_wait_vblank_t;
typedef struct drm_agp_mode drm_agp_mode_t;
typedef enum drm_ctx_flags drm_ctx_flags_t;
typedef struct drm_ctx drm_ctx_t;
typedef struct drm_ctx_res drm_ctx_res_t;
typedef struct drm_draw drm_draw_t;
typedef struct drm_update_draw drm_update_draw_t;
typedef struct drm_auth drm_auth_t;
typedef struct drm_irq_busid drm_irq_busid_t;
typedef enum drm_vblank_seq_type drm_vblank_seq_type_t;
typedef struct drm_agp_buffer drm_agp_buffer_t;
typedef struct drm_agp_binding drm_agp_binding_t;
typedef struct drm_agp_info drm_agp_info_t;
typedef struct drm_scatter_gather drm_scatter_gather_t;
typedef struct drm_set_version drm_set_version_t;
#ifdef __cplusplus
}
#endif
#endif