#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

int WINAPI
WspiapiGetNameInfo (const struct sockaddr *sa, socklen_t salen,
		    char *host, size_t hostlen,
		    char *serv, size_t servlen, int flags)
{
  static WSPIAPI_PGETNAMEINFO pfGetNameInfo = NULL;
  int err;

  if (!pfGetNameInfo)
    pfGetNameInfo = (WSPIAPI_PGETNAMEINFO) WspiapiLoad(1);
  err = (*pfGetNameInfo) (sa, salen, host, hostlen, serv, servlen, flags);
  WSASetLastError (err);
  return err;
}
