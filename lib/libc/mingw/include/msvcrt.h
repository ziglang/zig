#include <winbase.h>

#ifndef __LIBMSVCRT__
#error "This file should only be used in libmsvcrt.a"
#endif

static inline HANDLE __mingw_get_msvcrt_handle(void)
{
    return GetModuleHandleW(L"msvcrt.dll");
}
