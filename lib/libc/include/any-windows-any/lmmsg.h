/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _LMMSG_
#define _LMMSG_

#ifdef __cplusplus
extern "C" {
#endif

  NET_API_STATUS WINAPI NetMessageNameAdd(LPCWSTR servername,LPCWSTR msgname);
  NET_API_STATUS WINAPI NetMessageNameEnum(LPCWSTR servername,DWORD level,LPBYTE *bufptr,DWORD prefmaxlen,LPDWORD entriesread,LPDWORD totalentries,LPDWORD resume_handle);
  NET_API_STATUS WINAPI NetMessageNameGetInfo(LPCWSTR servername,LPCWSTR msgname,DWORD level,LPBYTE *bufptr);
  NET_API_STATUS WINAPI NetMessageNameDel(LPCWSTR servername,LPCWSTR msgname);
  NET_API_STATUS WINAPI NetMessageBufferSend(LPCWSTR servername,LPCWSTR msgname,LPCWSTR fromname,LPBYTE buf,DWORD buflen);

  typedef struct _MSG_INFO_0 {
    LPWSTR msgi0_name;
  } MSG_INFO_0,*PMSG_INFO_0,*LPMSG_INFO_0;

  typedef struct _MSG_INFO_1 {
    LPWSTR msgi1_name;
    DWORD msgi1_forward_flag;
    LPWSTR msgi1_forward;
  } MSG_INFO_1,*PMSG_INFO_1,*LPMSG_INFO_1;

#define MSGNAME_NOT_FORWARDED 0
#define MSGNAME_FORWARDED_TO 0x04
#define MSGNAME_FORWARDED_FROM 0x10

#ifdef __cplusplus
}
#endif
#endif
