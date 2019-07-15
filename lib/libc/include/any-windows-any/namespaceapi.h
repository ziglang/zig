/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _APISETNAMESPACE_
#define _APISETNAMESPACE_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#define PRIVATE_NAMESPACE_FLAG_DESTROY 0x1

  WINBASEAPI HANDLE WINAPI CreatePrivateNamespaceW (LPSECURITY_ATTRIBUTES lpPrivateNamespaceAttributes, LPVOID lpBoundaryDescriptor, LPCWSTR lpAliasPrefix);
  WINBASEAPI HANDLE WINAPI OpenPrivateNamespaceW (LPVOID lpBoundaryDescriptor, LPCWSTR lpAliasPrefix);
#ifdef UNICODE
#define CreatePrivateNamespace CreatePrivateNamespaceW
#endif

  WINBASEAPI BOOLEAN WINAPI ClosePrivateNamespace (HANDLE Handle, ULONG Flags);
  WINBASEAPI HANDLE WINAPI CreateBoundaryDescriptorW (LPCWSTR Name, ULONG Flags);
#ifdef UNICODE
#define CreateBoundaryDescriptor CreateBoundaryDescriptorW
#endif

  WINBASEAPI WINBOOL WINAPI AddSIDToBoundaryDescriptor (HANDLE *BoundaryDescriptor, PSID RequiredSid);
  WINBASEAPI VOID WINAPI DeleteBoundaryDescriptor (HANDLE BoundaryDescriptor);
#endif

#ifdef __cplusplus
}
#endif
#endif
