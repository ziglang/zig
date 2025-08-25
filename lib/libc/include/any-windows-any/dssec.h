/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_DSSEC
#define _INC_DSSEC
#include <aclui.h>
#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

typedef HRESULT (WINAPI *PFNREADOBJECTSECURITY)(
    LPCWSTR,               // Active Directory path of object
    SECURITY_INFORMATION,  // the security information to read
    PSECURITY_DESCRIPTOR*, // the returned security descriptor 
    LPARAM                 // context parameter
);

typedef HRESULT (WINAPI *PFNWRITEOBJECTSECURITY)(
    LPCWSTR,              // Active Directory path of object
    SECURITY_INFORMATION, // the security information to write
    PSECURITY_DESCRIPTOR, // the security descriptor to write
    LPARAM                // context parameter
);

#define DSSI_READ_ONLY 0x00000001
#define DSSI_NO_ACCESS_CHECK  0x00000002
#define DSSI_NO_EDIT_SACL  0x00000004
#define DSSI_NO_EDIT_OWNER  0x00000008
#define DSSI_IS_ROOT  0x00000010
#define DSSI_NO_FILTER  0x00000020
#define DSSI_NO_READONLY_MESSAGE  0x00000040

HRESULT WINAPI DSCreateISecurityInfoObject(
  LPCWSTR pwszObjectPath,
  LPCWSTR pwszObjectClass,
  DWORD dwFlags,
  LPSECURITYINFO *ppSI,
  PFNREADOBJECTSECURITY pfnReadSD,
  PFNWRITEOBJECTSECURITY pfnWriteSD,
  LPARAM lpContext
);

HRESULT WINAPI DSCreateISecurityInfoObjectEx(
  LPCWSTR pwszObjectPath,
  LPCWSTR pwszObjectClass,
  LPCWSTR pwszServer,
  LPCWSTR pwszUserName,
  LPCWSTR pwszPassword,
  DWORD dwFlags,
  LPSECURITYINFO *ppSI,
  PFNREADOBJECTSECURITY pfnReadSD,
  PFNWRITEOBJECTSECURITY pfnWriteSD,
  LPARAM lpContext
);

HRESULT WINAPI DSEditSecurity(
  HWND hwndOwner,
  LPCWSTR pwszObjectPath,
  LPCWSTR pwszObjectClass,
  DWORD dwFlags,
  LPCWSTR *pwszCaption,
  PFNREADOBJECTSECURITY pfnReadSD,
  PFNWRITEOBJECTSECURITY pfnWriteSD,
  LPARAM lpContext
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_DSSEC*/
