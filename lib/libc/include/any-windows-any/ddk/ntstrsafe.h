/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _NTSTRSAFE_H_INCLUDED_
#define _NTSTRSAFE_H_INCLUDED_

#include <_mingw_unicode.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <specstrings.h>

#if defined(__CRT__NO_INLINE) && !defined(__CRT_STRSAFE_IMPL)
#define __STRSAFE__NO_INLINE
#endif

#ifndef _SIZE_T_DEFINED
#define _SIZE_T_DEFINED
#undef size_t
#ifdef _WIN64
__MINGW_EXTENSION typedef unsigned __int64 size_t;
#else
typedef unsigned int size_t;
#endif
#endif

#ifndef _WCHAR_T_DEFINED
#define _WCHAR_T_DEFINED
typedef unsigned short wchar_t;
#endif

#ifndef _NTSTATUS_DEFINED
#define _NTSTATUS_DEFINED
typedef __LONG32 NTSTATUS;
#endif

#ifndef C_ASSERT
#ifdef _MSC_VER
# define C_ASSERT(e) typedef char __C_ASSERT__[(e)?1:-1]
#else
# define C_ASSERT(e) extern void __C_ASSERT__(int [(e)?1:-1])
#endif
#endif /* C_ASSERT */

/* extern removed for C mode to avoid double extern qualifier from __CRT_INLINE */
#ifdef __cplusplus
#define _STRSAFE_EXTERN_C extern "C"
#else
#define _STRSAFE_EXTERN_C extern
#endif

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

#if !defined(__CRT__NO_INLINE) && !defined(__CRT_STRSAFE_IMPL)
#define NTSTRSAFEDDI _STRSAFE_EXTERN_C __inline NTSTATUS WINAPI
/* Variadic functions can't be __stdcall.  */
#define NTSTRSAFEDDIV _STRSAFE_EXTERN_C __inline NTSTATUS
#else
#define NTSTRSAFEDDI _STRSAFE_EXTERN_C NTSTATUS WINAPI
/* Variadic functions can't be __stdcall.  */
#define NTSTRSAFEDDIV _STRSAFE_EXTERN_C NTSTATUS
#endif

#define NTSTRSAFE_MAX_CCH 2147483647

#define STRSAFE_IGNORE_NULLS 0x00000100
#define STRSAFE_FILL_BEHIND_NULL 0x00000200
#define STRSAFE_FILL_ON_FAILURE 0x00000400
#define STRSAFE_NULL_ON_FAILURE 0x00000800
#define STRSAFE_NO_TRUNCATION 0x00001000
#define STRSAFE_IGNORE_NULL_UNICODE_STRINGS 0x00010000
#define STRSAFE_UNICODE_STRING_DEST_NULL_TERMINATED 0x00020000

#define STRSAFE_VALID_FLAGS (0x000000FF | STRSAFE_IGNORE_NULLS | STRSAFE_FILL_BEHIND_NULL | STRSAFE_FILL_ON_FAILURE | STRSAFE_NULL_ON_FAILURE | STRSAFE_NO_TRUNCATION)
#define STRSAFE_UNICODE_STRING_VALID_FLAGS (STRSAFE_VALID_FLAGS | STRSAFE_IGNORE_NULL_UNICODE_STRINGS | STRSAFE_UNICODE_STRING_DEST_NULL_TERMINATED)

#define STRSAFE_FILL_BYTE(x) ((unsigned __LONG32)((x & 0x000000FF) | STRSAFE_FILL_BEHIND_NULL))
#define STRSAFE_FAILURE_BYTE(x) ((unsigned __LONG32)((x & 0x000000FF) | STRSAFE_FILL_ON_FAILURE))

#define STRSAFE_GET_FILL_PATTERN(dwFlags) ((int)(dwFlags & 0x000000FF))

typedef char *NTSTRSAFE_PSTR;
typedef const char *NTSTRSAFE_PCSTR;
typedef wchar_t *NTSTRSAFE_PWSTR;
typedef const wchar_t *NTSTRSAFE_PCWSTR;

NTSTRSAFEDDI RtlStringCopyWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc);
NTSTRSAFEDDI RtlStringCopyWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc);
NTSTRSAFEDDI RtlStringCopyExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCopyExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCopyNWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToCopy);
NTSTRSAFEDDI RtlStringCopyNWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToCopy);
NTSTRSAFEDDI RtlStringCopyNExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToCopy,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCopyNExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToCopy,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCatWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc);
NTSTRSAFEDDI RtlStringCatWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc);
NTSTRSAFEDDI RtlStringCatExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCatExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCatNWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToAppend);
NTSTRSAFEDDI RtlStringCatNWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToAppend);
NTSTRSAFEDDI RtlStringCatNExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToAppend,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCatNExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToAppend,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringVPrintfWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszFormat,va_list argList);
NTSTRSAFEDDI RtlStringVPrintfWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszFormat,va_list argList);
NTSTRSAFEDDI RtlStringVPrintfExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,va_list argList);
NTSTRSAFEDDI RtlStringVPrintfExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,va_list argList);
NTSTRSAFEDDI RtlStringLengthWorkerA(NTSTRSAFE_PCSTR psz,size_t cchMax,size_t *pcchLength);
NTSTRSAFEDDI RtlStringLengthWorkerW(NTSTRSAFE_PCWSTR psz,size_t cchMax,size_t *pcchLength);

#define RtlStringCchCopy __MINGW_NAME_AW(RtlStringCchCopy)

NTSTRSAFEDDI RtlStringCchCopyA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc);
NTSTRSAFEDDI RtlStringCchCopyW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc);

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchCopyA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc) {
  return (cchDest > NTSTRSAFE_MAX_CCH ? STATUS_INVALID_PARAMETER : RtlStringCopyWorkerA(pszDest,cchDest,pszSrc));
}

NTSTRSAFEDDI RtlStringCchCopyW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCopyWorkerW(pszDest,cchDest,pszSrc);
}
#endif /* !__STRSAFE__NO_INLINE */

#define RtlStringCbCopy __MINGW_NAME_AW(RtlStringCbCopy)

NTSTRSAFEDDI RtlStringCbCopyA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc);
NTSTRSAFEDDI RtlStringCbCopyW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc);

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbCopyA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc) {
  if(cbDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCopyWorkerA(pszDest,cbDest,pszSrc);
}

NTSTRSAFEDDI RtlStringCbCopyW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc) {
  size_t cchDest = cbDest / sizeof(wchar_t);
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCopyWorkerW(pszDest,cchDest,pszSrc);
}
#endif /* !__STRSAFE__NO_INLINE */

#define RtlStringCchCopyEx __MINGW_NAME_AW(RtlStringCchCopyEx)

NTSTRSAFEDDI RtlStringCchCopyExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCchCopyExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchCopyExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCopyExWorkerA(pszDest,cchDest,cchDest,pszSrc,ppszDestEnd,pcchRemaining,dwFlags);
}

NTSTRSAFEDDI RtlStringCchCopyExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  size_t cbDest;
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  cbDest = cchDest * sizeof(wchar_t);
  return RtlStringCopyExWorkerW(pszDest,cchDest,cbDest,pszSrc,ppszDestEnd,pcchRemaining,dwFlags);
}
#endif /* !__STRSAFE__NO_INLINE */

#define RtlStringCbCopyEx __MINGW_NAME_AW(RtlStringCbCopyEx)

NTSTRSAFEDDI RtlStringCbCopyExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCbCopyExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags);

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbCopyExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr;
  size_t cchRemaining = 0;
  if(cbDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  hr = RtlStringCopyExWorkerA(pszDest,cbDest,cbDest,pszSrc,ppszDestEnd,&cchRemaining,dwFlags);
  if(NT_SUCCESS(hr) || hr == STATUS_BUFFER_OVERFLOW) {
    if(pcbRemaining)
      *pcbRemaining = (cchRemaining*sizeof(char)) + (cbDest % sizeof(char));
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCbCopyExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr;
  size_t cchDest = cbDest / sizeof(wchar_t);
  size_t cchRemaining = 0;

  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  hr = RtlStringCopyExWorkerW(pszDest,cchDest,cbDest,pszSrc,ppszDestEnd,&cchRemaining,dwFlags);
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(pcbRemaining)
      *pcbRemaining = (cchRemaining*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t));
  }
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCchCopyNA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToCopy);
NTSTRSAFEDDI RtlStringCchCopyNW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToCopy);
#define RtlStringCchCopyN __MINGW_NAME_AW(RtlStringCchCopyN)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchCopyNA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToCopy) {
  if(cchDest > NTSTRSAFE_MAX_CCH || cchToCopy > NTSTRSAFE_MAX_CCH)
    return STATUS_INVALID_PARAMETER;
  return RtlStringCopyNWorkerA(pszDest,cchDest,pszSrc,cchToCopy);
}

NTSTRSAFEDDI RtlStringCchCopyNW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToCopy) {
  if(cchDest > NTSTRSAFE_MAX_CCH || cchToCopy > NTSTRSAFE_MAX_CCH)
    return STATUS_INVALID_PARAMETER;
  return RtlStringCopyNWorkerW(pszDest,cchDest,pszSrc,cchToCopy);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCbCopyNA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cbToCopy);
NTSTRSAFEDDI RtlStringCbCopyNW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cbToCopy);

#define RtlStringCbCopyN __MINGW_NAME_AW(RtlStringCbCopyN)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbCopyNA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cbToCopy) {
  if(cbDest > NTSTRSAFE_MAX_CCH || cbToCopy > NTSTRSAFE_MAX_CCH)
    return STATUS_INVALID_PARAMETER;
  return RtlStringCopyNWorkerA(pszDest,cbDest,pszSrc,cbToCopy);
}

NTSTRSAFEDDI RtlStringCbCopyNW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cbToCopy) {
  size_t cchDest  = cbDest / sizeof(wchar_t);
  size_t cchToCopy = cbToCopy / sizeof(wchar_t);
  if(cchDest > NTSTRSAFE_MAX_CCH || cchToCopy > NTSTRSAFE_MAX_CCH)
    return STATUS_INVALID_PARAMETER;
  return RtlStringCopyNWorkerW(pszDest,cchDest,pszSrc,cchToCopy);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCchCopyNExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToCopy,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCchCopyNExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToCopy,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);

#define RtlStringCchCopyNEx __MINGW_NAME_AW(RtlStringCchCopyNEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchCopyNExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToCopy,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCopyNExWorkerA(pszDest,cchDest,cchDest,pszSrc,cchToCopy,ppszDestEnd,pcchRemaining,dwFlags);
}

NTSTRSAFEDDI RtlStringCchCopyNExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToCopy,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCopyNExWorkerW(pszDest,cchDest,cchDest * sizeof(wchar_t),pszSrc,cchToCopy,ppszDestEnd,pcchRemaining,dwFlags);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCbCopyNExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cbToCopy,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCbCopyNExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cbToCopy,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags);

#define RtlStringCbCopyNEx __MINGW_NAME_AW(RtlStringCbCopyNEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbCopyNExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cbToCopy,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr;
  size_t cchRemaining = 0;
  if(cbDest > NTSTRSAFE_MAX_CCH)
    hr = STATUS_INVALID_PARAMETER;
  else
    hr = RtlStringCopyNExWorkerA(pszDest,cbDest,cbDest,pszSrc,cbToCopy,ppszDestEnd,&cchRemaining,dwFlags);
  if((NT_SUCCESS(hr) || hr == STATUS_BUFFER_OVERFLOW) && pcbRemaining)
    *pcbRemaining = cchRemaining;
  return hr;
}

NTSTRSAFEDDI RtlStringCbCopyNExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cbToCopy,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr;
  size_t cchDest;
  size_t cchToCopy;
  size_t cchRemaining = 0;
  cchDest = cbDest / sizeof(wchar_t);
  cchToCopy = cbToCopy / sizeof(wchar_t);
  if(cchDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringCopyNExWorkerW(pszDest,cchDest,cbDest,pszSrc,cchToCopy,ppszDestEnd,&cchRemaining,dwFlags);
  if((NT_SUCCESS(hr) || hr == STATUS_BUFFER_OVERFLOW) && pcbRemaining)
    *pcbRemaining = (cchRemaining*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t));
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCchCatA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc);
NTSTRSAFEDDI RtlStringCchCatW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc);

#define RtlStringCchCat __MINGW_NAME_AW(RtlStringCchCat)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchCatA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatWorkerA(pszDest,cchDest,pszSrc);
}

NTSTRSAFEDDI RtlStringCchCatW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatWorkerW(pszDest,cchDest,pszSrc);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCbCatA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc);
NTSTRSAFEDDI RtlStringCbCatW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc);

#define RtlStringCbCat __MINGW_NAME_AW(RtlStringCbCat)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbCatA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc) {
  if(cbDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatWorkerA(pszDest,cbDest,pszSrc);
}

NTSTRSAFEDDI RtlStringCbCatW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc) {
  size_t cchDest = cbDest / sizeof(wchar_t);
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatWorkerW(pszDest,cchDest,pszSrc);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCchCatExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCchCatExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);

#define RtlStringCchCatEx __MINGW_NAME_AW(RtlStringCchCatEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchCatExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatExWorkerA(pszDest,cchDest,cchDest,pszSrc,ppszDestEnd,pcchRemaining,dwFlags);
}

NTSTRSAFEDDI RtlStringCchCatExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  size_t cbDest = cchDest*sizeof(wchar_t);
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatExWorkerW(pszDest,cchDest,cbDest,pszSrc,ppszDestEnd,pcchRemaining,dwFlags);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCbCatExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCbCatExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags);

#define RtlStringCbCatEx __MINGW_NAME_AW(RtlStringCbCatEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbCatExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr;
  size_t cchRemaining = 0;
  if(cbDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringCatExWorkerA(pszDest,cbDest,cbDest,pszSrc,ppszDestEnd,&cchRemaining,dwFlags);
  if((NT_SUCCESS(hr) || hr == STATUS_BUFFER_OVERFLOW) && pcbRemaining)
    *pcbRemaining = (cchRemaining*sizeof(char)) + (cbDest % sizeof(char));
  return hr;
}

NTSTRSAFEDDI RtlStringCbCatExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr;
  size_t cchDest = cbDest / sizeof(wchar_t);
  size_t cchRemaining = 0;

  if(cchDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringCatExWorkerW(pszDest,cchDest,cbDest,pszSrc,ppszDestEnd,&cchRemaining,dwFlags);
  if((NT_SUCCESS(hr) || hr == STATUS_BUFFER_OVERFLOW) && pcbRemaining)
    *pcbRemaining = (cchRemaining*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t));
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCchCatNA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToAppend);
NTSTRSAFEDDI RtlStringCchCatNW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToAppend);

#define RtlStringCchCatN __MINGW_NAME_AW(RtlStringCchCatN)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchCatNA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToAppend) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatNWorkerA(pszDest,cchDest,pszSrc,cchToAppend);
}

NTSTRSAFEDDI RtlStringCchCatNW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToAppend) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatNWorkerW(pszDest,cchDest,pszSrc,cchToAppend);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCbCatNA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cbToAppend);
NTSTRSAFEDDI RtlStringCbCatNW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cbToAppend);

#define RtlStringCbCatN __MINGW_NAME_AW(RtlStringCbCatN)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbCatNA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cbToAppend) {
  if(cbDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatNWorkerA(pszDest,cbDest,pszSrc,cbToAppend);
}

NTSTRSAFEDDI RtlStringCbCatNW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cbToAppend) {
  size_t cchDest = cbDest / sizeof(wchar_t);
  size_t cchToAppend = cbToAppend / sizeof(wchar_t);

  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatNWorkerW(pszDest,cchDest,pszSrc,cchToAppend);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCchCatNExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToAppend,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCchCatNExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToAppend,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags);

#define RtlStringCchCatNEx __MINGW_NAME_AW(RtlStringCchCatNEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchCatNExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToAppend,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatNExWorkerA(pszDest,cchDest,cchDest,pszSrc,cchToAppend,ppszDestEnd,pcchRemaining,dwFlags);
}

NTSTRSAFEDDI RtlStringCchCatNExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToAppend,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringCatNExWorkerW(pszDest,cchDest,(cchDest*sizeof(wchar_t)),pszSrc,cchToAppend,ppszDestEnd,pcchRemaining,dwFlags);
}
#endif

NTSTRSAFEDDI RtlStringCbCatNExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cbToAppend,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags);
NTSTRSAFEDDI RtlStringCbCatNExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cbToAppend,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags);

#define RtlStringCbCatNEx __MINGW_NAME_AW(RtlStringCbCatNEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbCatNExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cbToAppend,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr;
  size_t cchRemaining = 0;
  if(cbDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringCatNExWorkerA(pszDest,cbDest,cbDest,pszSrc,cbToAppend,ppszDestEnd,&cchRemaining,dwFlags);
  if((NT_SUCCESS(hr) || hr == STATUS_BUFFER_OVERFLOW) && pcbRemaining)
    *pcbRemaining = (cchRemaining*sizeof(char)) + (cbDest % sizeof(char));
  return hr;
}

NTSTRSAFEDDI RtlStringCbCatNExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cbToAppend,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr;
  size_t cchDest = cbDest / sizeof(wchar_t);
  size_t cchToAppend = cbToAppend / sizeof(wchar_t);
  size_t cchRemaining = 0;
  if(cchDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringCatNExWorkerW(pszDest,cchDest,cbDest,pszSrc,cchToAppend,ppszDestEnd,&cchRemaining,dwFlags);
  if((NT_SUCCESS(hr) || hr == STATUS_BUFFER_OVERFLOW) && pcbRemaining)
    *pcbRemaining = (cchRemaining*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t));
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCchVPrintfA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszFormat,va_list argList);
NTSTRSAFEDDI RtlStringCchVPrintfW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszFormat,va_list argList);

#define RtlStringCchVPrintf __MINGW_NAME_AW(RtlStringCchVPrintf)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchVPrintfA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszFormat,va_list argList) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringVPrintfWorkerA(pszDest,cchDest,pszFormat,argList);
}

NTSTRSAFEDDI RtlStringCchVPrintfW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszFormat,va_list argList) {
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringVPrintfWorkerW(pszDest,cchDest,pszFormat,argList);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCbVPrintfA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszFormat,va_list argList);
NTSTRSAFEDDI RtlStringCbVPrintfW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszFormat,va_list argList);

#define RtlStringCbVPrintf __MINGW_NAME_AW(RtlStringCbVPrintf)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbVPrintfA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszFormat,va_list argList) {
  if(cbDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringVPrintfWorkerA(pszDest,cbDest,pszFormat,argList);
}

NTSTRSAFEDDI RtlStringCbVPrintfW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszFormat,va_list argList) {
  size_t cchDest = cbDest / sizeof(wchar_t);
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  return RtlStringVPrintfWorkerW(pszDest,cchDest,pszFormat,argList);
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDIV RtlStringCchPrintfA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszFormat,...);
NTSTRSAFEDDIV RtlStringCchPrintfW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszFormat,...);

#define RtlStringCchPrintf __MINGW_NAME_AW(RtlStringCchPrintf)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDIV RtlStringCchPrintfA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszFormat,...) {
  NTSTATUS hr;
  va_list argList;
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  va_start(argList,pszFormat);
  hr = RtlStringVPrintfWorkerA(pszDest,cchDest,pszFormat,argList);
  va_end(argList);
  return hr;
}

NTSTRSAFEDDIV RtlStringCchPrintfW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszFormat,...) {
  NTSTATUS hr;
  va_list argList;
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  va_start(argList,pszFormat);
  hr = RtlStringVPrintfWorkerW(pszDest,cchDest,pszFormat,argList);
  va_end(argList);
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDIV RtlStringCbPrintfA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszFormat,...);
NTSTRSAFEDDIV RtlStringCbPrintfW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszFormat,...);

#define RtlStringCbPrintf __MINGW_NAME_AW(RtlStringCbPrintf)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDIV RtlStringCbPrintfA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PCSTR pszFormat,...) {
  NTSTATUS hr;
  va_list argList;
  if(cbDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  va_start(argList,pszFormat);
  hr = RtlStringVPrintfWorkerA(pszDest,cbDest,pszFormat,argList);
  va_end(argList);
  return hr;
}

NTSTRSAFEDDIV RtlStringCbPrintfW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PCWSTR pszFormat,...) {
  NTSTATUS hr;
  va_list argList;
  size_t cchDest = cbDest / sizeof(wchar_t);
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  va_start(argList,pszFormat);
  hr = RtlStringVPrintfWorkerW(pszDest,cchDest,pszFormat,argList);
  va_end(argList);
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDIV RtlStringCchPrintfExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,...);
NTSTRSAFEDDIV RtlStringCchPrintfExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,...);

#define RtlStringCchPrintfEx __MINGW_NAME_AW(RtlStringCchPrintfEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDIV RtlStringCchPrintfExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,...) {
  NTSTATUS hr;
  va_list argList;
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  va_start(argList,pszFormat);
  hr = RtlStringVPrintfExWorkerA(pszDest,cchDest,cchDest,ppszDestEnd,pcchRemaining,dwFlags,pszFormat,argList);
  va_end(argList);
  return hr;
}

NTSTRSAFEDDIV RtlStringCchPrintfExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,...) {
  NTSTATUS hr;
  size_t cbDest = cchDest * sizeof(wchar_t);
  va_list argList;
  if(cchDest > NTSTRSAFE_MAX_CCH) return STATUS_INVALID_PARAMETER;
  va_start(argList,pszFormat);
  hr = RtlStringVPrintfExWorkerW(pszDest,cchDest,cbDest,ppszDestEnd,pcchRemaining,dwFlags,pszFormat,argList);
  va_end(argList);
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDIV RtlStringCbPrintfExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,...);
NTSTRSAFEDDIV RtlStringCbPrintfExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,...);

#define RtlStringCbPrintfEx __MINGW_NAME_AW(RtlStringCbPrintfEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDIV RtlStringCbPrintfExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,...) {
  NTSTATUS hr;
  size_t cchDest;
  size_t cchRemaining = 0;
  cchDest = cbDest / sizeof(char);
  if(cchDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else {
    va_list argList;
    va_start(argList,pszFormat);
    hr = RtlStringVPrintfExWorkerA(pszDest,cchDest,cbDest,ppszDestEnd,&cchRemaining,dwFlags,pszFormat,argList);
    va_end(argList);
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(pcbRemaining) {
      *pcbRemaining = (cchRemaining*sizeof(char)) + (cbDest % sizeof(char));
    }
  }
  return hr;
}

NTSTRSAFEDDIV RtlStringCbPrintfExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,...) {
  NTSTATUS hr;
  size_t cchDest;
  size_t cchRemaining = 0;
  cchDest = cbDest / sizeof(wchar_t);
  if(cchDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else {
    va_list argList;
    va_start(argList,pszFormat);
    hr = RtlStringVPrintfExWorkerW(pszDest,cchDest,cbDest,ppszDestEnd,&cchRemaining,dwFlags,pszFormat,argList);
    va_end(argList);
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(pcbRemaining) {
      *pcbRemaining = (cchRemaining*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t));
    }
  }
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCchVPrintfExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,va_list argList);
NTSTRSAFEDDI RtlStringCchVPrintfExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,va_list argList);

#define RtlStringCchVPrintfEx __MINGW_NAME_AW(RtlStringCchVPrintfEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchVPrintfExA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,va_list argList) {
  NTSTATUS hr;
  if(cchDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else {
    size_t cbDest;
    cbDest = cchDest*sizeof(char);
    hr = RtlStringVPrintfExWorkerA(pszDest,cchDest,cbDest,ppszDestEnd,pcchRemaining,dwFlags,pszFormat,argList);
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCchVPrintfExW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,va_list argList) {
  NTSTATUS hr;
  if(cchDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else {
    size_t cbDest;
    cbDest = cchDest*sizeof(wchar_t);
    hr = RtlStringVPrintfExWorkerW(pszDest,cchDest,cbDest,ppszDestEnd,pcchRemaining,dwFlags,pszFormat,argList);
  }
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCbVPrintfExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,va_list argList);
NTSTRSAFEDDI RtlStringCbVPrintfExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,va_list argList);

#define RtlStringCbVPrintfEx __MINGW_NAME_AW(RtlStringCbVPrintfEx)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbVPrintfExA(NTSTRSAFE_PSTR pszDest,size_t cbDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,va_list argList) {
  NTSTATUS hr;
  size_t cchDest;
  size_t cchRemaining = 0;
  cchDest = cbDest / sizeof(char);
  if(cchDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringVPrintfExWorkerA(pszDest,cchDest,cbDest,ppszDestEnd,&cchRemaining,dwFlags,pszFormat,argList);
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(pcbRemaining) {
      *pcbRemaining = (cchRemaining*sizeof(char)) + (cbDest % sizeof(char));
    }
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCbVPrintfExW(NTSTRSAFE_PWSTR pszDest,size_t cbDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcbRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,va_list argList) {
  NTSTATUS hr;
  size_t cchDest;
  size_t cchRemaining = 0;
  cchDest = cbDest / sizeof(wchar_t);
  if(cchDest > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringVPrintfExWorkerW(pszDest,cchDest,cbDest,ppszDestEnd,&cchRemaining,dwFlags,pszFormat,argList);
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(pcbRemaining) {
      *pcbRemaining = (cchRemaining*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t));
    }
  }
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCchLengthA(NTSTRSAFE_PCSTR psz,size_t cchMax,size_t *pcchLength);
NTSTRSAFEDDI RtlStringCchLengthW(NTSTRSAFE_PCWSTR psz,size_t cchMax,size_t *pcchLength);

#define RtlStringCchLength __MINGW_NAME_AW(RtlStringCchLength)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCchLengthA(NTSTRSAFE_PCSTR psz,size_t cchMax,size_t *pcchLength) {
  NTSTATUS hr;
  if(!psz || (cchMax > NTSTRSAFE_MAX_CCH)) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringLengthWorkerA(psz,cchMax,pcchLength);
  if(!NT_SUCCESS(hr) && pcchLength) {
    *pcchLength = 0;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCchLengthW(NTSTRSAFE_PCWSTR psz,size_t cchMax,size_t *pcchLength) {
  NTSTATUS hr;
  if(!psz || (cchMax > NTSTRSAFE_MAX_CCH)) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringLengthWorkerW(psz,cchMax,pcchLength);
  if(!NT_SUCCESS(hr) && pcchLength) {
    *pcchLength = 0;
  }
  return hr;
}
#endif /* !__STRSAFE__NO_INLINE */

NTSTRSAFEDDI RtlStringCbLengthA(NTSTRSAFE_PCSTR psz,size_t cbMax,size_t *pcbLength);
NTSTRSAFEDDI RtlStringCbLengthW(NTSTRSAFE_PCWSTR psz,size_t cbMax,size_t *pcbLength);

#define RtlStringCbLength __MINGW_NAME_AW(RtlStringCbLength)

#ifndef __STRSAFE__NO_INLINE
NTSTRSAFEDDI RtlStringCbLengthA(NTSTRSAFE_PCSTR psz,size_t cbMax,size_t *pcbLength) {
  NTSTATUS hr;
  size_t cchMax;
  size_t cchLength = 0;
  cchMax = cbMax / sizeof(char);
  if(!psz || (cchMax > NTSTRSAFE_MAX_CCH)) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringLengthWorkerA(psz,cchMax,&cchLength);
  if(pcbLength) {
    if(NT_SUCCESS(hr)) {
      *pcbLength = cchLength*sizeof(char);
    } else {
      *pcbLength = 0;
    }
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCbLengthW(NTSTRSAFE_PCWSTR psz,size_t cbMax,size_t *pcbLength) {
  NTSTATUS hr;
  size_t cchMax;
  size_t cchLength = 0;
  cchMax = cbMax / sizeof(wchar_t);
  if(!psz || (cchMax > NTSTRSAFE_MAX_CCH)) hr = STATUS_INVALID_PARAMETER;
  else hr = RtlStringLengthWorkerW(psz,cchMax,&cchLength);
  if(pcbLength) {
    if(NT_SUCCESS(hr)) {
      *pcbLength = cchLength*sizeof(wchar_t);
    } else {
      *pcbLength = 0;
    }
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCopyWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc) {
  NTSTATUS hr = STATUS_SUCCESS;
  if(cchDest==0) hr = STATUS_INVALID_PARAMETER;
  else {
    while(cchDest && (*pszSrc!='\0')) {
      *pszDest++ = *pszSrc++;
      cchDest--;
    }
    if(cchDest==0) {
      pszDest--;
      hr = STATUS_BUFFER_OVERFLOW;
    }
    *pszDest= '\0';
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCopyWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc) {
  NTSTATUS hr = STATUS_SUCCESS;
  if(cchDest==0) hr = STATUS_INVALID_PARAMETER;
  else {
    while(cchDest && (*pszSrc!=L'\0')) {
      *pszDest++ = *pszSrc++;
      cchDest--;
    }
    if(cchDest==0) {
      pszDest--;
      hr = STATUS_BUFFER_OVERFLOW;
    }
    *pszDest= L'\0';
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCopyExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else {
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest!=0) || (cbDest!=0)) hr = STATUS_INVALID_PARAMETER;
      }
      if(!pszSrc) pszSrc = "";
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	pszDestEnd = pszDest;
	cchRemaining = 0;
	if(*pszSrc!='\0') {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else {
	pszDestEnd = pszDest;
	cchRemaining = cchDest;
	while(cchRemaining && (*pszSrc!='\0')) {
	  *pszDestEnd++ = *pszSrc++;
	  cchRemaining--;
	}
	if(cchRemaining > 0) {
	  if(dwFlags & STRSAFE_FILL_BEHIND_NULL) {
	    memset(pszDestEnd + 1,STRSAFE_GET_FILL_PATTERN(dwFlags),((cchRemaining - 1)*sizeof(char)) + (cbDest % sizeof(char)));
	  }
	} else {
	  pszDestEnd--;
	  cchRemaining++;
	  hr = STATUS_BUFFER_OVERFLOW;
	}
	*pszDestEnd = '\0';
      }
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = '\0';
	}
      }
      if(dwFlags & (STRSAFE_NULL_ON_FAILURE | STRSAFE_NO_TRUNCATION)) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = '\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCopyExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PWSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else {
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest!=0) || (cbDest!=0)) hr = STATUS_INVALID_PARAMETER;
      }
      if(!pszSrc) pszSrc = L"";
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	pszDestEnd = pszDest;
	cchRemaining = 0;
	if(*pszSrc!=L'\0') {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else {
	pszDestEnd = pszDest;
	cchRemaining = cchDest;
	while(cchRemaining && (*pszSrc!=L'\0')) {
	  *pszDestEnd++ = *pszSrc++;
	  cchRemaining--;
	}
	if(cchRemaining > 0) {
	  if(dwFlags & STRSAFE_FILL_BEHIND_NULL) {
	    memset(pszDestEnd + 1,STRSAFE_GET_FILL_PATTERN(dwFlags),((cchRemaining - 1)*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t)));
	  }
	} else {
	  pszDestEnd--;
	  cchRemaining++;
	  hr = STATUS_BUFFER_OVERFLOW;
	}
	*pszDestEnd = L'\0';
      }
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = L'\0';
	}
      }
      if(dwFlags & (STRSAFE_NULL_ON_FAILURE | STRSAFE_NO_TRUNCATION)) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = L'\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCopyNWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchSrc) {
  NTSTATUS hr = STATUS_SUCCESS;
  if(cchDest==0) hr = STATUS_INVALID_PARAMETER;
  else {
    while(cchDest && cchSrc && (*pszSrc!='\0')) {
      *pszDest++ = *pszSrc++;
      cchDest--;
      cchSrc--;
    }
    if(cchDest==0) {
      pszDest--;
      hr = STATUS_BUFFER_OVERFLOW;
    }
    *pszDest= '\0';
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCopyNWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToCopy) {
  NTSTATUS hr = STATUS_SUCCESS;
  if(cchDest==0) hr = STATUS_INVALID_PARAMETER;
  else {
    while(cchDest && cchToCopy && (*pszSrc!=L'\0')) {
      *pszDest++ = *pszSrc++;
      cchDest--;
      cchToCopy--;
    }
    if(cchDest==0) {
      pszDest--;
      hr = STATUS_BUFFER_OVERFLOW;
    }
    *pszDest= L'\0';
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCopyNExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToCopy,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else if(cchToCopy > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else {
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest!=0) || (cbDest!=0)) hr = STATUS_INVALID_PARAMETER;
      }
      if(!pszSrc) pszSrc = "";
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	pszDestEnd = pszDest;
	cchRemaining = 0;
	if((cchToCopy!=0) && (*pszSrc!='\0')) {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else {
	pszDestEnd = pszDest;
	cchRemaining = cchDest;
	while(cchRemaining && cchToCopy && (*pszSrc!='\0')) {
	  *pszDestEnd++ = *pszSrc++;
	  cchRemaining--;
	  cchToCopy--;
	}
	if(cchRemaining > 0) {
	  if(dwFlags & STRSAFE_FILL_BEHIND_NULL) {
	    memset(pszDestEnd + 1,STRSAFE_GET_FILL_PATTERN(dwFlags),((cchRemaining - 1)*sizeof(char)) + (cbDest % sizeof(char)));
	  }
	} else {
	  pszDestEnd--;
	  cchRemaining++;
	  hr = STATUS_BUFFER_OVERFLOW;
	}
	*pszDestEnd = '\0';
      }
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = '\0';
	}
      }
      if(dwFlags & (STRSAFE_NULL_ON_FAILURE | STRSAFE_NO_TRUNCATION)) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = '\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCopyNExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToCopy,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PWSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else if(cchToCopy > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else {
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest!=0) || (cbDest!=0)) hr = STATUS_INVALID_PARAMETER;
      }
      if(!pszSrc) pszSrc = L"";
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	pszDestEnd = pszDest;
	cchRemaining = 0;
	if((cchToCopy!=0) && (*pszSrc!=L'\0')) {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else {
	pszDestEnd = pszDest;
	cchRemaining = cchDest;
	while(cchRemaining && cchToCopy && (*pszSrc!=L'\0')) {
	  *pszDestEnd++ = *pszSrc++;
	  cchRemaining--;
	  cchToCopy--;
	}
	if(cchRemaining > 0) {
	  if(dwFlags & STRSAFE_FILL_BEHIND_NULL) {
	    memset(pszDestEnd + 1,STRSAFE_GET_FILL_PATTERN(dwFlags),((cchRemaining - 1)*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t)));
	  }
	} else {
	  pszDestEnd--;
	  cchRemaining++;
	  hr = STATUS_BUFFER_OVERFLOW;
	}
	*pszDestEnd = L'\0';
      }
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = L'\0';
	}
      }
      if(dwFlags & (STRSAFE_NULL_ON_FAILURE | STRSAFE_NO_TRUNCATION)) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = L'\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCatWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc) {
  NTSTATUS hr;
  size_t cchDestLength;
  hr = RtlStringLengthWorkerA(pszDest,cchDest,&cchDestLength);
  if(NT_SUCCESS(hr)) hr = RtlStringCopyWorkerA(pszDest + cchDestLength,cchDest - cchDestLength,pszSrc);
  return hr;
}

NTSTRSAFEDDI RtlStringCatWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc) {
  NTSTATUS hr;
  size_t cchDestLength;
  hr = RtlStringLengthWorkerW(pszDest,cchDest,&cchDestLength);
  if(NT_SUCCESS(hr)) hr = RtlStringCopyWorkerW(pszDest + cchDestLength,cchDest - cchDestLength,pszSrc);
  return hr;
}

NTSTRSAFEDDI RtlStringCatExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else {
    size_t cchDestLength;
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest==0) && (cbDest==0)) cchDestLength = 0;
	else hr = STATUS_INVALID_PARAMETER;
      } else {
	hr = RtlStringLengthWorkerA(pszDest,cchDest,&cchDestLength);
	if(NT_SUCCESS(hr)) {
	  pszDestEnd = pszDest + cchDestLength;
	  cchRemaining = cchDest - cchDestLength;
	}
      }
      if(!pszSrc) pszSrc = "";
    } else {
      hr = RtlStringLengthWorkerA(pszDest,cchDest,&cchDestLength);
      if(NT_SUCCESS(hr)) {
	pszDestEnd = pszDest + cchDestLength;
	cchRemaining = cchDest - cchDestLength;
      }
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	if(*pszSrc!='\0') {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else hr = RtlStringCopyExWorkerA(pszDestEnd,cchRemaining,(cchRemaining*sizeof(char)) + (cbDest % sizeof(char)),pszSrc,&pszDestEnd,&cchRemaining,dwFlags & (~(STRSAFE_FILL_ON_FAILURE | STRSAFE_NULL_ON_FAILURE)));
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = '\0';
	}
      }
      if(dwFlags & STRSAFE_NULL_ON_FAILURE) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = '\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCatExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PWSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else {
    size_t cchDestLength;
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest==0) && (cbDest==0)) cchDestLength = 0;
	else hr = STATUS_INVALID_PARAMETER;
      } else {
	hr = RtlStringLengthWorkerW(pszDest,cchDest,&cchDestLength);
	if(NT_SUCCESS(hr)) {
	  pszDestEnd = pszDest + cchDestLength;
	  cchRemaining = cchDest - cchDestLength;
	}
      }
      if(!pszSrc) pszSrc = L"";
    } else {
      hr = RtlStringLengthWorkerW(pszDest,cchDest,&cchDestLength);
      if(NT_SUCCESS(hr)) {
	pszDestEnd = pszDest + cchDestLength;
	cchRemaining = cchDest - cchDestLength;
      }
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	if(*pszSrc!=L'\0') {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else hr = RtlStringCopyExWorkerW(pszDestEnd,cchRemaining,(cchRemaining*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t)),pszSrc,&pszDestEnd,&cchRemaining,dwFlags & (~(STRSAFE_FILL_ON_FAILURE | STRSAFE_NULL_ON_FAILURE)));
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = L'\0';
	}
      }
      if(dwFlags & STRSAFE_NULL_ON_FAILURE) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = L'\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCatNWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToAppend) {
  NTSTATUS hr;
  size_t cchDestLength;
  hr = RtlStringLengthWorkerA(pszDest,cchDest,&cchDestLength);
  if(NT_SUCCESS(hr)) hr = RtlStringCopyNWorkerA(pszDest + cchDestLength,cchDest - cchDestLength,pszSrc,cchToAppend);
  return hr;
}

NTSTRSAFEDDI RtlStringCatNWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToAppend) {
  NTSTATUS hr;
  size_t cchDestLength;
  hr = RtlStringLengthWorkerW(pszDest,cchDest,&cchDestLength);
  if(NT_SUCCESS(hr)) hr = RtlStringCopyNWorkerW(pszDest + cchDestLength,cchDest - cchDestLength,pszSrc,cchToAppend);
  return hr;
}

NTSTRSAFEDDI RtlStringCatNExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCSTR pszSrc,size_t cchToAppend,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  size_t cchDestLength = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else if(cchToAppend > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else {
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest==0) && (cbDest==0)) cchDestLength = 0;
	else hr = STATUS_INVALID_PARAMETER;
      } else {
	hr = RtlStringLengthWorkerA(pszDest,cchDest,&cchDestLength);
	if(NT_SUCCESS(hr)) {
	  pszDestEnd = pszDest + cchDestLength;
	  cchRemaining = cchDest - cchDestLength;
	}
      }
      if(!pszSrc) pszSrc = "";
    } else {
      hr = RtlStringLengthWorkerA(pszDest,cchDest,&cchDestLength);
      if(NT_SUCCESS(hr)) {
	pszDestEnd = pszDest + cchDestLength;
	cchRemaining = cchDest - cchDestLength;
      }
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	if((cchToAppend!=0) && (*pszSrc!='\0')) {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else hr = RtlStringCopyNExWorkerA(pszDestEnd,cchRemaining,(cchRemaining*sizeof(char)) + (cbDest % sizeof(char)),pszSrc,cchToAppend,&pszDestEnd,&cchRemaining,dwFlags & (~(STRSAFE_FILL_ON_FAILURE | STRSAFE_NULL_ON_FAILURE)));
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = '\0';
	}
      }
      if(dwFlags & (STRSAFE_NULL_ON_FAILURE)) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = '\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringCatNExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PCWSTR pszSrc,size_t cchToAppend,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PWSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  size_t cchDestLength = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else if(cchToAppend > NTSTRSAFE_MAX_CCH) hr = STATUS_INVALID_PARAMETER;
  else {
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest==0) && (cbDest==0)) cchDestLength = 0;
	else hr = STATUS_INVALID_PARAMETER;
      } else {
	hr = RtlStringLengthWorkerW(pszDest,cchDest,&cchDestLength);
	if(NT_SUCCESS(hr)) {
	  pszDestEnd = pszDest + cchDestLength;
	  cchRemaining = cchDest - cchDestLength;
	}
      }
      if(!pszSrc) pszSrc = L"";
    } else {
      hr = RtlStringLengthWorkerW(pszDest,cchDest,&cchDestLength);
      if(NT_SUCCESS(hr)) {
	pszDestEnd = pszDest + cchDestLength;
	cchRemaining = cchDest - cchDestLength;
      }
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	if((cchToAppend!=0) && (*pszSrc!=L'\0')) {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else hr = RtlStringCopyNExWorkerW(pszDestEnd,cchRemaining,(cchRemaining*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t)),pszSrc,cchToAppend,&pszDestEnd,&cchRemaining,dwFlags & (~(STRSAFE_FILL_ON_FAILURE | STRSAFE_NULL_ON_FAILURE)));
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = L'\0';
	}
      }
      if(dwFlags & (STRSAFE_NULL_ON_FAILURE)) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = L'\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringVPrintfWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,NTSTRSAFE_PCSTR pszFormat,va_list argList) {
  NTSTATUS hr = STATUS_SUCCESS;
  if(cchDest==0) hr = STATUS_INVALID_PARAMETER;
  else {
    int iRet;
    size_t cchMax;
    cchMax = cchDest - 1;
    iRet = _vsnprintf(pszDest,cchMax,pszFormat,argList);
    if((iRet < 0) || (((size_t)iRet) > cchMax)) {
      pszDest += cchMax;
      *pszDest = '\0';
      hr = STATUS_BUFFER_OVERFLOW;
    } else if(((size_t)iRet)==cchMax) {
      pszDest += cchMax;
      *pszDest = '\0';
    }
  }
  return hr;
}

NTSTRSAFEDDI RtlStringVPrintfWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,NTSTRSAFE_PCWSTR pszFormat,va_list argList) {
  NTSTATUS hr = STATUS_SUCCESS;
  if(cchDest==0) hr = STATUS_INVALID_PARAMETER;
  else {
    int iRet;
    size_t cchMax;
    cchMax = cchDest - 1;
    iRet = _vsnwprintf(pszDest,cchMax,pszFormat,argList);
    if((iRet < 0) || (((size_t)iRet) > cchMax)) {
      pszDest += cchMax;
      *pszDest = L'\0';
      hr = STATUS_BUFFER_OVERFLOW;
    } else if(((size_t)iRet)==cchMax) {
      pszDest += cchMax;
      *pszDest = L'\0';
    }
  }
  return hr;
}

NTSTRSAFEDDI RtlStringVPrintfExWorkerA(NTSTRSAFE_PSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCSTR pszFormat,va_list argList) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else {
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest!=0) || (cbDest!=0)) hr = STATUS_INVALID_PARAMETER;
      }
      if(!pszFormat) pszFormat = "";
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	pszDestEnd = pszDest;
	cchRemaining = 0;
	if(*pszFormat!='\0') {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else {
	int iRet;
	size_t cchMax;
	cchMax = cchDest - 1;
	iRet = _vsnprintf(pszDest,cchMax,pszFormat,argList);
	if((iRet < 0) || (((size_t)iRet) > cchMax)) {
	  pszDestEnd = pszDest + cchMax;
	  cchRemaining = 1;
	  *pszDestEnd = '\0';
	  hr = STATUS_BUFFER_OVERFLOW;
	} else if(((size_t)iRet)==cchMax) {
	  pszDestEnd = pszDest + cchMax;
	  cchRemaining = 1;
	  *pszDestEnd = '\0';
	} else if(((size_t)iRet) < cchMax) {
	  pszDestEnd = pszDest + iRet;
	  cchRemaining = cchDest - iRet;
	  if(dwFlags & STRSAFE_FILL_BEHIND_NULL) {
	    memset(pszDestEnd + 1,STRSAFE_GET_FILL_PATTERN(dwFlags),((cchRemaining - 1)*sizeof(char)) + (cbDest % sizeof(char)));
	  }
	}
      }
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = '\0';
	}
      }
      if(dwFlags & (STRSAFE_NULL_ON_FAILURE | STRSAFE_NO_TRUNCATION)) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = '\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringVPrintfExWorkerW(NTSTRSAFE_PWSTR pszDest,size_t cchDest,size_t cbDest,NTSTRSAFE_PWSTR *ppszDestEnd,size_t *pcchRemaining,unsigned __LONG32 dwFlags,NTSTRSAFE_PCWSTR pszFormat,va_list argList) {
  NTSTATUS hr = STATUS_SUCCESS;
  NTSTRSAFE_PWSTR pszDestEnd = pszDest;
  size_t cchRemaining = 0;
  if(dwFlags & (~STRSAFE_VALID_FLAGS)) hr = STATUS_INVALID_PARAMETER;
  else {
    if(dwFlags & STRSAFE_IGNORE_NULLS) {
      if(!pszDest) {
	if((cchDest!=0) || (cbDest!=0)) hr = STATUS_INVALID_PARAMETER;
      }
      if(!pszFormat) pszFormat = L"";
    }
    if(NT_SUCCESS(hr)) {
      if(cchDest==0) {
	pszDestEnd = pszDest;
	cchRemaining = 0;
	if(*pszFormat!=L'\0') {
	  if(!pszDest) hr = STATUS_INVALID_PARAMETER;
	  else hr = STATUS_BUFFER_OVERFLOW;
	}
      } else {
	int iRet;
	size_t cchMax;
	cchMax = cchDest - 1;
	iRet = _vsnwprintf(pszDest,cchMax,pszFormat,argList);
	if((iRet < 0) || (((size_t)iRet) > cchMax)) {
	  pszDestEnd = pszDest + cchMax;
	  cchRemaining = 1;
	  *pszDestEnd = L'\0';
	  hr = STATUS_BUFFER_OVERFLOW;
	} else if(((size_t)iRet)==cchMax) {
	  pszDestEnd = pszDest + cchMax;
	  cchRemaining = 1;
	  *pszDestEnd = L'\0';
	} else if(((size_t)iRet) < cchMax) {
	  pszDestEnd = pszDest + iRet;
	  cchRemaining = cchDest - iRet;
	  if(dwFlags & STRSAFE_FILL_BEHIND_NULL) {
	    memset(pszDestEnd + 1,STRSAFE_GET_FILL_PATTERN(dwFlags),((cchRemaining - 1)*sizeof(wchar_t)) + (cbDest % sizeof(wchar_t)));
	  }
	}
      }
    }
  }
  if(!NT_SUCCESS(hr)) {
    if(pszDest) {
      if(dwFlags & STRSAFE_FILL_ON_FAILURE) {
	memset(pszDest,STRSAFE_GET_FILL_PATTERN(dwFlags),cbDest);
	if(STRSAFE_GET_FILL_PATTERN(dwFlags)==0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	} else if(cchDest > 0) {
	  pszDestEnd = pszDest + cchDest - 1;
	  cchRemaining = 1;
	  *pszDestEnd = L'\0';
	}
      }
      if(dwFlags & (STRSAFE_NULL_ON_FAILURE | STRSAFE_NO_TRUNCATION)) {
	if(cchDest > 0) {
	  pszDestEnd = pszDest;
	  cchRemaining = cchDest;
	  *pszDestEnd = L'\0';
	}
      }
    }
  }
  if(NT_SUCCESS(hr) || (hr==STATUS_BUFFER_OVERFLOW)) {
    if(ppszDestEnd) *ppszDestEnd = pszDestEnd;
    if(pcchRemaining) *pcchRemaining = cchRemaining;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringLengthWorkerA(NTSTRSAFE_PCSTR psz,size_t cchMax,size_t *pcchLength) {
  NTSTATUS hr = STATUS_SUCCESS;
  size_t cchMaxPrev = cchMax;
  while(cchMax && (*psz!='\0')) {
    psz++;
    cchMax--;
  }
  if(cchMax==0) hr = STATUS_INVALID_PARAMETER;
  if(pcchLength) {
    if(NT_SUCCESS(hr)) *pcchLength = cchMaxPrev - cchMax;
    else *pcchLength = 0;
  }
  return hr;
}

NTSTRSAFEDDI RtlStringLengthWorkerW(NTSTRSAFE_PCWSTR psz,size_t cchMax,size_t *pcchLength) {
  NTSTATUS hr = STATUS_SUCCESS;
  size_t cchMaxPrev = cchMax;
  while(cchMax && (*psz!=L'\0')) {
    psz++;
    cchMax--;
  }
  if(cchMax==0) hr = STATUS_INVALID_PARAMETER;
  if(pcchLength) {
    if(NT_SUCCESS(hr)) *pcchLength = cchMaxPrev - cchMax;
    else *pcchLength = 0;
  }
  return hr;
}

#endif /* !__STRSAFE__NO_INLINE */

#define RtlStringCopyWorkerA RtlStringCopyWorkerA_instead_use_RtlStringCchCopyA_or_RtlStringCchCopyExA;
#define RtlStringCopyWorkerW RtlStringCopyWorkerW_instead_use_RtlStringCchCopyW_or_RtlStringCchCopyExW;
#define RtlStringCopyExWorkerA RtlStringCopyExWorkerA_instead_use_RtlStringCchCopyA_or_RtlStringCchCopyExA;
#define RtlStringCopyExWorkerW RtlStringCopyExWorkerW_instead_use_RtlStringCchCopyW_or_RtlStringCchCopyExW;
#define RtlStringCatWorkerA RtlStringCatWorkerA_instead_use_RtlStringCchCatA_or_RtlStringCchCatExA;
#define RtlStringCatWorkerW RtlStringCatWorkerW_instead_use_RtlStringCchCatW_or_RtlStringCchCatExW;
#define RtlStringCatExWorkerA RtlStringCatExWorkerA_instead_use_RtlStringCchCatA_or_RtlStringCchCatExA;
#define RtlStringCatExWorkerW RtlStringCatExWorkerW_instead_use_RtlStringCchCatW_or_RtlStringCchCatExW;
#define RtlStringCatNWorkerA RtlStringCatNWorkerA_instead_use_RtlStringCchCatNA_or_StrincCbCatNA;
#define RtlStringCatNWorkerW RtlStringCatNWorkerW_instead_use_RtlStringCchCatNW_or_RtlStringCbCatNW;
#define RtlStringCatNExWorkerA RtlStringCatNExWorkerA_instead_use_RtlStringCchCatNExA_or_RtlStringCbCatNExA;
#define RtlStringCatNExWorkerW RtlStringCatNExWorkerW_instead_use_RtlStringCchCatNExW_or_RtlStringCbCatNExW;
#define RtlStringVPrintfWorkerA RtlStringVPrintfWorkerA_instead_use_RtlStringCchVPrintfA_or_RtlStringCchVPrintfExA;
#define RtlStringVPrintfWorkerW RtlStringVPrintfWorkerW_instead_use_RtlStringCchVPrintfW_or_RtlStringCchVPrintfExW;
#define RtlStringVPrintfExWorkerA RtlStringVPrintfExWorkerA_instead_use_RtlStringCchVPrintfA_or_RtlStringCchVPrintfExA;
#define RtlStringVPrintfExWorkerW RtlStringVPrintfExWorkerW_instead_use_RtlStringCchVPrintfW_or_RtlStringCchVPrintfExW;
#define RtlStringLengthWorkerA RtlStringLengthWorkerA_instead_use_RtlStringCchLengthA_or_RtlStringCbLengthA;
#define RtlStringLengthWorkerW RtlStringLengthWorkerW_instead_use_RtlStringCchLengthW_or_RtlStringCbLengthW;

#endif
