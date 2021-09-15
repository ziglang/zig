/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <stdio.h>
#include <io.h>
#include <errno.h>

#if !defined(__arm__) && !defined(__aarch64__) /* we have F_ARM_ANY(_fseeki64) in msvcrt.def.in */
int __cdecl _fseeki64(FILE* stream, __int64 offset, int whence)
{
  fpos_t pos;
  if (whence == SEEK_CUR)
    {
      /* If stream is invalid, fgetpos sets errno. */
      if (fgetpos (stream, &pos))
        return (-1);
      pos += (fpos_t) offset;
    }
  else if (whence == SEEK_END)
    {
      /* If writing, we need to flush before getting file length.  */
      fflush (stream);
      pos = (fpos_t) (_filelengthi64 (_fileno (stream)) + offset);
    }
  else if (whence == SEEK_SET)
    pos = (fpos_t) offset;
  else
    {
      errno = EINVAL;
      return (-1);
    }
  return fsetpos (stream, &pos);
}

int __cdecl (*__MINGW_IMP_SYMBOL(_fseeki64))(FILE*, __int64, int) = _fseeki64;
#endif /* !defined(__arm__) && !defined(__aarch64__) */

__int64 __cdecl _ftelli64(FILE* stream)
{
  fpos_t pos;
  if (fgetpos (stream, &pos))
    return -1LL;
  else
    return (__int64) pos;
}

__int64 __cdecl (*__MINGW_IMP_SYMBOL(_ftelli64))(FILE*) = _ftelli64;

