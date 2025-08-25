/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_INFSTR
#define _INC_INFSTR

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

#define INFSTR_SECT_VERSION TEXT("Version")
#define INFSTR_KEY_PROVIDER TEXT("Provider")
#define INFSTR_KEY_HARDWARE_CLASSGUID TEXT("ClassGUID")
#define INFSTR_DRIVERVERSION_SECTION TEXT("DriverVer")

#endif
#endif
