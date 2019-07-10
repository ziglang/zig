/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __SPORDER_H__
#define __SPORDER_H__

#ifdef __cplusplus
extern "C" {
#endif

  typedef int (WSPAPI *LPWSCWRITEPROVIDERORDER)(LPDWORD lpwdCatalogEntryId,DWORD dwNumberOfEntries);
  typedef int (WSPAPI *LPWSCWRITENAMESPACEORDER)(LPGUID lpProviderId,DWORD dwNumberOfEntries);

  int WSPAPI WSCWriteProviderOrder(LPDWORD lpwdCatalogEntryId,DWORD dwNumberOfEntries);
  int WSPAPI WSCWriteNameSpaceOrder(LPGUID lpProviderId,DWORD dwNumberOfEntries);
#ifdef _WIN64
  int WSPAPI WSCWriteProviderOrder32(LPDWORD lpwdCatalogEntryId,DWORD dwNumberOfEntries);
  int WSPAPI WSCWriteNameSpaceOrder32(LPGUID lpProviderId,DWORD dwNumberOfEntries);
#endif

#ifdef __cplusplus
}
#endif
#endif
