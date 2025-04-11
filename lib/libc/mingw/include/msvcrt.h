#ifndef __LIBMSVCRT_OS__
#error "This file should only be used in libmsvcrt-os.a"
#endif

#ifndef MSVCRT_H
#define MSVCRT_H

#include <winbase.h>

static inline HMODULE __mingw_get_msvcrt_handle(void)
{
    return GetModuleHandleA("msvcrt.dll");
}

#endif
