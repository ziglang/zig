/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _INC_WINAPIFAMILY
#define _INC_WINAPIFAMILY

#define WINAPI_PARTITION_DESKTOP 0x1
#define WINAPI_PARTITION_APP     0x2    

#define WINAPI_FAMILY_APP WINAPI_PARTITION_APP
#define WINAPI_FAMILY_DESKTOP_APP (WINAPI_PARTITION_DESKTOP \
				   | WINAPI_PARTITION_APP)    

/* WINAPI_FAMILY can be either desktop + App, or App.  */
#ifndef WINAPI_FAMILY
#define WINAPI_FAMILY WINAPI_FAMILY_DESKTOP_APP
#endif

#define WINAPI_FAMILY_PARTITION(v) ((WINAPI_FAMILY & v) == v)
#define WINAPI_FAMILY_ONE_PARTITION(vset, v) ((WINAPI_FAMILY & vset) == v)

#endif 
