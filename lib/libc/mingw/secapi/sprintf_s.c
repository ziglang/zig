#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/stdio_s.h>

int __cdecl (*__MINGW_IMP_SYMBOL(sprintf_s))(char *, size_t, const char *,...) = sprintf_s;

int __cdecl
sprintf_s (char *_DstBuf, size_t _Size, const char *_Format, ...)
{
  va_list argp;
  int r;

  va_start (argp, _Format);
  r = vsprintf_s (_DstBuf, _Size, _Format, argp);
  va_end (argp);
  return r; 
}
