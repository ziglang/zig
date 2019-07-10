/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _INC_WINSDKVER
#define _INC_WINSDKVER

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#define _WIN32_MAXVER         0x0A00
#define _WIN32_WINDOWS_MAXVER 0x0A00
#define NTDDI_MAXVER          0x0A00
#define _WIN32_IE_MAXVER      0x0A00
#define _WIN32_WINNT_MAXVER   0x0A00
#define WINVER_MAXVER         0x0A00

#endif
#endif
