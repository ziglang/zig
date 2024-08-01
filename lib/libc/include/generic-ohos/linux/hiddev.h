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
#ifndef _UAPI_HIDDEV_H
#define _UAPI_HIDDEV_H
#include <linux/types.h>
struct hiddev_event {
  unsigned hid;
  signed int value;
};
struct hiddev_devinfo {
  __u32 bustype;
  __u32 busnum;
  __u32 devnum;
  __u32 ifnum;
  __s16 vendor;
  __s16 product;
  __s16 version;
  __u32 num_applications;
};
struct hiddev_collection_info {
  __u32 index;
  __u32 type;
  __u32 usage;
  __u32 level;
};
#define HID_STRING_SIZE 256
struct hiddev_string_descriptor {
  __s32 index;
  char value[HID_STRING_SIZE];
};
struct hiddev_report_info {
  __u32 report_type;
  __u32 report_id;
  __u32 num_fields;
};
#define HID_REPORT_ID_UNKNOWN 0xffffffff
#define HID_REPORT_ID_FIRST 0x00000100
#define HID_REPORT_ID_NEXT 0x00000200
#define HID_REPORT_ID_MASK 0x000000ff
#define HID_REPORT_ID_MAX 0x000000ff
#define HID_REPORT_TYPE_INPUT 1
#define HID_REPORT_TYPE_OUTPUT 2
#define HID_REPORT_TYPE_FEATURE 3
#define HID_REPORT_TYPE_MIN 1
#define HID_REPORT_TYPE_MAX 3
struct hiddev_field_info {
  __u32 report_type;
  __u32 report_id;
  __u32 field_index;
  __u32 maxusage;
  __u32 flags;
  __u32 physical;
  __u32 logical;
  __u32 application;
  __s32 logical_minimum;
  __s32 logical_maximum;
  __s32 physical_minimum;
  __s32 physical_maximum;
  __u32 unit_exponent;
  __u32 unit;
};
#define HID_FIELD_CONSTANT 0x001
#define HID_FIELD_VARIABLE 0x002
#define HID_FIELD_RELATIVE 0x004
#define HID_FIELD_WRAP 0x008
#define HID_FIELD_NONLINEAR 0x010
#define HID_FIELD_NO_PREFERRED 0x020
#define HID_FIELD_NULL_STATE 0x040
#define HID_FIELD_VOLATILE 0x080
#define HID_FIELD_BUFFERED_BYTE 0x100
struct hiddev_usage_ref {
  __u32 report_type;
  __u32 report_id;
  __u32 field_index;
  __u32 usage_index;
  __u32 usage_code;
  __s32 value;
};
#define HID_MAX_MULTI_USAGES 1024
struct hiddev_usage_ref_multi {
  struct hiddev_usage_ref uref;
  __u32 num_values;
  __s32 values[HID_MAX_MULTI_USAGES];
};
#define HID_FIELD_INDEX_NONE 0xffffffff
#define HID_VERSION 0x010004
#define HIDIOCGVERSION _IOR('H', 0x01, int)
#define HIDIOCAPPLICATION _IO('H', 0x02)
#define HIDIOCGDEVINFO _IOR('H', 0x03, struct hiddev_devinfo)
#define HIDIOCGSTRING _IOR('H', 0x04, struct hiddev_string_descriptor)
#define HIDIOCINITREPORT _IO('H', 0x05)
#define HIDIOCGNAME(len) _IOC(_IOC_READ, 'H', 0x06, len)
#define HIDIOCGREPORT _IOW('H', 0x07, struct hiddev_report_info)
#define HIDIOCSREPORT _IOW('H', 0x08, struct hiddev_report_info)
#define HIDIOCGREPORTINFO _IOWR('H', 0x09, struct hiddev_report_info)
#define HIDIOCGFIELDINFO _IOWR('H', 0x0A, struct hiddev_field_info)
#define HIDIOCGUSAGE _IOWR('H', 0x0B, struct hiddev_usage_ref)
#define HIDIOCSUSAGE _IOW('H', 0x0C, struct hiddev_usage_ref)
#define HIDIOCGUCODE _IOWR('H', 0x0D, struct hiddev_usage_ref)
#define HIDIOCGFLAG _IOR('H', 0x0E, int)
#define HIDIOCSFLAG _IOW('H', 0x0F, int)
#define HIDIOCGCOLLECTIONINDEX _IOW('H', 0x10, struct hiddev_usage_ref)
#define HIDIOCGCOLLECTIONINFO _IOWR('H', 0x11, struct hiddev_collection_info)
#define HIDIOCGPHYS(len) _IOC(_IOC_READ, 'H', 0x12, len)
#define HIDIOCGUSAGES _IOWR('H', 0x13, struct hiddev_usage_ref_multi)
#define HIDIOCSUSAGES _IOW('H', 0x14, struct hiddev_usage_ref_multi)
#define HIDDEV_FLAG_UREF 0x1
#define HIDDEV_FLAG_REPORT 0x2
#define HIDDEV_FLAGS 0x3
#endif