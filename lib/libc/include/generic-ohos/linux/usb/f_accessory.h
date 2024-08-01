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
#ifndef _UAPI_LINUX_USB_F_ACCESSORY_H
#define _UAPI_LINUX_USB_F_ACCESSORY_H
#define USB_ACCESSORY_VENDOR_ID 0x18D1
#define USB_ACCESSORY_PRODUCT_ID 0x2D00
#define USB_ACCESSORY_ADB_PRODUCT_ID 0x2D01
#define ACCESSORY_STRING_MANUFACTURER 0
#define ACCESSORY_STRING_MODEL 1
#define ACCESSORY_STRING_DESCRIPTION 2
#define ACCESSORY_STRING_VERSION 3
#define ACCESSORY_STRING_URI 4
#define ACCESSORY_STRING_SERIAL 5
#define ACCESSORY_GET_PROTOCOL 51
#define ACCESSORY_SEND_STRING 52
#define ACCESSORY_START 53
#define ACCESSORY_REGISTER_HID 54
#define ACCESSORY_UNREGISTER_HID 55
#define ACCESSORY_SET_HID_REPORT_DESC 56
#define ACCESSORY_SEND_HID_EVENT 57
#define ACCESSORY_SET_AUDIO_MODE 58
#define ACCESSORY_GET_STRING_MANUFACTURER _IOW('M', 1, char[256])
#define ACCESSORY_GET_STRING_MODEL _IOW('M', 2, char[256])
#define ACCESSORY_GET_STRING_DESCRIPTION _IOW('M', 3, char[256])
#define ACCESSORY_GET_STRING_VERSION _IOW('M', 4, char[256])
#define ACCESSORY_GET_STRING_URI _IOW('M', 5, char[256])
#define ACCESSORY_GET_STRING_SERIAL _IOW('M', 6, char[256])
#define ACCESSORY_IS_START_REQUESTED _IO('M', 7)
#define ACCESSORY_GET_AUDIO_MODE _IO('M', 8)
#endif