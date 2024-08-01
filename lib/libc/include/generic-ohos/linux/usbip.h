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
#ifndef _UAPI_LINUX_USBIP_H
#define _UAPI_LINUX_USBIP_H
enum usbip_device_status {
  SDEV_ST_AVAILABLE = 0x01,
  SDEV_ST_USED,
  SDEV_ST_ERROR,
  VDEV_ST_NULL,
  VDEV_ST_NOTASSIGNED,
  VDEV_ST_USED,
  VDEV_ST_ERROR
};
#endif