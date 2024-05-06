#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

int WINAPI
WspiapiLegacyGetNameInfo (const struct sockaddr *ptSocketAddress,
			 socklen_t tSocketLength,
			 char *pszNodeName, size_t tNodeLength,
			 char *pszServiceName, size_t tServiceLength,
			 int iFlags)
{
  struct servent *svc;
  WORD port;
  char str[] = "65535";
  char *pstr = str;
  struct hostent *phost;
  struct in_addr l_inaddr;
  char *pnode = NULL, *pc = NULL;

  if (!ptSocketAddress || tSocketLength < (int) sizeof (struct sockaddr))
    return EAI_FAIL;
  if (ptSocketAddress->sa_family != AF_INET)
    return EAI_FAMILY;
  if (tSocketLength < (int) sizeof (struct sockaddr_in))
    return EAI_FAIL;
  if (!(pszNodeName && tNodeLength) && !(pszServiceName && tServiceLength))
    return EAI_NONAME;
  if ((iFlags & NI_NUMERICHOST) != 0 && (iFlags & NI_NAMEREQD) != 0)
    return EAI_BADFLAGS;
  if (pszServiceName && tServiceLength)
    {
	port = ((struct sockaddr_in *) ptSocketAddress)->sin_port;
	if (iFlags & NI_NUMERICSERV)
	  sprintf (str, "%u", ntohs (port));
      else
	  {
	    svc = getservbyport(port, (iFlags & NI_DGRAM) ? "udp" : NULL);
	    if (svc && svc->s_name)
	      pstr = svc->s_name;
	    else
	      sprintf (str, "%u", ntohs (port));
	  }
	if (tServiceLength > strlen (pstr))
	  strcpy (pszServiceName, pstr);
	else
	  return EAI_FAIL;
    }
  if (pszNodeName && tNodeLength)
    {
	l_inaddr = ((struct sockaddr_in *) ptSocketAddress)->sin_addr;
	if (iFlags & NI_NUMERICHOST)
	  pnode = inet_ntoa (l_inaddr);
	else
	  {
	    phost = gethostbyaddr ((char *) &l_inaddr, sizeof (struct in_addr), AF_INET);
	    if (phost && phost->h_name)
	      {
		pnode = phost->h_name;
		if ((iFlags & NI_NOFQDN) != 0 && ((pc = strchr (pnode,'.')) != NULL))
		  *pc = 0;
	      }
	    else
	      {
		if ((iFlags & NI_NAMEREQD) != 0)
		  {
		    switch(WSAGetLastError())
		      {
		      case WSAHOST_NOT_FOUND: return EAI_NONAME;
		      case WSATRY_AGAIN: return EAI_AGAIN;
		      case WSANO_RECOVERY: return EAI_FAIL;
		      default: return EAI_NONAME;
		      }
		  }
		else
		  pnode = inet_ntoa (l_inaddr);
	      }
	  }
	if (tNodeLength > strlen (pnode))
	  strcpy (pszNodeName, pnode);
	else
	  return EAI_FAIL;
    }
  return 0;
}
