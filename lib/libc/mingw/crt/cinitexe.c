#include <stdio.h>
#include <sect_attribs.h>
#include <corecrt_startup.h>

#ifdef _MSC_VER
#pragma comment(linker, "/merge:.CRT=.rdata")
#endif

_CRTALLOC(".CRT$XIA") _PIFV __xi_a[] = { NULL };
_CRTALLOC(".CRT$XIZ") _PIFV __xi_z[] = { NULL };
_CRTALLOC(".CRT$XCA") _PVFV __xc_a[] = { NULL };
_CRTALLOC(".CRT$XCZ") _PVFV __xc_z[] = { NULL };
