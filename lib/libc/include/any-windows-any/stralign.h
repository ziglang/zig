/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __STRALIGN_H_
#define __STRALIGN_H_

#ifndef _STRALIGN_USE_SECURE_CRT
#define _STRALIGN_USE_SECURE_CRT 0
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef WSTR_ALIGNED
#if defined (__x86_64__) || defined (__arm__)
#define WSTR_ALIGNED(s) TRUE
#else
#define WSTR_ALIGNED(s) (((DWORD_PTR)(s) & 1) == 0)
#endif
#endif

#if defined(_X86_)
#define ua_CharUpperW CharUpperW
#define ua_lstrcmpiW lstrcmpiW
#define ua_lstrcmpW lstrcmpW
#define ua_lstrlenW lstrlenW
#define ua_wcschr wcschr
#define ua_wcsicmp wcsicmp
#define ua_wcslen wcslen
#define ua_wcsrchr wcsrchr

  PUWSTR ua_wcscpy(PUWSTR Destination,PCUWSTR Source);
#if !defined (__CRT__NO_INLINE) && !defined (__CYGWIN__)
  __CRT_INLINE PUWSTR ua_wcscpy(PUWSTR Destination,PCUWSTR Source) { return wcscpy(Destination,Source); }
#else
#define ua_wcscpy wcscpy
#endif

#else /* not _X86_ : */

#ifndef WSTR_ALIGNED
#define WSTR_ALIGNED(s) (((DWORD_PTR)(s) & (sizeof(WCHAR)-1))==0)
#endif

  /* TODO: This method seems to be not present for x86-64.  */
  LPUWSTR WINAPI uaw_CharUpperW(LPUWSTR String);
  int WINAPI uaw_lstrcmpW(PCUWSTR String1,PCUWSTR String2);
  int WINAPI uaw_lstrcmpiW(PCUWSTR String1,PCUWSTR String2);
  int WINAPI uaw_lstrlenW(LPCUWSTR String);
  PUWSTR __cdecl uaw_wcschr(PCUWSTR String,WCHAR Character);
  PUWSTR __cdecl uaw_wcscpy(PUWSTR Destination,PCUWSTR Source);
  int __cdecl uaw_wcsicmp(PCUWSTR String1,PCUWSTR String2);
  size_t __cdecl uaw_wcslen(PCUWSTR String);
  PUWSTR __cdecl uaw_wcsrchr(PCUWSTR String,WCHAR Character);
#ifdef CharUpper
  LPUWSTR ua_CharUpperW(LPUWSTR String);
#ifndef __CRT__NO_INLINE
  __CRT_INLINE LPUWSTR ua_CharUpperW(LPUWSTR String) {
    if(WSTR_ALIGNED(String)) return CharUpperW((PWSTR)String);
    return uaw_CharUpperW(String);
  }
#endif /* !__CRT__NO_INLINE */
#endif /* CharUpper */

#ifdef lstrcmp
  int ua_lstrcmpW(LPCUWSTR String1,LPCUWSTR String2);
#endif
#ifdef lstrcmpi
  int ua_lstrcmpiW(LPCUWSTR String1,LPCUWSTR String2);
#endif
#ifdef lstrlen
  int ua_lstrlenW(LPCUWSTR String);
#endif

#ifndef __CRT__NO_INLINE
#ifdef lstrcmp
  __CRT_INLINE int ua_lstrcmpW(LPCUWSTR String1,LPCUWSTR String2) {
    if(WSTR_ALIGNED(String1) && WSTR_ALIGNED(String2))
      return lstrcmpW((LPCWSTR)String1,(LPCWSTR)String2);
    return uaw_lstrcmpW(String1,String2);
  }
#endif

#ifdef lstrcmpi
  __CRT_INLINE int ua_lstrcmpiW(LPCUWSTR String1,LPCUWSTR String2) {
    if(WSTR_ALIGNED(String1) && WSTR_ALIGNED(String2))
      return lstrcmpiW((LPCWSTR)String1,(LPCWSTR)String2);
    return uaw_lstrcmpiW(String1,String2);
  }
#endif

#ifdef lstrlen
  __CRT_INLINE int ua_lstrlenW(LPCUWSTR String) {
    if(WSTR_ALIGNED(String)) return lstrlenW((PCWSTR)String);
    return uaw_lstrlenW(String);
  }
#endif
#endif /* !__CRT__NO_INLINE */

#if defined(_WSTRING_DEFINED)
#ifdef _WConst_return
  typedef _WConst_return WCHAR UNALIGNED *PUWSTR_C;
#else
  typedef WCHAR UNALIGNED *PUWSTR_C;
#endif

  PUWSTR_C ua_wcschr(PCUWSTR String,WCHAR Character);
  PUWSTR_C ua_wcsrchr(PCUWSTR String,WCHAR Character);
#if defined(__cplusplus) && defined(_WConst_Return)
  PUWSTR ua_wcschr(PUWSTR String,WCHAR Character);
  PUWSTR ua_wcsrchr(PUWSTR String,WCHAR Character);
#endif
  PUWSTR ua_wcscpy(PUWSTR Destination,PCUWSTR Source);
  size_t ua_wcslen(PCUWSTR String);

#ifndef __CRT__NO_INLINE
  __CRT_INLINE PUWSTR_C ua_wcschr(PCUWSTR String,WCHAR Character) {
    if(WSTR_ALIGNED(String)) return (PUWSTR_C)wcschr((PCWSTR)String,Character);
    return (PUWSTR_C)uaw_wcschr(String,Character);
  }
  __CRT_INLINE PUWSTR_C ua_wcsrchr(PCUWSTR String,WCHAR Character) {
    if(WSTR_ALIGNED(String)) return (PUWSTR_C)wcsrchr((PCWSTR)String,Character);
    return (PUWSTR_C)uaw_wcsrchr(String,Character);
  }
#if defined(__cplusplus) && defined(_WConst_Return)
  __CRT_INLINE PUWSTR ua_wcschr(PUWSTR String,WCHAR Character) {
    if(WSTR_ALIGNED(String)) return wcscpy((PWSTR)Destination,(PCWSTR)Source);
    return uaw_wcscpy(Destination,Source);
  }
  __CRT_INLINE PUWSTR ua_wcsrchr(PUWSTR String,WCHAR Character) {
    if(WSTR_ALIGNED(String)) return wcsrchr(String,Character);
    return uaw_wcsrchr((PCUWSTR)String,Character);
  }
#endif

  __CRT_INLINE PUWSTR ua_wcscpy(PUWSTR Destination,PCUWSTR Source) {
    if(WSTR_ALIGNED(Source) && WSTR_ALIGNED(Destination))
      return wcscpy((PWSTR)Destination,(PCWSTR)Source);
    return uaw_wcscpy(Destination,Source);
  }
  __CRT_INLINE size_t ua_wcslen(PCUWSTR String) {
    if(WSTR_ALIGNED(String)) return wcslen((PCWSTR)String);
    return uaw_wcslen(String);
  }
#endif /* !__CRT__NO_INLINE */
#endif /* _X86_ */
  int ua_wcsicmp(LPCUWSTR String1,LPCUWSTR String2);

#ifndef __CRT__NO_INLINE
  __CRT_INLINE int ua_wcsicmp(LPCUWSTR String1,LPCUWSTR String2) {
    if(WSTR_ALIGNED(String1) && WSTR_ALIGNED(String2))
      return _wcsicmp((LPCWSTR)String1,(LPCWSTR)String2);
    return uaw_wcsicmp(String1,String2);
  }
#endif /* !__CRT__NO_INLINE */
#endif /* _WSTRING_DEFINED */

#ifndef __UA_WCSLEN
#define __UA_WCSLEN ua_wcslen
#endif

#define __UA_WSTRSIZE(s) ((__UA_WCSLEN(s)+1)*sizeof(WCHAR))
#define __UA_STACKCOPY(p,s) memcpy(_alloca(s),p,s)

#if defined (__x86_64__) || defined (__arm__) || defined (_X86_)
#define WSTR_ALIGNED_STACK_COPY(d,s) (*(d) = (PCWSTR)(s))
#else
#define WSTR_ALIGNED_STACK_COPY(d,s) { PCUWSTR __ua_src; ULONG __ua_size; PWSTR __ua_dst; __ua_src = (s); if(WSTR_ALIGNED(__ua_src)) { __ua_dst = (PWSTR)__ua_src; } else { __ua_size = __UA_WSTRSIZE(__ua_src); __ua_dst = (PWSTR)_alloca(__ua_size); memcpy(__ua_dst,__ua_src,__ua_size); } *(d) = (PCWSTR)__ua_dst; }
#endif

#define ASTR_ALIGNED_STACK_COPY(d,s) (*(d) = (PCSTR)(s))

#if !defined (_X86_) && !defined (__x86_64__) && !defined (__arm__)
#define __UA_STRUC_ALIGNED(t,s) (((DWORD_PTR)(s) & (TYPE_ALIGNMENT(t)-1))==0)
#define STRUC_ALIGNED_STACK_COPY(t,s) __UA_STRUC_ALIGNED(t,s) ? ((t const *)(s)) : ((t const *)__UA_STACKCOPY((s),sizeof(t)))
#else
#define STRUC_ALIGNED_STACK_COPY(t,s) ((CONST t *)(s))
#endif

#if defined(UNICODE)
#define TSTR_ALIGNED_STACK_COPY(d,s) WSTR_ALIGNED_STACK_COPY(d,s)
#define TSTR_ALIGNED(x) WSTR_ALIGNED(x)
#define ua_CharUpper ua_CharUpperW
#define ua_lstrcmp ua_lstrcmpW
#define ua_lstrcmpi ua_lstrcmpiW
#define ua_lstrlen ua_lstrlenW
#define ua_tcscpy ua_wcscpy
#else
#define TSTR_ALIGNED_STACK_COPY(d,s) ASTR_ALIGNED_STACK_COPY(d,s)
#define TSTR_ALIGNED(x) TRUE
#define ua_CharUpper CharUpperA
#define ua_lstrcmp lstrcmpA
#define ua_lstrcmpi lstrcmpiA
#define ua_lstrlen lstrlenA
#define ua_tcscpy strcpy
#endif

#ifdef __cplusplus
}
#endif

#include <sec_api/stralign_s.h>
#endif
