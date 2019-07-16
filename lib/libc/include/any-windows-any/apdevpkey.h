/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)
#if _WIN32_WINNT >= 0x0602
#include "devpropdef.h"

DEFINE_DEVPROPKEY(DEVPKEY_DeviceInterface_Autoplay_Silent,0x434dd28f,0x9e75,0x450a,0x9a,0xb9,0xff,0x61,0xe6,0x18,0xba,0xd0,2);
#endif

#endif /* WINAPI_PARTITION_DESKTOP.  */
