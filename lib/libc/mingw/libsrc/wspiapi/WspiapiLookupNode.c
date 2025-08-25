#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

int WINAPI
WspiapiLookupNode (const char *pszNodeName,
		   int iSocketType, int iProtocol,
		   WORD wPort, WINBOOL bAI_CANONNAME,
		   struct addrinfo **pptResult)
{
  int err = 0, cntAlias = 0;
  char name[NI_MAXHOST] = "";
  char alias[NI_MAXHOST] = "";
  char *pname = name, *palias = alias, *tmp = NULL;

  strncpy (pname, pszNodeName, NI_MAXHOST - 1);
  pname[NI_MAXHOST - 1] = 0;
  for (;;)
    {
	err = WspiapiQueryDNS (pszNodeName, iSocketType, iProtocol, wPort, palias, pptResult);
	if (err)
	  break;
	if (*pptResult)
	  break;
	++cntAlias;
	if (strlen (palias) == 0 || !strcmp (pname, palias) || cntAlias == 16)
	  {
	    err = EAI_FAIL;
	    break;
	  }
	WspiapiSwap(pname, palias, tmp);
    }
  if (!err && bAI_CANONNAME)
    {
      (*pptResult)->ai_canonname = WspiapiStrdup (palias);
      if (!(*pptResult)->ai_canonname)
	  err = EAI_MEMORY;
    }
  return err;
}
