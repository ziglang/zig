#include <winbase.h>

static inline HANDLE __mingw_get_msvcrt_handle(void)
{
    return GetModuleHandleW(L"msvcrt.dll");
}
