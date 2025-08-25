/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _HTTPFILT_H_
#define _HTTPFILT_H_

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN64
  __MINGW_EXTENSION typedef unsigned __int64 ULONG_PTR,*PULONG_PTR;
#else
  typedef unsigned long ULONG_PTR,*PULONG_PTR;
#endif

#define HTTP_FILTER_REVISION MAKELONG(0,6)

#define SF_MAX_USERNAME (256+1)
#define SF_MAX_PASSWORD (256+1)
#define SF_MAX_AUTH_TYPE (32+1)

#define SF_MAX_FILTER_DESC_LEN (256+1)

  enum SF_REQ_TYPE {
    SF_REQ_SEND_RESPONSE_HEADER,SF_REQ_ADD_HEADERS_ON_DENIAL,SF_REQ_SET_NEXT_READ_SIZE,SF_REQ_SET_PROXY_INFO,SF_REQ_GET_CONNID,
    SF_REQ_SET_CERTIFICATE_INFO,SF_REQ_GET_PROPERTY,SF_REQ_NORMALIZE_URL,SF_REQ_DISABLE_NOTIFICATIONS
  };

  enum SF_PROPERTY_IIS {
    SF_PROPERTY_SSL_CTXT,SF_PROPERTY_INSTANCE_NUM_ID
  };

  enum SF_STATUS_TYPE {
    SF_STATUS_REQ_FINISHED = 0x8000000,SF_STATUS_REQ_FINISHED_KEEP_CONN,SF_STATUS_REQ_NEXT_NOTIFICATION,SF_STATUS_REQ_HANDLED_NOTIFICATION,
    SF_STATUS_REQ_ERROR,SF_STATUS_REQ_READ_NEXT
  };

  typedef struct _HTTP_FILTER_CONTEXT {
    DWORD cbSize;
    DWORD Revision;
    PVOID ServerContext;
    DWORD ulReserved;
    WINBOOL fIsSecurePort;
    PVOID pFilterContext;
    WINBOOL (WINAPI *GetServerVariable)(struct _HTTP_FILTER_CONTEXT *pfc,LPSTR lpszVariableName,LPVOID lpvBuffer,LPDWORD lpdwSize);
    WINBOOL (WINAPI *AddResponseHeaders)(struct _HTTP_FILTER_CONTEXT *pfc,LPSTR lpszHeaders,DWORD dwReserved);
    WINBOOL (WINAPI *WriteClient)(struct _HTTP_FILTER_CONTEXT *pfc,LPVOID Buffer,LPDWORD lpdwBytes,DWORD dwReserved);
    VOID *(WINAPI *AllocMem)(struct _HTTP_FILTER_CONTEXT *pfc,DWORD cbSize,DWORD dwReserved);
    WINBOOL (WINAPI *ServerSupportFunction)(struct _HTTP_FILTER_CONTEXT *pfc,enum SF_REQ_TYPE sfReq,PVOID pData,ULONG_PTR ul1,ULONG_PTR ul2);
  } HTTP_FILTER_CONTEXT,*PHTTP_FILTER_CONTEXT;

  typedef struct _HTTP_FILTER_RAW_DATA {
    PVOID pvInData;
    DWORD cbInData;
    DWORD cbInBuffer;
    DWORD dwReserved;
  } HTTP_FILTER_RAW_DATA,*PHTTP_FILTER_RAW_DATA;

  typedef struct _HTTP_FILTER_PREPROC_HEADERS {
    WINBOOL (WINAPI *GetHeader)(struct _HTTP_FILTER_CONTEXT *pfc,LPSTR lpszName,LPVOID lpvBuffer,LPDWORD lpdwSize);
    WINBOOL (WINAPI *SetHeader)(struct _HTTP_FILTER_CONTEXT *pfc,LPSTR lpszName,LPSTR lpszValue);
    WINBOOL (WINAPI *AddHeader)(struct _HTTP_FILTER_CONTEXT *pfc,LPSTR lpszName,LPSTR lpszValue);
    DWORD HttpStatus;
    DWORD dwReserved;
  } HTTP_FILTER_PREPROC_HEADERS,*PHTTP_FILTER_PREPROC_HEADERS;

  typedef HTTP_FILTER_PREPROC_HEADERS HTTP_FILTER_SEND_RESPONSE;
  typedef HTTP_FILTER_PREPROC_HEADERS *PHTTP_FILTER_SEND_RESPONSE;

  typedef struct _HTTP_FILTER_AUTHENT {
    CHAR *pszUser;
    DWORD cbUserBuff;
    CHAR *pszPassword;
    DWORD cbPasswordBuff;
  } HTTP_FILTER_AUTHENT,*PHTTP_FILTER_AUTHENT;

  typedef struct _HTTP_FILTER_URL_MAP {
    const CHAR *pszURL;
    CHAR *pszPhysicalPath;
    DWORD cbPathBuff;
  } HTTP_FILTER_URL_MAP,*PHTTP_FILTER_URL_MAP;

  typedef struct _HTTP_FILTER_URL_MAP_EX {
    const CHAR *pszURL;
    CHAR *pszPhysicalPath;
    DWORD cbPathBuff;
    DWORD dwFlags;
    DWORD cchMatchingPath;
    DWORD cchMatchingURL;
    const CHAR *pszScriptMapEntry;
  } HTTP_FILTER_URL_MAP_EX,*PHTTP_FILTER_URL_MAP_EX;

#define SF_DENIED_LOGON 0x00000001
#define SF_DENIED_RESOURCE 0x00000002
#define SF_DENIED_FILTER 0x00000004
#define SF_DENIED_APPLICATION 0x00000008

#define SF_DENIED_BY_CONFIG 0x00010000

  typedef struct _HTTP_FILTER_ACCESS_DENIED {
    const CHAR *pszURL;
    const CHAR *pszPhysicalPath;
    DWORD dwReason;
  } HTTP_FILTER_ACCESS_DENIED,*PHTTP_FILTER_ACCESS_DENIED;

  typedef struct _HTTP_FILTER_LOG {
    const CHAR *pszClientHostName;
    const CHAR *pszClientUserName;
    const CHAR *pszServerName;
    const CHAR *pszOperation;
    const CHAR *pszTarget;
    const CHAR *pszParameters;
    DWORD dwHttpStatus;
    DWORD dwWin32Status;
    DWORD dwBytesSent;
    DWORD dwBytesRecvd;
    DWORD msTimeForProcessing;
  } HTTP_FILTER_LOG,*PHTTP_FILTER_LOG;

  typedef struct _HTTP_FILTER_AUTH_COMPLETE_INFO {
    WINBOOL (WINAPI *GetHeader)(struct _HTTP_FILTER_CONTEXT *pfc,LPSTR lpszName,LPVOID lpvBuffer,LPDWORD lpdwSize);
    WINBOOL (WINAPI *SetHeader)(struct _HTTP_FILTER_CONTEXT *pfc,LPSTR lpszName,LPSTR lpszValue);
    WINBOOL (WINAPI *AddHeader)(struct _HTTP_FILTER_CONTEXT *pfc,LPSTR lpszName,LPSTR lpszValue);
    WINBOOL (WINAPI *GetUserToken)(struct _HTTP_FILTER_CONTEXT *pfc,HANDLE *phToken);
    DWORD HttpStatus;
    WINBOOL fResetAuth;
    DWORD dwReserved;
  } HTTP_FILTER_AUTH_COMPLETE_INFO,*PHTTP_FILTER_AUTH_COMPLETE_INFO;

#define SF_NOTIFY_SECURE_PORT 0x00000001
#define SF_NOTIFY_NONSECURE_PORT 0x00000002

#define SF_NOTIFY_READ_RAW_DATA 0x00008000
#define SF_NOTIFY_PREPROC_HEADERS 0x00004000
#define SF_NOTIFY_AUTHENTICATION 0x00002000
#define SF_NOTIFY_URL_MAP 0x00001000
#define SF_NOTIFY_ACCESS_DENIED 0x00000800
#define SF_NOTIFY_SEND_RESPONSE 0x00000040
#define SF_NOTIFY_SEND_RAW_DATA 0x00000400
#define SF_NOTIFY_LOG 0x00000200
#define SF_NOTIFY_END_OF_REQUEST 0x00000080
#define SF_NOTIFY_END_OF_NET_SESSION 0x00000100
#define SF_NOTIFY_AUTH_COMPLETE 0x04000000

#define SF_NOTIFY_ORDER_HIGH 0x00080000
#define SF_NOTIFY_ORDER_MEDIUM 0x00040000
#define SF_NOTIFY_ORDER_LOW 0x00020000
#define SF_NOTIFY_ORDER_DEFAULT SF_NOTIFY_ORDER_LOW

#define SF_NOTIFY_ORDER_MASK (SF_NOTIFY_ORDER_HIGH | SF_NOTIFY_ORDER_MEDIUM | SF_NOTIFY_ORDER_LOW)

  typedef struct _HTTP_FILTER_VERSION {
    DWORD dwServerFilterVersion;
    DWORD dwFilterVersion;
    CHAR lpszFilterDesc[SF_MAX_FILTER_DESC_LEN];
    DWORD dwFlags;
  } HTTP_FILTER_VERSION,*PHTTP_FILTER_VERSION;

  DWORD WINAPI HttpFilterProc(HTTP_FILTER_CONTEXT *pfc,DWORD NotificationType,VOID *pvNotification);
  WINBOOL WINAPI GetFilterVersion(HTTP_FILTER_VERSION *pVer);
  WINBOOL WINAPI TerminateFilter(DWORD dwFlags);

#ifdef __cplusplus
}
#endif
#endif
