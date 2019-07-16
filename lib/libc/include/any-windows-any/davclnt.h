/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_DAVCLNT
#define _INC_DAVCLNT

#ifdef __cplusplus
extern "C" {
#endif

#if (_WIN32_WINNT >= 0x0600)
#define DAV_AUTHN_SCHEME_BASIC      0x00000001
#define DAV_AUTHN_SCHEME_NTLM       0x00000002
#define DAV_AUTHN_SCHEME_PASSPORT   0x00000004
#define DAV_AUTHN_SCHEME_DIGEST     0x00000008
#define DAV_AUTHN_SCHEME_NEGOTIATE  0x00000010
#define DAV_AUTHN_SCHEME_CERT       0x00010000
#define DAV_AUTHN_SCHEME_FBA        0x00100000

#define OPAQUE_HANDLE DWORD

typedef enum AUTHNEXTSTEP {
  DefaultBehavior   = 0,
  RetryRequest      = 1,
  CancelRequest     = 2 
} AUTHNEXTSTEP;

typedef struct _DAV_CALLBACK_AUTH_BLOB {
  PVOID pBuffer;
  ULONG ulSize;
  ULONG ulType;
}DAV_CALLBACK_AUTH_BLOB, *PDAV_CALLBACK_AUTH_BLOB;

typedef struct _DAV_CALLBACK_AUTH_UNP {
  LPWSTR pszUserName;
  ULONG  ulUserNameLength;
  LPWSTR pszPassword;
  ULONG  ulPasswordLength;
}DAV_CALLBACK_AUTH_UNP, *PDAV_CALLBACK_AUTH_UNP;

typedef struct _DAV_CALLBACK_CRED {
  DAV_CALLBACK_AUTH_BLOB AuthBlob;
  DAV_CALLBACK_AUTH_UNP  UNPBlob;
  WINBOOL                bAuthBlobValid;
  WINBOOL                bSave;
}DAV_CALLBACK_CRED, *PDAV_CALLBACK_CRED;

typedef DWORD (*PFNDAVAUTHCALLBACK_FREECRED)(
  PVOID pbuffer
);

typedef DWORD (*PFNDAVAUTHCALLBACK)(
  LPWSTR lpwzServerName,
  LPWSTR lpwzRemoteName,
  DWORD dwAuthScheme,
  DWORD dwFlags,
  PDAV_CALLBACK_CRED pCallbackCred,
  AUTHNEXTSTEP *NextStep,
  PFNDAVAUTHCALLBACK_FREECRED *pFreeCred
);

OPAQUE_HANDLE WINAPI DavRegisterAuthCallback(
  PFNDAVAUTHCALLBACK CallBack,
  ULONG Version
);

VOID WINAPI DavUnregisterAuthCallback(
  OPAQUE_HANDLE hCallback
);

DWORD WINAPI DavAddConnection(
  HANDLE *ConnectionHandle,
  LPCWSTR RemoteName,
  LPCWSTR UserName,
  LPCWSTR Password,
  PBYTE ClientCert,
  DWORD CertSize
);

DWORD WINAPI DavCancelConnectionsToServer(
  LPWSTR lpName,
  WINBOOL fForce
);

DWORD WINAPI DavDeleteConnection(
  HANDLE ConnectionHandle
);

DWORD WINAPI DavFlushFile(
  HANDLE hFile
);

DWORD WINAPI DavGetExtendedError(
  HANDLE hFile,
  DWORD *ExtError,
  LPWSTR ExtErrorString,
  DWORD *cChSize
);

DWORD WINAPI DavGetHTTPFromUNCPath(
  LPCWSTR UncPath,
  LPWSTR HttpPath,
  LPDWORD lpSize
);

DWORD WINAPI DavGetTheLockOwnerOfTheFile(
  LPCWSTR FileName,
  PWSTR LockOwnerName,
  PULONG LockOwnerNameLengthInBytes
);

DWORD WINAPI DavGetUNCFromHTTPPath(
  LPCWSTR HttpPath,
  LPWSTR UncPath,
  LPDWORD lpSize
);

DWORD WINAPI DavInvalidateCache(
  LPWSTR URLName
);

OPAQUE_HANDLE WINAPI DavRegisterAuthCallback(
  PFNDAVAUTHCALLBACK CallBack,
  ULONG Version
);

VOID WINAPI DavUnregisterAuthCallback(
  OPAQUE_HANDLE hCallback
);

#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif

#endif /*_INC_DAVCLNT*/
