#include <stdio.h>
#include <sect_attribs.h>

#ifdef _MSC_VER
#pragma comment(linker, "/merge:.CRT=.rdata")
#endif

typedef void (__cdecl *_PVFV)(void);

_CRTALLOC(".CRT$XIA") _PVFV __xi_a[] = { NULL };
_CRTALLOC(".CRT$XIZ") _PVFV __xi_z[] = { NULL };
_CRTALLOC(".CRT$XCA") _PVFV __xc_a[] = { NULL };
_CRTALLOC(".CRT$XCZ") _PVFV __xc_z[] = { NULL };
