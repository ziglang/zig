/*
 * ntdd1394.h
 *
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 *
 * Initial contributor is Magnus Olsen.
 * Extended by Kai Tietz
 */

#ifndef _NTDD1394_H_
#define _NTDD1394_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

#define BUS1394_VIRTUAL_DEVICE_LIST_KEY L"Virtual Device List"
#define BUS1394_LOCAL_HOST_INSTANCE_KEY L"LOCAL HOST EUI64"

  typedef struct _IEEE1394_VDEV_PNP_REQUEST {
    ULONG fulFlags;
    ULONG Reserved;
    ULARGE_INTEGER InstanceId;
    UCHAR DeviceId;
  } IEEE1394_VDEV_PNP_REQUEST,*PIEEE1394_VDEV_PNP_REQUEST;

  typedef struct _IEEE1394_API_REQUEST {
    ULONG RequestNumber;
    ULONG Flags;
    union {
      IEEE1394_VDEV_PNP_REQUEST AddVirtualDevice;
      IEEE1394_VDEV_PNP_REQUEST RemoveVirtualDevice;
    } u;
  } IEEE1394_API_REQUEST,*PIEEE1394_API_REQUEST;

#define IEEE1394_API_ADD_VIRTUAL_DEVICE 0x00000001
#define IEEE1394_API_REMOVE_VIRTUAL_DEVICE 0x00000002
#define IEEE1394_REQUEST_FLAG_UNICODE 0x00000001
#define IEEE1394_REQUEST_FLAG_PERSISTENT 0x00000002
#define IEEE1394_REQUEST_FLAG_USE_LOCAL_HOST_EUI 0x00000004
#define BUS1394_VIRTUAL_DEVICE_LIST_KEY L"Virtual Device List"
#define BUS1394_LOCAL_HOST_INSTANCE_KEY L"LOCAL HOST EUI64"
#define IOCTL_IEEE1394_API_REQUEST CTL_CODE (FILE_DEVICE_UNKNOWN, 0x100, METHOD_BUFFERED, FILE_ANY_ACCESS)

#ifdef __cplusplus
}
#endif
#endif
#endif
