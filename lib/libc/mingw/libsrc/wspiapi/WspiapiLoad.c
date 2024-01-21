#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <wspiapi.h>

FARPROC WINAPI
WspiapiLoad (WORD wFunction)
{
  static WINBOOL isinit = FALSE;
  static WSPIAPI_FUNCTION rgtGlobal[] = WSPIAPI_FUNCTION_ARRAY;
  static const int iNumGlobal = (sizeof(rgtGlobal) / sizeof(WSPIAPI_FUNCTION));
  HMODULE hlib = NULL;
  WSPIAPI_FUNCTION rgtLocal[] = WSPIAPI_FUNCTION_ARRAY;
  FARPROC fScratch = NULL;
  int i = 0;

  if (isinit)
    return rgtGlobal[wFunction].pfAddress;

  for (;;)
    {
	CHAR systemdir[MAX_PATH + 1], path[MAX_PATH + 8];

	if (GetSystemDirectoryA (systemdir, MAX_PATH) == 0)
	  break;
	strcpy (path, systemdir);
	strcat (path, "\\ws2_32");
	hlib = LoadLibraryA (path);
	if(hlib != NULL)
	  {
	    fScratch = GetProcAddress (hlib, "getaddrinfo");
	    if (!fScratch)
	      {
		FreeLibrary (hlib);
		hlib = NULL;
	      }
	  }
	if (hlib != NULL)
	  break;
	strcpy (path, systemdir);
	strcat (path, "\\wship6");
	hlib = LoadLibraryA (path);
	if (hlib != NULL)
	  {
	    if ((fScratch = GetProcAddress (hlib, "getaddrinfo")) == NULL)
	      {
		FreeLibrary (hlib);
		hlib = NULL;
	      }
	  }
	break;
    }
  if (hlib != NULL)
    {
	for (i = 0; i < iNumGlobal; i++)
	  {
	    if ((rgtLocal[i].pfAddress = GetProcAddress (hlib, rgtLocal[i].pszName)) == NULL)
	      {
		FreeLibrary (hlib);
		hlib = NULL;
		break;
	      }
	  }
	if (hlib != NULL)
	  {
	    for (i = 0; i < iNumGlobal; i++)
	      rgtGlobal[i].pfAddress = rgtLocal[i].pfAddress;
	  }
    }
  isinit = TRUE;
  return rgtGlobal[wFunction].pfAddress;
}
