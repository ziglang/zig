#include <stdio.h>

#undef _getwc_nolock
wint_t __cdecl _getwc_nolock(FILE *stream);
wint_t __cdecl _getwc_nolock(FILE *stream)
{
    return _fgetwc_nolock(stream);
}
