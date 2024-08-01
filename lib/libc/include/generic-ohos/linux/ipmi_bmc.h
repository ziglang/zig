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
#ifndef _UAPI_LINUX_IPMI_BMC_H
#define _UAPI_LINUX_IPMI_BMC_H
#include <linux/ioctl.h>
#define __IPMI_BMC_IOCTL_MAGIC 0xB1
#define IPMI_BMC_IOCTL_SET_SMS_ATN _IO(__IPMI_BMC_IOCTL_MAGIC, 0x00)
#define IPMI_BMC_IOCTL_CLEAR_SMS_ATN _IO(__IPMI_BMC_IOCTL_MAGIC, 0x01)
#define IPMI_BMC_IOCTL_FORCE_ABORT _IO(__IPMI_BMC_IOCTL_MAGIC, 0x02)
#endif