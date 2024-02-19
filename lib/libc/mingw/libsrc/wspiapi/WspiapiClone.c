#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

int WINAPI
WspiapiClone (WORD wPort, struct addrinfo *ptResult)
{
  struct addrinfo *p = NULL;
  struct addrinfo *n = NULL;

  for (p = ptResult; p != NULL;)
    {
	n = WspiapiNewAddrInfo (SOCK_DGRAM, p->ai_protocol, wPort,
				((struct sockaddr_in *) p->ai_addr)->sin_addr.s_addr);
	if (!n)
	  break;
	n->ai_next = p->ai_next;
	p->ai_next = n;
	p = n->ai_next;
    }
  if (p != NULL)
    return EAI_MEMORY;
  return 0;
}
