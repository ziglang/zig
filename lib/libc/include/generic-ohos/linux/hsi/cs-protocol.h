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
#ifndef _CS_PROTOCOL_H
#define _CS_PROTOCOL_H
#include <linux/types.h>
#include <linux/ioctl.h>
#define CS_DEV_FILE_NAME "/dev/cmt_speech"
#define CS_IF_VERSION 2
#define CS_CMD_SHIFT 28
#define CS_DOMAIN_SHIFT 24
#define CS_CMD_MASK 0xff000000
#define CS_PARAM_MASK 0xffffff
#define CS_CMD(id,dom) (((id) << CS_CMD_SHIFT) | ((dom) << CS_DOMAIN_SHIFT))
#define CS_ERROR CS_CMD(1, 0)
#define CS_RX_DATA_RECEIVED CS_CMD(2, 0)
#define CS_TX_DATA_READY CS_CMD(3, 0)
#define CS_TX_DATA_SENT CS_CMD(4, 0)
#define CS_ERR_PEER_RESET 0
#define CS_FEAT_TSTAMP_RX_CTRL (1 << 0)
#define CS_FEAT_ROLLING_RX_COUNTER (2 << 0)
#define CS_STATE_CLOSED 0
#define CS_STATE_OPENED 1
#define CS_STATE_CONFIGURED 2
#define CS_MAX_BUFFERS_SHIFT 4
#define CS_MAX_BUFFERS (1 << CS_MAX_BUFFERS_SHIFT)
struct cs_buffer_config {
  __u32 rx_bufs;
  __u32 tx_bufs;
  __u32 buf_size;
  __u32 flags;
  __u32 reserved[4];
};
struct cs_timestamp {
  __u32 tv_sec;
  __u32 tv_nsec;
};
struct cs_mmap_config_block {
  __u32 reserved1;
  __u32 buf_size;
  __u32 rx_bufs;
  __u32 tx_bufs;
  __u32 reserved2;
  __u32 rx_offsets[CS_MAX_BUFFERS];
  __u32 tx_offsets[CS_MAX_BUFFERS];
  __u32 rx_ptr;
  __u32 rx_ptr_boundary;
  __u32 reserved3[2];
  struct cs_timestamp tstamp_rx_ctrl;
};
#define CS_IO_MAGIC 'C'
#define CS_IOW(num,dtype) _IOW(CS_IO_MAGIC, num, dtype)
#define CS_IOR(num,dtype) _IOR(CS_IO_MAGIC, num, dtype)
#define CS_IOWR(num,dtype) _IOWR(CS_IO_MAGIC, num, dtype)
#define CS_IO(num) _IO(CS_IO_MAGIC, num)
#define CS_GET_STATE CS_IOR(21, unsigned int)
#define CS_SET_WAKELINE CS_IOW(23, unsigned int)
#define CS_GET_IF_VERSION CS_IOR(30, unsigned int)
#define CS_CONFIG_BUFS CS_IOW(31, struct cs_buffer_config)
#endif