#include <stdio.h>

#undef _putc_nolock
int __cdecl _putc_nolock(int c, FILE *stream);
int __cdecl _putc_nolock(int c, FILE *stream)
{
    return _fputc_nolock(c, stream);
}
