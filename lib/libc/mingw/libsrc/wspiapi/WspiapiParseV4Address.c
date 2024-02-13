#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

WINBOOL WINAPI
WspiapiParseV4Address (const char *pszAddress, PDWORD pdwAddress)
{
  DWORD dwAddress = 0;
  const char *h = NULL;
  int cnt;

  for (cnt = 0,h = pszAddress; *h != 0; h++)
    if (h[0] == '.')
	cnt++;
  if (cnt != 3)
    return FALSE;
  dwAddress = inet_addr (pszAddress);
  if (dwAddress == INADDR_NONE)
    return FALSE;
  *pdwAddress = dwAddress;
  return TRUE;
}
