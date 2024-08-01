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
#ifndef _UAPI_HIDRAW_H
#define _UAPI_HIDRAW_H
#include <linux/hid.h>
#include <linux/types.h>
struct hidraw_report_descriptor {
  __u32 size;
  __u8 value[HID_MAX_DESCRIPTOR_SIZE];
};
struct hidraw_devinfo {
  __u32 bustype;
  __s16 vendor;
  __s16 product;
};
#define HIDIOCGRDESCSIZE _IOR('H', 0x01, int)
#define HIDIOCGRDESC _IOR('H', 0x02, struct hidraw_report_descriptor)
#define HIDIOCGRAWINFO _IOR('H', 0x03, struct hidraw_devinfo)
#define HIDIOCGRAWNAME(len) _IOC(_IOC_READ, 'H', 0x04, len)
#define HIDIOCGRAWPHYS(len) _IOC(_IOC_READ, 'H', 0x05, len)
#define HIDIOCSFEATURE(len) _IOC(_IOC_WRITE | _IOC_READ, 'H', 0x06, len)
#define HIDIOCGFEATURE(len) _IOC(_IOC_WRITE | _IOC_READ, 'H', 0x07, len)
#define HIDIOCGRAWUNIQ(len) _IOC(_IOC_READ, 'H', 0x08, len)
#define HIDRAW_FIRST_MINOR 0
#define HIDRAW_MAX_DEVICES 64
#define HIDRAW_BUFFER_SIZE 64
#endif