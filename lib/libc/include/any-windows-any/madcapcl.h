/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MADCAPCL_H_
#define _MADCAPCL_H_

#include <winternl.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <time.h>

#define MCAST_CLIENT_ID_LEN 17

  enum {
    MCAST_API_VERSION_0 = 0,MCAST_API_VERSION_1
  };

#define MCAST_API_CURRENT_VERSION MCAST_API_VERSION_1

  typedef unsigned short IP_ADDR_FAMILY;

  typedef union _IPNG_ADDRESS {
    DWORD IpAddrV4;
    BYTE IpAddrV6[16];
  } IPNG_ADDRESS,*PIPNG_ADDRESS;

  typedef struct _MCAST_CLIENT_UID {
    LPBYTE ClientUID;
    DWORD ClientUIDLength;
  } MCAST_CLIENT_UID,*LPMCAST_CLIENT_UID;

  typedef struct _MCAST_SCOPE_CTX {
    IPNG_ADDRESS ScopeID;
    IPNG_ADDRESS Interface;
    IPNG_ADDRESS ServerID;
  } MCAST_SCOPE_CTX,*PMCAST_SCOPE_CTX;

  typedef struct _MCAST_SCOPE_ENTRY {
    MCAST_SCOPE_CTX ScopeCtx;
    IPNG_ADDRESS LastAddr;
    DWORD TTL;
    UNICODE_STRING ScopeDesc;
  } MCAST_SCOPE_ENTRY,*PMCAST_SCOPE_ENTRY;

  typedef struct _MCAST_LEASE_REQUEST {
    LONG LeaseStartTime;
    LONG MaxLeaseStartTime;
    DWORD LeaseDuration;
    DWORD MinLeaseDuration;
    IPNG_ADDRESS ServerAddress;
    WORD MinAddrCount;
    WORD AddrCount;
    PBYTE pAddrBuf;
  } MCAST_LEASE_REQUEST,*PMCAST_LEASE_REQUEST;

  typedef struct _MCAST_LEASE_RESPONSE {
    LONG LeaseStartTime;
    LONG LeaseEndTime;
    IPNG_ADDRESS ServerAddress;
    WORD AddrCount;
    PBYTE pAddrBuf;
  } MCAST_LEASE_RESPONSE,*PMCAST_LEASE_RESPONSE;

  DWORD WINAPI McastApiStartup(PDWORD Version);
  VOID WINAPI McastApiCleanup(VOID);
  DWORD WINAPI McastGenUID(LPMCAST_CLIENT_UID pRequestID);
  DWORD WINAPI McastEnumerateScopes(IP_ADDR_FAMILY AddrFamily,WINBOOL ReQuery,PMCAST_SCOPE_ENTRY pScopeList,PDWORD pScopeLen,PDWORD pScopeCount);
  DWORD WINAPI McastRequestAddress(IP_ADDR_FAMILY AddrFamily,LPMCAST_CLIENT_UID pRequestID,PMCAST_SCOPE_CTX pScopeCtx,PMCAST_LEASE_REQUEST pAddrRequest,PMCAST_LEASE_RESPONSE pAddrResponse);
  DWORD WINAPI McastRenewAddress(IP_ADDR_FAMILY AddrFamily,LPMCAST_CLIENT_UID pRequestID,PMCAST_LEASE_REQUEST pRenewRequest,PMCAST_LEASE_RESPONSE pRenewResponse);
  DWORD WINAPI McastReleaseAddress(IP_ADDR_FAMILY AddrFamily,LPMCAST_CLIENT_UID pRequestID,PMCAST_LEASE_REQUEST pReleaseRequest);

#ifdef __cplusplus
}
#endif
#endif
