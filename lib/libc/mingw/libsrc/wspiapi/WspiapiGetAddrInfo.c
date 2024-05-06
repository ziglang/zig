#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

int WINAPI
WspiapiGetAddrInfo(const char *nodename, const char *servname,
		   const struct addrinfo *hints, struct addrinfo **res)
{
  static WSPIAPI_PGETADDRINFO pfGetAddrInfo = NULL;
  int err;

  if (!pfGetAddrInfo)
    pfGetAddrInfo = (WSPIAPI_PGETADDRINFO) WspiapiLoad (0);
  err = (*pfGetAddrInfo) (nodename, servname, hints, res);
  WSASetLastError (err);
  return err;
}
