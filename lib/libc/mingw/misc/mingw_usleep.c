#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <sys/types.h>
#include <errno.h>

int __cdecl usleep (useconds_t);

int __cdecl
usleep (useconds_t us)
{
  if (us != 0)
    Sleep (us / 1000);

  return 0;
}

