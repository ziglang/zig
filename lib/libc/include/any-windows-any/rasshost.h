/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _RASSHOST_
#define _RASSHOST_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <mprapi.h>

typedef HANDLE HPORT;

typedef struct _SECURITY_MESSAGE {
  DWORD dwMsgId;
  HPORT hPort;
  DWORD dwError;
  CHAR UserName[UNLEN+1];
  CHAR Domain[DNLEN+1];
} SECURITY_MESSAGE,*PSECURITY_MESSAGE;

#define SECURITYMSG_SUCCESS 1
#define SECURITYMSG_FAILURE 2
#define SECURITYMSG_ERROR 3

typedef struct _RAS_SECURITY_INFO {
  DWORD LastError;
  DWORD BytesReceived;
  CHAR DeviceName[MAX_DEVICE_NAME+1];
} RAS_SECURITY_INFO,*PRAS_SECURITY_INFO;

typedef DWORD (WINAPI *RASSECURITYPROC)();

VOID WINAPI RasSecurityDialogComplete(SECURITY_MESSAGE *pSecMsg);
DWORD WINAPI RasSecurityDialogBegin(HPORT hPort,PBYTE pSendBuf,DWORD SendBufSize,PBYTE pRecvBuf,DWORD RecvBufSize,VOID (WINAPI *RasSecurityDialogComplete)(SECURITY_MESSAGE *));
DWORD WINAPI RasSecurityDialogEnd(HPORT hPort);
DWORD WINAPI RasSecurityDialogSend(HPORT hPort,PBYTE pBuffer,WORD BufferLength);
DWORD WINAPI RasSecurityDialogReceive(HPORT hPort,PBYTE pBuffer,PWORD pBufferLength,DWORD Timeout,HANDLE hEvent);
DWORD WINAPI RasSecurityDialogGetInfo(HPORT hPort,RAS_SECURITY_INFO *pBuffer);

#endif
#endif
