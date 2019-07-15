#include <stdio.h>

#undef _getc_nolock
int __cdecl _getc_nolock(FILE *stream);
int __cdecl _getc_nolock(FILE *stream)
{
    return _fgetc_nolock(stream);
}
