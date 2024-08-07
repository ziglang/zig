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
#ifndef _UAPIUUACCE_H
#define _UAPIUUACCE_H
#include <linux/types.h>
#include <linux/ioctl.h>
#define UACCE_CMD_START_Q _IO('W', 0)
#define UACCE_CMD_PUT_Q _IO('W', 1)
#define UACCE_DEV_SVA BIT(0)
enum uacce_qfrt {
  UACCE_QFRT_MMIO = 0,
  UACCE_QFRT_DUS = 1,
};
#endif