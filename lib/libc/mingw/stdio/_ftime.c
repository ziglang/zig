#define __CRT__NO_INLINE
#include <sys/stat.h>
#include <sys/timeb.h>

/* FIXME: Relying on _USE_32BIT_TIME_T, which is a user-macro,
during CRT compilation is plainly broken.  Need an appropriate
implementation to provide users the ability of compiling the
CRT only with 32-bit time_t behavior. */
#if defined(_USE_32BIT_TIME_T)
void __cdecl ftime (struct timeb *b)
{
  return _ftime ((struct __timeb32 *)b);
}
#else
void __cdecl ftime (struct timeb *b)
{
  _ftime64((struct __timeb64 *)b);
}
#endif
