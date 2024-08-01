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
#ifndef _UAPI_LINUX_DMABUF_POOL_H
#define _UAPI_LINUX_DMABUF_POOL_H
#include <linux/ioctl.h>
#include <linux/types.h>
#include <stddef.h>
#define DMA_HEAP_VALID_FD_FLAGS (O_CLOEXEC | O_ACCMODE)
#define DMA_HEAP_VALID_HEAP_FLAGS (0)
struct dma_heap_allocation_data {
  __u64 len;
  __u32 fd;
  __u32 fd_flags;
  __u64 heap_flags;
};
#define DMA_HEAP_IOC_MAGIC 'H'

enum dma_heap_flag_owner_id {
	OWNER_DEFAULT = 0,
	OWNER_GPU,
	OWNER_MEDIA_CODEC,
	COUNT_DMA_HEAP_FLAG_OWNER,
};

#define OWNER_OFFSET_BIT 27 /* 27 bit */
#define OWNER_MASK (0xfUL << OWNER_OFFSET_BIT)

/* Use the 27-30 bits of heap flags as owner_id flag */
static inline void set_owner_id_for_heap_flags(__u64 *heap_flags, __u64 owner_id)
{
    if (heap_flags == NULL || owner_id >= COUNT_DMA_HEAP_FLAG_OWNER) {
        return;
    }
    *heap_flags |= owner_id << OWNER_OFFSET_BIT;
}

/* To get the binary number of owner_id */
static inline __u64 get_owner_id_from_heap_flags(__u64 heap_flags)
{
    return (heap_flags & OWNER_MASK) >> OWNER_OFFSET_BIT;
}

#define DMA_HEAP_IOCTL_ALLOC _IOWR(DMA_HEAP_IOC_MAGIC, 0x0, struct dma_heap_allocation_data)
#endif