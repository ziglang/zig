#define __CRT__NO_INLINE 1
#include <windows.h>

PVOID WINAPI RtlSecureZeroMemory(PVOID ptr,SIZE_T cnt)
{
  volatile char *vptr = (volatile char *)ptr;
#ifdef __x86_64
  __stosb ((PBYTE)((DWORD64)vptr),0,cnt);
#else
  while (cnt != 0)
    {
      *vptr++ = 0;
      cnt--;
    }
#endif /* __x86_64 */
  return ptr;
}
