/*
 * hidclass.h
 *
 * HID class driver interface
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __HIDCLASS_H
#define __HIDCLASS_H

#include "hidpi.h"

#ifdef __cplusplus
extern "C" {
#endif

#define HID_REVISION                      0x00000001

DEFINE_GUID (GUID_DEVINTERFACE_HID, \
  0x4D1E55B2L, 0xF16F, 0x11CF, 0x88, 0xCB, 0x00, 0x11, 0x11, 0x00, 0x00, 0x30);
DEFINE_GUID (GUID_HID_INTERFACE_NOTIFY, \
  0x2c4e2e88L, 0x25e6, 0x4c33, 0x88, 0x2f, 0x3d, 0x82, 0xe6, 0x07, 0x36, 0x81);
DEFINE_GUID (GUID_HID_INTERFACE_HIDPARSE, \
  0xf5c315a5, 0x69ac, 0x4bc2, 0x92, 0x79, 0xd0, 0xb6, 0x45, 0x76, 0xf4, 0x4b);

#define GUID_CLASS_INPUT GUID_DEVINTERFACE_HID

#define GUID_CLASS_INPUT_STR "4D1E55B2-F16F-11CF-88CB-001111000030"


#define HID_CTL_CODE(id) \
  CTL_CODE (FILE_DEVICE_KEYBOARD, (id), METHOD_NEITHER, FILE_ANY_ACCESS)
#define HID_BUFFER_CTL_CODE(id) \
  CTL_CODE (FILE_DEVICE_KEYBOARD, (id), METHOD_BUFFERED, FILE_ANY_ACCESS)
#define HID_IN_CTL_CODE(id) \
  CTL_CODE (FILE_DEVICE_KEYBOARD, (id), METHOD_IN_DIRECT, FILE_ANY_ACCESS)
#define HID_OUT_CTL_CODE(id) \
  CTL_CODE (FILE_DEVICE_KEYBOARD, (id), METHOD_OUT_DIRECT, FILE_ANY_ACCESS)


#define IOCTL_GET_PHYSICAL_DESCRIPTOR         HID_OUT_CTL_CODE(102)
#define IOCTL_HID_FLUSH_QUEUE                 HID_CTL_CODE(101)
#define IOCTL_HID_GET_COLLECTION_DESCRIPTOR   HID_CTL_CODE(100)
#define IOCTL_HID_GET_COLLECTION_INFORMATION  HID_BUFFER_CTL_CODE(106)
#define IOCTL_HID_GET_FEATURE                 HID_OUT_CTL_CODE(100)
#define IOCTL_HID_GET_HARDWARE_ID             HID_OUT_CTL_CODE(103)
#define IOCTL_HID_GET_INDEXED_STRING          HID_OUT_CTL_CODE(120)
#define IOCTL_HID_GET_INPUT_REPORT            HID_OUT_CTL_CODE(104)
#define IOCTL_HID_GET_MANUFACTURER_STRING     HID_OUT_CTL_CODE(110)
#define IOCTL_GET_NUM_DEVICE_INPUT_BUFFERS    HID_BUFFER_CTL_CODE(104)
#define IOCTL_HID_GET_POLL_FREQUENCY_MSEC     HID_BUFFER_CTL_CODE(102)
#define IOCTL_HID_GET_PRODUCT_STRING          HID_OUT_CTL_CODE(111)
#define IOCTL_HID_GET_SERIALNUMBER_STRING     HID_OUT_CTL_CODE(112)
#define IOCTL_HID_SET_FEATURE                 HID_IN_CTL_CODE(100)
#define IOCTL_SET_NUM_DEVICE_INPUT_BUFFERS    HID_BUFFER_CTL_CODE(105)
#define IOCTL_HID_SET_OUTPUT_REPORT           HID_IN_CTL_CODE(101)
#define IOCTL_HID_SET_POLL_FREQUENCY_MSEC     HID_BUFFER_CTL_CODE(103)

#define IOCTL_HID_GET_DRIVER_CONFIG           HID_BUFFER_CTL_CODE(100)
#define IOCTL_HID_SET_DRIVER_CONFIG           HID_BUFFER_CTL_CODE(101)
#define IOCTL_HID_GET_MS_GENRE_DESCRIPTOR     HID_OUT_CTL_CODE(121)

/* FIXME: these values are wrong! */
#define IOCTL_HID_GET_STRING                  0
#define IOCTL_HID_GET_DEVICE_ATTRIBUTES       1
#define IOCTL_HID_GET_DEVICE_DESCRIPTOR       2
#define IOCTL_HID_READ_REPORT                 3
#define IOCTL_HID_WRITE_REPORT                4
#define IOCTL_HID_GET_REPORT_DESCRIPTOR       5

typedef enum _HID_STRING_TYPE
{
	HID_STRING_INDEXED = 0,
	HID_STRING_ID_IMANUFACTURER,
	HID_STRING_ID_IPRODUCT,
	HID_STRING_ID_ISERIALNUMBER,
	HID_STRING_MAX
} HID_STRING_TYPE;

enum DeviceObjectState {
  DeviceObjectStarted = 0,
  DeviceObjectStopped,
  DeviceObjectRemoved
};

typedef VOID (NTAPI *PHID_STATUS_CHANGE)(
  PVOID  Context,
  enum DeviceObjectState  State);

typedef NTSTATUS (NTAPI *PHIDP_GETCAPS)(
  IN PHIDP_PREPARSED_DATA  PreparsedData,
  OUT PHIDP_CAPS  Capabilities);

typedef struct _HID_COLLECTION_INFORMATION {
  ULONG  DescriptorSize;
  BOOLEAN  Polled;
  UCHAR  Reserved1[1];
  USHORT  VendorID;
  USHORT  ProductID;
  USHORT  VersionNumber;
} HID_COLLECTION_INFORMATION, *PHID_COLLECTION_INFORMATION;

typedef struct _HID_DRIVER_CONFIG {
  ULONG  Size;
  ULONG  RingBufferSize;
} HID_DRIVER_CONFIG, *PHID_DRIVER_CONFIG;

typedef struct _HID_INTERFACE_HIDPARSE {
#ifdef __cplusplus
  INTERFACE  i;
#else
  /* GCC doesn't support including unnamed structs, so INTERFACE is
     expanded here */
  USHORT  Size;
  USHORT  Version;
  PVOID  Context;
  PINTERFACE_REFERENCE  InterfaceReference;
  PINTERFACE_DEREFERENCE  InterfaceDereference;
#endif
  PHIDP_GETCAPS  HidpGetCaps;
} HID_INTERFACE_HIDPARSE, *PHID_INTERFACE_HIDPARSE;

typedef struct _HID_INTERFACE_NOTIFY_PNP {
#ifdef __cplusplus
  INTERFACE  i;
#else
  /* GCC doesn't support including unnamed structs, so INTERFACE is
     expanded here */
  USHORT  Size;
  USHORT  Version;
  PVOID  Context;
  PINTERFACE_REFERENCE  InterfaceReference;
  PINTERFACE_DEREFERENCE  InterfaceDereference;
#endif
  PHID_STATUS_CHANGE  StatusChangeFn;
  PVOID  CallbackContext;
} HID_INTERFACE_NOTIFY_PNP, *PHID_INTERFACE_NOTIFY_PNP;

typedef struct _HID_XFER_PACKET {
  PUCHAR  reportBuffer;
  ULONG  reportBufferLen;
  UCHAR  reportId;
} HID_XFER_PACKET, *PHID_XFER_PACKET;

#ifdef __cplusplus
}
#endif

#endif /* __HIDCLASS_H */
