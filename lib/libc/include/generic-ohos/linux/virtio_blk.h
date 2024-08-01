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
#ifndef _LINUX_VIRTIO_BLK_H
#define _LINUX_VIRTIO_BLK_H
#include <linux/types.h>
#include <linux/virtio_ids.h>
#include <linux/virtio_config.h>
#include <linux/virtio_types.h>
#define VIRTIO_BLK_F_SIZE_MAX 1
#define VIRTIO_BLK_F_SEG_MAX 2
#define VIRTIO_BLK_F_GEOMETRY 4
#define VIRTIO_BLK_F_RO 5
#define VIRTIO_BLK_F_BLK_SIZE 6
#define VIRTIO_BLK_F_TOPOLOGY 10
#define VIRTIO_BLK_F_MQ 12
#define VIRTIO_BLK_F_DISCARD 13
#define VIRTIO_BLK_F_WRITE_ZEROES 14
#ifndef VIRTIO_BLK_NO_LEGACY
#define VIRTIO_BLK_F_BARRIER 0
#define VIRTIO_BLK_F_SCSI 7
#define VIRTIO_BLK_F_FLUSH 9
#define VIRTIO_BLK_F_CONFIG_WCE 11
#define VIRTIO_BLK_F_WCE VIRTIO_BLK_F_FLUSH
#endif
#define VIRTIO_BLK_ID_BYTES 20
struct virtio_blk_config {
  __virtio64 capacity;
  __virtio32 size_max;
  __virtio32 seg_max;
  struct virtio_blk_geometry {
    __virtio16 cylinders;
    __u8 heads;
    __u8 sectors;
  } geometry;
  __virtio32 blk_size;
  __u8 physical_block_exp;
  __u8 alignment_offset;
  __virtio16 min_io_size;
  __virtio32 opt_io_size;
  __u8 wce;
  __u8 unused;
  __virtio16 num_queues;
  __virtio32 max_discard_sectors;
  __virtio32 max_discard_seg;
  __virtio32 discard_sector_alignment;
  __virtio32 max_write_zeroes_sectors;
  __virtio32 max_write_zeroes_seg;
  __u8 write_zeroes_may_unmap;
  __u8 unused1[3];
} __attribute__((packed));
#define VIRTIO_BLK_T_IN 0
#define VIRTIO_BLK_T_OUT 1
#ifndef VIRTIO_BLK_NO_LEGACY
#define VIRTIO_BLK_T_SCSI_CMD 2
#endif
#define VIRTIO_BLK_T_FLUSH 4
#define VIRTIO_BLK_T_GET_ID 8
#define VIRTIO_BLK_T_DISCARD 11
#define VIRTIO_BLK_T_WRITE_ZEROES 13
#ifndef VIRTIO_BLK_NO_LEGACY
#define VIRTIO_BLK_T_BARRIER 0x80000000
#endif
struct virtio_blk_outhdr {
  __virtio32 type;
  __virtio32 ioprio;
  __virtio64 sector;
};
#define VIRTIO_BLK_WRITE_ZEROES_FLAG_UNMAP 0x00000001
struct virtio_blk_discard_write_zeroes {
  __le64 sector;
  __le32 num_sectors;
  __le32 flags;
};
#ifndef VIRTIO_BLK_NO_LEGACY
struct virtio_scsi_inhdr {
  __virtio32 errors;
  __virtio32 data_len;
  __virtio32 sense_len;
  __virtio32 residual;
};
#endif
#define VIRTIO_BLK_S_OK 0
#define VIRTIO_BLK_S_IOERR 1
#define VIRTIO_BLK_S_UNSUPP 2
#endif