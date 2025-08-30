/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_DIRECT
#define _INC_DIRECT

#include <crtdefs.h>
#include <io.h>

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _DISKFREE_T_DEFINED
#define _DISKFREE_T_DEFINED
  struct _diskfree_t {
    unsigned total_clusters;
    unsigned avail_clusters;
    unsigned sectors_per_cluster;
    unsigned bytes_per_sector;
  };
#endif

#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma push_macro("_getcwd")
#undef _getcwd
#pragma push_macro("_getdcwd")
#undef _getdcwd
#pragma push_macro("_getdcwd_nolock")
#undef _getdcwd_nolock
#endif
  _CRTIMP char *__cdecl _getcwd(char *_DstBuf,int _SizeInBytes);
  _CRTIMP char *__cdecl _getdcwd(int _Drive,char *_DstBuf,int _SizeInBytes);
#if __MSVCRT_VERSION__ >= 0x800
  char *__cdecl _getdcwd_nolock(int _Drive,char *_DstBuf,int _SizeInBytes);
#endif
#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma pop_macro("_getcwd")
#pragma pop_macro("_getdcwd")
#pragma pop_macro("_getdcwd_nolock")
#endif
  _CRTIMP int __cdecl _chdir(const char *_Path);
  _CRTIMP int __cdecl _mkdir(const char *_Path);
  _CRTIMP int __cdecl _rmdir(const char *_Path);
#ifdef _CRT_USE_WINAPI_FAMILY_DESKTOP_APP
  _CRTIMP int __cdecl _chdrive(int _Drive);
  _CRTIMP int __cdecl _getdrive(void);
  _CRTIMP unsigned long __cdecl _getdrives(void);

#ifndef _GETDISKFREE_DEFINED
#define _GETDISKFREE_DEFINED
  _CRTIMP unsigned __cdecl _getdiskfree(unsigned _Drive,struct _diskfree_t *_DiskFree);
#endif
#endif /* _CRT_USE_WINAPI_FAMILY_DESKTOP_APP */

#ifndef _WDIRECT_DEFINED
#define _WDIRECT_DEFINED
#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma push_macro("_wgetcwd")
#undef _wgetcwd
#pragma push_macro("_wgetdcwd")
#undef _wgetdcwd
#pragma push_macro("_wgetdcwd_nolock")
#undef _wgetdcwd_nolock
#endif
  _CRTIMP wchar_t *__cdecl _wgetcwd(wchar_t *_DstBuf,int _SizeInWords);
  _CRTIMP wchar_t *__cdecl _wgetdcwd(int _Drive,wchar_t *_DstBuf,int _SizeInWords);
#if __MSVCRT_VERSION__ >= 0x800
  wchar_t *__cdecl _wgetdcwd_nolock(int _Drive,wchar_t *_DstBuf,int _SizeInWords);
#endif
#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma pop_macro("_wgetcwd")
#pragma pop_macro("_wgetdcwd")
#pragma pop_macro("_wgetdcwd_nolock")
#endif
  _CRTIMP int __cdecl _wchdir(const wchar_t *_Path);
  _CRTIMP int __cdecl _wmkdir(const wchar_t *_Path);
  _CRTIMP int __cdecl _wrmdir(const wchar_t *_Path);
#endif

#ifndef	NO_OLDNAMES

#define diskfree_t _diskfree_t

#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma push_macro("getcwd")
#undef getcwd
#endif
  char *__cdecl getcwd(char *_DstBuf,int _SizeInBytes) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma pop_macro("getcwd")
#endif
  int __cdecl chdir(const char *_Path) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl mkdir(const char *_Path) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl rmdir(const char *_Path) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif

#ifdef __cplusplus
}
#endif

#pragma pack(pop)
#endif
