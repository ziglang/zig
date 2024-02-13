#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

struct addrinfo * WINAPI
WspiapiNewAddrInfo (int iSocketType, int iProtocol, WORD wPort, DWORD dwAddress)
{
  struct addrinfo *n;
  struct sockaddr_in *pa;

  if ((n = (struct addrinfo *) WspiapiMalloc (sizeof (struct addrinfo))) == NULL)
    return NULL;
  if ((pa = (struct sockaddr_in *) WspiapiMalloc (sizeof(struct sockaddr_in))) == NULL)
    {
	WspiapiFree(n);
	return NULL;
    }
  pa->sin_family = AF_INET;
  pa->sin_port = wPort;
  pa->sin_addr.s_addr = dwAddress;
  n->ai_family = PF_INET;
  n->ai_socktype = iSocketType;
  n->ai_protocol = iProtocol;
  n->ai_addrlen = sizeof (struct sockaddr_in);
  n->ai_addr = (struct sockaddr *) pa;
  return n;
}
