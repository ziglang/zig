#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

int WINAPI
WspiapiQueryDNS(const char *pszNodeName,
		int iSocketType, int iProtocol,
		WORD wPort, char pszAlias[NI_MAXHOST],
		struct addrinfo **pptResult)
{
  struct addrinfo **paddrinfo = pptResult;
  struct hostent *phost = NULL;
  char **h;

  *paddrinfo = NULL;
  pszAlias[0] = 0;
  phost = gethostbyname (pszNodeName);
  if (phost)
    {
      if (phost->h_addrtype == AF_INET && phost->h_length == sizeof(struct in_addr))
	  {
	    for (h = phost->h_addr_list; *h != NULL; h++)
	      {
		*paddrinfo = WspiapiNewAddrInfo (iSocketType, iProtocol, wPort,
						 ((struct in_addr *) *h)->s_addr);
		if (!*paddrinfo)
		  return EAI_MEMORY;
		paddrinfo = &((*paddrinfo)->ai_next);
	      }
	  }
	strncpy (pszAlias, phost->h_name, NI_MAXHOST - 1);
	pszAlias[NI_MAXHOST - 1] = 0;
	return 0;
    }
  switch(WSAGetLastError())
    {
    case WSAHOST_NOT_FOUND: break;
    case WSATRY_AGAIN: return EAI_AGAIN;
    case WSANO_RECOVERY: return EAI_FAIL;
    case WSANO_DATA: return EAI_NODATA;
    default: break;
    }
  return EAI_NONAME;
}
