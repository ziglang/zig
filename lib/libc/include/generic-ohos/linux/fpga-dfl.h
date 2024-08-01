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
#ifndef _UAPI_LINUX_FPGA_DFL_H
#define _UAPI_LINUX_FPGA_DFL_H
#include <linux/types.h>
#include <linux/ioctl.h>
#define DFL_FPGA_API_VERSION 0
#define DFL_FPGA_MAGIC 0xB6
#define DFL_FPGA_BASE 0
#define DFL_PORT_BASE 0x40
#define DFL_FME_BASE 0x80
#define DFL_FPGA_GET_API_VERSION _IO(DFL_FPGA_MAGIC, DFL_FPGA_BASE + 0)
#define DFL_FPGA_CHECK_EXTENSION _IO(DFL_FPGA_MAGIC, DFL_FPGA_BASE + 1)
#define DFL_FPGA_PORT_RESET _IO(DFL_FPGA_MAGIC, DFL_PORT_BASE + 0)
struct dfl_fpga_port_info {
  __u32 argsz;
  __u32 flags;
  __u32 num_regions;
  __u32 num_umsgs;
};
#define DFL_FPGA_PORT_GET_INFO _IO(DFL_FPGA_MAGIC, DFL_PORT_BASE + 1)
struct dfl_fpga_port_region_info {
  __u32 argsz;
  __u32 flags;
#define DFL_PORT_REGION_READ (1 << 0)
#define DFL_PORT_REGION_WRITE (1 << 1)
#define DFL_PORT_REGION_MMAP (1 << 2)
  __u32 index;
#define DFL_PORT_REGION_INDEX_AFU 0
#define DFL_PORT_REGION_INDEX_STP 1
  __u32 padding;
  __u64 size;
  __u64 offset;
};
#define DFL_FPGA_PORT_GET_REGION_INFO _IO(DFL_FPGA_MAGIC, DFL_PORT_BASE + 2)
struct dfl_fpga_port_dma_map {
  __u32 argsz;
  __u32 flags;
  __u64 user_addr;
  __u64 length;
  __u64 iova;
};
#define DFL_FPGA_PORT_DMA_MAP _IO(DFL_FPGA_MAGIC, DFL_PORT_BASE + 3)
struct dfl_fpga_port_dma_unmap {
  __u32 argsz;
  __u32 flags;
  __u64 iova;
};
#define DFL_FPGA_PORT_DMA_UNMAP _IO(DFL_FPGA_MAGIC, DFL_PORT_BASE + 4)
struct dfl_fpga_irq_set {
  __u32 start;
  __u32 count;
  __s32 evtfds[];
};
#define DFL_FPGA_PORT_ERR_GET_IRQ_NUM _IOR(DFL_FPGA_MAGIC, DFL_PORT_BASE + 5, __u32)
#define DFL_FPGA_PORT_ERR_SET_IRQ _IOW(DFL_FPGA_MAGIC, DFL_PORT_BASE + 6, struct dfl_fpga_irq_set)
#define DFL_FPGA_PORT_UINT_GET_IRQ_NUM _IOR(DFL_FPGA_MAGIC, DFL_PORT_BASE + 7, __u32)
#define DFL_FPGA_PORT_UINT_SET_IRQ _IOW(DFL_FPGA_MAGIC, DFL_PORT_BASE + 8, struct dfl_fpga_irq_set)
struct dfl_fpga_fme_port_pr {
  __u32 argsz;
  __u32 flags;
  __u32 port_id;
  __u32 buffer_size;
  __u64 buffer_address;
};
#define DFL_FPGA_FME_PORT_PR _IO(DFL_FPGA_MAGIC, DFL_FME_BASE + 0)
#define DFL_FPGA_FME_PORT_RELEASE _IOW(DFL_FPGA_MAGIC, DFL_FME_BASE + 1, int)
#define DFL_FPGA_FME_PORT_ASSIGN _IOW(DFL_FPGA_MAGIC, DFL_FME_BASE + 2, int)
#define DFL_FPGA_FME_ERR_GET_IRQ_NUM _IOR(DFL_FPGA_MAGIC, DFL_FME_BASE + 3, __u32)
#define DFL_FPGA_FME_ERR_SET_IRQ _IOW(DFL_FPGA_MAGIC, DFL_FME_BASE + 4, struct dfl_fpga_irq_set)
#endif