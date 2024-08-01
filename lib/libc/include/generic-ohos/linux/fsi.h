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
#ifndef _UAPI_LINUX_FSI_H
#define _UAPI_LINUX_FSI_H
#include <linux/types.h>
#include <linux/ioctl.h>
struct scom_access {
  __u64 addr;
  __u64 data;
  __u64 mask;
  __u32 intf_errors;
#define SCOM_INTF_ERR_PARITY 0x00000001
#define SCOM_INTF_ERR_PROTECTION 0x00000002
#define SCOM_INTF_ERR_ABORT 0x00000004
#define SCOM_INTF_ERR_UNKNOWN 0x80000000
  __u8 pib_status;
#define SCOM_PIB_SUCCESS 0
#define SCOM_PIB_BLOCKED 1
#define SCOM_PIB_OFFLINE 2
#define SCOM_PIB_PARTIAL 3
#define SCOM_PIB_BAD_ADDR 4
#define SCOM_PIB_CLK_ERR 5
#define SCOM_PIB_PARITY_ERR 6
#define SCOM_PIB_TIMEOUT 7
  __u8 pad;
};
#define SCOM_CHECK_SUPPORTED 0x00000001
#define SCOM_CHECK_PROTECTED 0x00000002
#define SCOM_RESET_INTF 0x00000001
#define SCOM_RESET_PIB 0x00000002
#define FSI_SCOM_CHECK _IOR('s', 0x00, __u32)
#define FSI_SCOM_READ _IOWR('s', 0x01, struct scom_access)
#define FSI_SCOM_WRITE _IOWR('s', 0x02, struct scom_access)
#define FSI_SCOM_RESET _IOW('s', 0x03, __u32)
#endif