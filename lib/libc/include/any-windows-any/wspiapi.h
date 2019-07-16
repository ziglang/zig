/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WSPIAPI_H_
#define _WSPIAPI_H_

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <string.h>
#include <ws2tcpip.h>

#include <_mingw_print_push.h>

#define _WSPIAPI_STRCPY_S(_Dst,_Size,_Src) strcpy((_Dst),(_Src))
#define _WSPIAPI_STRCAT_S(_Dst,_Size,_Src) strcat((_Dst),(_Src))
#define _WSPIAPI_STRNCPY_S(_Dst,_Size,_Src,_Count) strncpy((_Dst),(_Src),(_Count)); (_Dst)[(_Size) - 1] = 0
#define _WSPIAPI_SPRINTF_S_1(_Dst,_Size,_Format,_Arg1) sprintf((_Dst),(_Format),(_Arg1))

#ifndef _WSPIAPI_COUNTOF
#ifndef __cplusplus
#define _WSPIAPI_COUNTOF(_Array) (sizeof(_Array) / sizeof(_Array[0]))
#else
template <typename __CountofType,size_t __wspiapi_countof_helper_N> char (&__wspiapi_countof_helper(__CountofType (&_Array)[__wspiapi_countof_helper_N]))[__wspiapi_countof_helper_N];
#define _WSPIAPI_COUNTOF(_Array) sizeof(__wspiapi_countof_helper(_Array))
#endif
#endif

#define WspiapiMalloc(tSize) calloc(1,(tSize))
#define WspiapiFree(p) free(p)
#define WspiapiSwap(a,b,c) { (c) = (a); (a) = (b); (b) = (c); }
#define getaddrinfo WspiapiGetAddrInfo
#define getnameinfo WspiapiGetNameInfo
#define freeaddrinfo WspiapiFreeAddrInfo

typedef int (WINAPI *WSPIAPI_PGETADDRINFO)(const char *nodename,const char *servname,const struct addrinfo *hints,struct addrinfo **res);
typedef int (WINAPI *WSPIAPI_PGETNAMEINFO)(const struct sockaddr *sa,socklen_t salen,char *host,size_t hostlen,char *serv,size_t servlen,int flags);
typedef void (WINAPI *WSPIAPI_PFREEADDRINFO)(struct addrinfo *ai);

#ifdef __cplusplus
extern "C" {
#endif
  typedef struct {
    char const *pszName;
    FARPROC pfAddress;
  } WSPIAPI_FUNCTION;

#define WSPIAPI_FUNCTION_ARRAY { { "getaddrinfo",(FARPROC) WspiapiLegacyGetAddrInfo }, \
  { "getnameinfo",(FARPROC) WspiapiLegacyGetNameInfo }, \
  { "freeaddrinfo",(FARPROC) WspiapiLegacyFreeAddrInfo } }

  char *WINAPI WspiapiStrdup (const char *pszString);
  WINBOOL WINAPI WspiapiParseV4Address (const char *pszAddress,PDWORD pdwAddress);
  struct addrinfo * WINAPI WspiapiNewAddrInfo (int iSocketType,int iProtocol,WORD wPort,DWORD dwAddress);
  int WINAPI WspiapiQueryDNS (const char *pszNodeName,int iSocketType,int iProtocol,WORD wPort,char pszAlias[NI_MAXHOST],struct addrinfo **pptResult);
  int WINAPI WspiapiLookupNode (const char *pszNodeName,int iSocketType,int iProtocol,WORD wPort,WINBOOL bAI_CANONNAME,struct addrinfo **pptResult);
  int WINAPI WspiapiClone (WORD wPort,struct addrinfo *ptResult);
  void WINAPI WspiapiLegacyFreeAddrInfo (struct addrinfo *ptHead);
  int WINAPI WspiapiLegacyGetAddrInfo(const char *pszNodeName,const char *pszServiceName,const struct addrinfo *ptHints,struct addrinfo **pptResult);
  int WINAPI WspiapiLegacyGetNameInfo(const struct sockaddr *ptSocketAddress,socklen_t tSocketLength,char *pszNodeName,size_t tNodeLength,char *pszServiceName,size_t tServiceLength,int iFlags);
  FARPROC WINAPI WspiapiLoad(WORD wFunction);
  int WINAPI WspiapiGetAddrInfo(const char *nodename,const char *servname,const struct addrinfo *hints,struct addrinfo **res);
  int WINAPI WspiapiGetNameInfo (const struct sockaddr *sa,socklen_t salen,char *host,size_t hostlen,char *serv,size_t servlen,int flags);
  void WINAPI WspiapiFreeAddrInfo (struct addrinfo *ai);

#ifndef __CRT__NO_INLINE
  __CRT_INLINE char * WINAPI
  WspiapiStrdup (const char *pszString)
  {
    char *rstr;
    size_t szlen;

    if(!pszString)
      return NULL;
    szlen = strlen(pszString) + 1;
    rstr = (char *) WspiapiMalloc (szlen);
    if (!rstr)
      return NULL;
    strcpy (rstr, pszString);
    return rstr;
  }

  __CRT_INLINE WINBOOL WINAPI
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

  __CRT_INLINE struct addrinfo * WINAPI
  WspiapiNewAddrInfo (int iSocketType,int iProtocol, WORD wPort,DWORD dwAddress)
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

  __CRT_INLINE int WINAPI
  WspiapiLookupNode (const char *pszNodeName, int iSocketType, int iProtocol, WORD wPort,
		     WINBOOL bAI_CANONNAME, struct addrinfo **pptResult)
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

  __CRT_INLINE int WINAPI
  WspiapiClone (WORD wPort,struct addrinfo *ptResult)
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

  __CRT_INLINE void WINAPI
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
#endif /* !__CRT__NO_INLINE */

#ifdef __cplusplus
}
#endif

#include <_mingw_print_pop.h>

#endif
