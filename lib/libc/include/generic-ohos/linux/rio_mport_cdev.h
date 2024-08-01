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
#ifndef _RIO_MPORT_CDEV_H_
#define _RIO_MPORT_CDEV_H_
#include <linux/ioctl.h>
#include <linux/types.h>
struct rio_mport_maint_io {
  __u16 rioid;
  __u8 hopcount;
  __u8 pad0[5];
  __u32 offset;
  __u32 length;
  __u64 buffer;
};
#define RIO_TRANSFER_MODE_MAPPED (1 << 0)
#define RIO_TRANSFER_MODE_TRANSFER (1 << 1)
#define RIO_CAP_DBL_SEND (1 << 2)
#define RIO_CAP_DBL_RECV (1 << 3)
#define RIO_CAP_PW_SEND (1 << 4)
#define RIO_CAP_PW_RECV (1 << 5)
#define RIO_CAP_MAP_OUTB (1 << 6)
#define RIO_CAP_MAP_INB (1 << 7)
struct rio_mport_properties {
  __u16 hdid;
  __u8 id;
  __u8 index;
  __u32 flags;
  __u32 sys_size;
  __u8 port_ok;
  __u8 link_speed;
  __u8 link_width;
  __u8 pad0;
  __u32 dma_max_sge;
  __u32 dma_max_size;
  __u32 dma_align;
  __u32 transfer_mode;
  __u32 cap_sys_size;
  __u32 cap_addr_size;
  __u32 cap_transfer_mode;
  __u32 cap_mport;
};
#define RIO_DOORBELL (1 << 0)
#define RIO_PORTWRITE (1 << 1)
struct rio_doorbell {
  __u16 rioid;
  __u16 payload;
};
struct rio_doorbell_filter {
  __u16 rioid;
  __u16 low;
  __u16 high;
  __u16 pad0;
};
struct rio_portwrite {
  __u32 payload[16];
};
struct rio_pw_filter {
  __u32 mask;
  __u32 low;
  __u32 high;
  __u32 pad0;
};
#define RIO_MAP_ANY_ADDR (__u64) (~((__u64) 0))
struct rio_mmap {
  __u16 rioid;
  __u16 pad0[3];
  __u64 rio_addr;
  __u64 length;
  __u64 handle;
  __u64 address;
};
struct rio_dma_mem {
  __u64 length;
  __u64 dma_handle;
  __u64 address;
};
struct rio_event {
  __u32 header;
  union {
    struct rio_doorbell doorbell;
    struct rio_portwrite portwrite;
  } u;
  __u32 pad0;
};
enum rio_transfer_sync {
  RIO_TRANSFER_SYNC,
  RIO_TRANSFER_ASYNC,
  RIO_TRANSFER_FAF,
};
enum rio_transfer_dir {
  RIO_TRANSFER_DIR_READ,
  RIO_TRANSFER_DIR_WRITE,
};
enum rio_exchange {
  RIO_EXCHANGE_DEFAULT,
  RIO_EXCHANGE_NWRITE,
  RIO_EXCHANGE_SWRITE,
  RIO_EXCHANGE_NWRITE_R,
  RIO_EXCHANGE_SWRITE_R,
  RIO_EXCHANGE_NWRITE_R_ALL,
};
struct rio_transfer_io {
  __u64 rio_addr;
  __u64 loc_addr;
  __u64 handle;
  __u64 offset;
  __u64 length;
  __u16 rioid;
  __u16 method;
  __u32 completion_code;
};
struct rio_transaction {
  __u64 block;
  __u32 count;
  __u32 transfer_mode;
  __u16 sync;
  __u16 dir;
  __u32 pad0;
};
struct rio_async_tx_wait {
  __u32 token;
  __u32 timeout;
};
#define RIO_MAX_DEVNAME_SZ 20
struct rio_rdev_info {
  __u16 destid;
  __u8 hopcount;
  __u8 pad0;
  __u32 comptag;
  char name[RIO_MAX_DEVNAME_SZ + 1];
};
#define RIO_MPORT_DRV_MAGIC 'm'
#define RIO_MPORT_MAINT_HDID_SET _IOW(RIO_MPORT_DRV_MAGIC, 1, __u16)
#define RIO_MPORT_MAINT_COMPTAG_SET _IOW(RIO_MPORT_DRV_MAGIC, 2, __u32)
#define RIO_MPORT_MAINT_PORT_IDX_GET _IOR(RIO_MPORT_DRV_MAGIC, 3, __u32)
#define RIO_MPORT_GET_PROPERTIES _IOR(RIO_MPORT_DRV_MAGIC, 4, struct rio_mport_properties)
#define RIO_MPORT_MAINT_READ_LOCAL _IOR(RIO_MPORT_DRV_MAGIC, 5, struct rio_mport_maint_io)
#define RIO_MPORT_MAINT_WRITE_LOCAL _IOW(RIO_MPORT_DRV_MAGIC, 6, struct rio_mport_maint_io)
#define RIO_MPORT_MAINT_READ_REMOTE _IOR(RIO_MPORT_DRV_MAGIC, 7, struct rio_mport_maint_io)
#define RIO_MPORT_MAINT_WRITE_REMOTE _IOW(RIO_MPORT_DRV_MAGIC, 8, struct rio_mport_maint_io)
#define RIO_ENABLE_DOORBELL_RANGE _IOW(RIO_MPORT_DRV_MAGIC, 9, struct rio_doorbell_filter)
#define RIO_DISABLE_DOORBELL_RANGE _IOW(RIO_MPORT_DRV_MAGIC, 10, struct rio_doorbell_filter)
#define RIO_ENABLE_PORTWRITE_RANGE _IOW(RIO_MPORT_DRV_MAGIC, 11, struct rio_pw_filter)
#define RIO_DISABLE_PORTWRITE_RANGE _IOW(RIO_MPORT_DRV_MAGIC, 12, struct rio_pw_filter)
#define RIO_SET_EVENT_MASK _IOW(RIO_MPORT_DRV_MAGIC, 13, __u32)
#define RIO_GET_EVENT_MASK _IOR(RIO_MPORT_DRV_MAGIC, 14, __u32)
#define RIO_MAP_OUTBOUND _IOWR(RIO_MPORT_DRV_MAGIC, 15, struct rio_mmap)
#define RIO_UNMAP_OUTBOUND _IOW(RIO_MPORT_DRV_MAGIC, 16, struct rio_mmap)
#define RIO_MAP_INBOUND _IOWR(RIO_MPORT_DRV_MAGIC, 17, struct rio_mmap)
#define RIO_UNMAP_INBOUND _IOW(RIO_MPORT_DRV_MAGIC, 18, __u64)
#define RIO_ALLOC_DMA _IOWR(RIO_MPORT_DRV_MAGIC, 19, struct rio_dma_mem)
#define RIO_FREE_DMA _IOW(RIO_MPORT_DRV_MAGIC, 20, __u64)
#define RIO_TRANSFER _IOWR(RIO_MPORT_DRV_MAGIC, 21, struct rio_transaction)
#define RIO_WAIT_FOR_ASYNC _IOW(RIO_MPORT_DRV_MAGIC, 22, struct rio_async_tx_wait)
#define RIO_DEV_ADD _IOW(RIO_MPORT_DRV_MAGIC, 23, struct rio_rdev_info)
#define RIO_DEV_DEL _IOW(RIO_MPORT_DRV_MAGIC, 24, struct rio_rdev_info)
#endif