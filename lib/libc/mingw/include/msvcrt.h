#include <winbase.h>

#ifndef __LIBMSVCRT_OS__
#error "This file should only be used in libmsvcrt-os.a"
#endif

static inline HANDLE __mingw_get_msvcrt_handle(void)
{
    return GetModuleHandleW(L"msvcrt.dll");
}
