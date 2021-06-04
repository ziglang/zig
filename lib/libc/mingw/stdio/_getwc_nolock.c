#undef __MSVCRT_VERSION__
#define __MSVCRT_VERSION__ 0x800
#include <stdio.h>

#undef _getwc_nolock
wint_t __cdecl _getwc_nolock(FILE *stream);
wint_t __cdecl _getwc_nolock(FILE *stream)
{
    return _fgetwc_nolock(stream);
}
