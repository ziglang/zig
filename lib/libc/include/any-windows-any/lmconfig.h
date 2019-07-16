/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _LMCONFIG_
#define _LMCONFIG_

#ifdef __cplusplus
extern "C" {
#endif

#define REVISED_CONFIG_APIS

  NET_API_STATUS WINAPI NetConfigGet(LPCWSTR server,LPCWSTR component,LPCWSTR parameter,LPBYTE *bufptr);
  NET_API_STATUS WINAPI NetConfigGetAll(LPCWSTR server,LPCWSTR component,LPBYTE *bufptr);
  NET_API_STATUS WINAPI NetConfigSet(LPCWSTR server,LPCWSTR reserved1,LPCWSTR component,DWORD level,DWORD reserved2,LPBYTE buf,DWORD reserved3);
  NET_API_STATUS WINAPI NetRegisterDomainNameChangeNotification(PHANDLE NotificationEventHandle);
  NET_API_STATUS WINAPI NetUnregisterDomainNameChangeNotification(HANDLE NotificationEventHandle);

  typedef struct _CONFIG_INFO_0 {
    LPWSTR cfgi0_key;
    LPWSTR cfgi0_data;
  } CONFIG_INFO_0,*PCONFIG_INFO_0,*LPCONFIG_INFO_0;

#ifdef __cplusplus
}
#endif
#endif
