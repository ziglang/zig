/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef _INC_COMLITE_
#define _INC_COMLITE_

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#define QzInitialize CoInitialize
#define QzUninitialize CoUninitialize
#define QzFreeUnusedLibraries CoFreeUnusedLibraries

#define QzGetMalloc CoGetMalloc
#define QzTaskMemAlloc CoTaskMemAlloc
#define QzTaskMemRealloc CoTaskMemRealloc
#define QzTaskMemFree CoTaskMemFree
#define QzCreateFilterObject CoCreateInstance
#define QzCLSIDFromString CLSIDFromString
#define QzStringFromGUID2 StringFromGUID2
#endif

#endif
