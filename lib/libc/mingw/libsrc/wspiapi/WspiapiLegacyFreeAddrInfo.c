#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

void WINAPI
WspiapiLegacyFreeAddrInfo (struct addrinfo *ptHead)
{
  struct addrinfo *p;

  for (p = ptHead; p != NULL; p = ptHead)
    {
	if (p->ai_canonname)
	  WspiapiFree (p->ai_canonname);
	if (p->ai_addr)
	  WspiapiFree (p->ai_addr);
	ptHead = p->ai_next;
	WspiapiFree (p);
    }
}
