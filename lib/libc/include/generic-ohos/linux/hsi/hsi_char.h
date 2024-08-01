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
#ifndef __HSI_CHAR_H
#define __HSI_CHAR_H
#include <linux/types.h>
#define HSI_CHAR_MAGIC 'k'
#define HSC_IOW(num,dtype) _IOW(HSI_CHAR_MAGIC, num, dtype)
#define HSC_IOR(num,dtype) _IOR(HSI_CHAR_MAGIC, num, dtype)
#define HSC_IOWR(num,dtype) _IOWR(HSI_CHAR_MAGIC, num, dtype)
#define HSC_IO(num) _IO(HSI_CHAR_MAGIC, num)
#define HSC_RESET HSC_IO(16)
#define HSC_SET_PM HSC_IO(17)
#define HSC_SEND_BREAK HSC_IO(18)
#define HSC_SET_RX HSC_IOW(19, struct hsc_rx_config)
#define HSC_GET_RX HSC_IOW(20, struct hsc_rx_config)
#define HSC_SET_TX HSC_IOW(21, struct hsc_tx_config)
#define HSC_GET_TX HSC_IOW(22, struct hsc_tx_config)
#define HSC_PM_DISABLE 0
#define HSC_PM_ENABLE 1
#define HSC_MODE_STREAM 1
#define HSC_MODE_FRAME 2
#define HSC_FLOW_SYNC 0
#define HSC_ARB_RR 0
#define HSC_ARB_PRIO 1
struct hsc_rx_config {
  __u32 mode;
  __u32 flow;
  __u32 channels;
};
struct hsc_tx_config {
  __u32 mode;
  __u32 channels;
  __u32 speed;
  __u32 arb_mode;
};
#endif