/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef __GPIO_W__
#define __GPIO_W__

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#if NTDDI_VERSION >= 0x06020000
#define IOCTL_GPIO_READ_PINS CTL_CODE (FILE_DEVICE_GPIO, 0x0, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_GPIO_WRITE_PINS CTL_CODE (FILE_DEVICE_GPIO, 0x1, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_GPIO_CONTROLLER_SPECIFIC_FUNCTION CTL_CODE (FILE_DEVICE_GPIO, 0x2, METHOD_BUFFERED, FILE_ANY_ACCESS)
#endif

#endif
#endif
