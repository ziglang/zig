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
#ifndef _UAPI_LINUX_VIRTIO_RING_H
#define _UAPI_LINUX_VIRTIO_RING_H
#include <stdint.h>
#include <linux/types.h>
#include <linux/virtio_types.h>
#define VRING_DESC_F_NEXT 1
#define VRING_DESC_F_WRITE 2
#define VRING_DESC_F_INDIRECT 4
#define VRING_PACKED_DESC_F_AVAIL 7
#define VRING_PACKED_DESC_F_USED 15
#define VRING_USED_F_NO_NOTIFY 1
#define VRING_AVAIL_F_NO_INTERRUPT 1
#define VRING_PACKED_EVENT_FLAG_ENABLE 0x0
#define VRING_PACKED_EVENT_FLAG_DISABLE 0x1
#define VRING_PACKED_EVENT_FLAG_DESC 0x2
#define VRING_PACKED_EVENT_F_WRAP_CTR 15
#define VIRTIO_RING_F_INDIRECT_DESC 28
#define VIRTIO_RING_F_EVENT_IDX 29
#define VRING_AVAIL_ALIGN_SIZE 2
#define VRING_USED_ALIGN_SIZE 4
#define VRING_DESC_ALIGN_SIZE 16
struct vring_desc {
  __virtio64 addr;
  __virtio32 len;
  __virtio16 flags;
  __virtio16 next;
};
struct vring_avail {
  __virtio16 flags;
  __virtio16 idx;
  __virtio16 ring[];
};
struct vring_used_elem {
  __virtio32 id;
  __virtio32 len;
};
typedef struct vring_used_elem __attribute__((aligned(VRING_USED_ALIGN_SIZE))) vring_used_elem_t;
struct vring_used {
  __virtio16 flags;
  __virtio16 idx;
  vring_used_elem_t ring[];
};
typedef struct vring_desc __attribute__((aligned(VRING_DESC_ALIGN_SIZE))) vring_desc_t;
typedef struct vring_avail __attribute__((aligned(VRING_AVAIL_ALIGN_SIZE))) vring_avail_t;
typedef struct vring_used __attribute__((aligned(VRING_USED_ALIGN_SIZE))) vring_used_t;
struct vring {
  unsigned int num;
  vring_desc_t * desc;
  vring_avail_t * avail;
  vring_used_t * used;
};
#ifndef VIRTIO_RING_NO_LEGACY
#define vring_used_event(vr) ((vr)->avail->ring[(vr)->num])
#define vring_avail_event(vr) (* (__virtio16 *) & (vr)->used->ring[(vr)->num])
#endif
struct vring_packed_desc_event {
  __le16 off_wrap;
  __le16 flags;
};
struct vring_packed_desc {
  __le64 addr;
  __le32 len;
  __le16 id;
  __le16 flags;
};
#endif