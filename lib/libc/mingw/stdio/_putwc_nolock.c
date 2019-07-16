#include <stdio.h>

#undef _putwc_nolock
wint_t __cdecl _putwc_nolock(wchar_t c, FILE *stream);
wint_t __cdecl _putwc_nolock(wchar_t c, FILE *stream)
{
    return _fputwc_nolock(c, stream);
}
