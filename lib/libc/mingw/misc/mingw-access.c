/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <windows.h>
#include <errno.h>
#include <io.h>

int __cdecl __mingw_access(const char *fname, int mode);

int __cdecl __mingw_access(const char *fname, int mode)
{
  DWORD attr;

  if (fname == NULL || (mode & ~(F_OK | X_OK | W_OK | R_OK)))
  {
    errno = EINVAL;
    return -1;
  }

  attr = GetFileAttributesA(fname);
  if (attr == INVALID_FILE_ATTRIBUTES)
  {
    switch (GetLastError())
    {
      case ERROR_FILE_NOT_FOUND:
      case ERROR_PATH_NOT_FOUND:
        errno = ENOENT;
        break;
      case ERROR_ACCESS_DENIED:
        errno = EACCES;
        break;
      default:
        errno = EINVAL;
    }
    return -1;
  }

  if (attr & FILE_ATTRIBUTE_DIRECTORY)
  {
    /* All directories have read & write access */
    return 0;
  }

  if ((attr & FILE_ATTRIBUTE_READONLY) && (mode & W_OK))
  {
    /* no write permission on file */
    errno = EACCES;
    return -1;
  }
  else
    return 0;
}
