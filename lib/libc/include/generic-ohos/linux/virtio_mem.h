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
#ifndef _LINUX_VIRTIO_MEM_H
#define _LINUX_VIRTIO_MEM_H
#include <linux/types.h>
#include <linux/virtio_types.h>
#include <linux/virtio_ids.h>
#include <linux/virtio_config.h>
#define VIRTIO_MEM_F_ACPI_PXM 0
#define VIRTIO_MEM_REQ_PLUG 0
#define VIRTIO_MEM_REQ_UNPLUG 1
#define VIRTIO_MEM_REQ_UNPLUG_ALL 2
#define VIRTIO_MEM_REQ_STATE 3
struct virtio_mem_req_plug {
  __virtio64 addr;
  __virtio16 nb_blocks;
  __virtio16 padding[3];
};
struct virtio_mem_req_unplug {
  __virtio64 addr;
  __virtio16 nb_blocks;
  __virtio16 padding[3];
};
struct virtio_mem_req_state {
  __virtio64 addr;
  __virtio16 nb_blocks;
  __virtio16 padding[3];
};
struct virtio_mem_req {
  __virtio16 type;
  __virtio16 padding[3];
  union {
    struct virtio_mem_req_plug plug;
    struct virtio_mem_req_unplug unplug;
    struct virtio_mem_req_state state;
  } u;
};
#define VIRTIO_MEM_RESP_ACK 0
#define VIRTIO_MEM_RESP_NACK 1
#define VIRTIO_MEM_RESP_BUSY 2
#define VIRTIO_MEM_RESP_ERROR 3
#define VIRTIO_MEM_STATE_PLUGGED 0
#define VIRTIO_MEM_STATE_UNPLUGGED 1
#define VIRTIO_MEM_STATE_MIXED 2
struct virtio_mem_resp_state {
  __virtio16 state;
};
struct virtio_mem_resp {
  __virtio16 type;
  __virtio16 padding[3];
  union {
    struct virtio_mem_resp_state state;
  } u;
};
struct virtio_mem_config {
  __le64 block_size;
  __le16 node_id;
  __u8 padding[6];
  __le64 addr;
  __le64 region_size;
  __le64 usable_region_size;
  __le64 plugged_size;
  __le64 requested_size;
};
#endif