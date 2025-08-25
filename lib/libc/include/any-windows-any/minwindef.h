#ifndef _MINWINDEF_
#define _MINWINDEF_

#include <_mingw.h>
#include <winapifamily.h>
#include <specstrings.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)

#if !defined (STRICT) && !defined (NO_STRICT)
#define STRICT 1
#endif

#ifndef WIN32
#define WIN32
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef BASETYPES
#define BASETYPES
  typedef unsigned __LONG32 ULONG;
  typedef ULONG *PULONG;
  typedef unsigned short USHORT;
  typedef USHORT *PUSHORT;
  typedef unsigned char UCHAR;
  typedef UCHAR *PUCHAR;
  typedef char *PSZ;
#endif

#define MAX_PATH 260

#ifndef NULL
#ifdef __cplusplus
#ifndef _WIN64
#define NULL 0
#else
#define NULL 0LL
#endif
#else
#define NULL ((void *)0)
#endif
#endif

#ifndef FALSE
#define FALSE 0
#endif

#ifndef TRUE
#define TRUE 1
#endif

#ifndef _NO_W32_PSEUDO_MODIFIERS
#ifndef IN
#define IN
#endif

#ifndef OUT
#define OUT
#endif

#ifndef OPTIONAL
#define OPTIONAL
#endif
#endif /* _NO_W32_PSEUDO_MODIFIERS */

#undef far
#undef near
#undef pascal

#define far
#define near
#if defined(_ARM_)
#define pascal
#else
#define pascal __stdcall
#endif

#define cdecl
#ifndef CDECL
#define CDECL
#endif

#ifndef CALLBACK
#if defined(_ARM_)
#define CALLBACK
#else
#define CALLBACK __stdcall
#endif
#endif

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

#define WINAPIV __cdecl
#define APIENTRY WINAPI
#if defined(_ARM_)
#define APIPRIVATE
#define PASCAL
#else
#define APIPRIVATE __stdcall
#define PASCAL __stdcall
#endif

#ifndef WINAPI_INLINE
#define WINAPI_INLINE WINAPI
#endif

#undef FAR
#undef NEAR
#define FAR
#define NEAR

#ifndef CONST
#define CONST const
#endif

#ifndef _DEF_WINBOOL_
#define _DEF_WINBOOL_
typedef int WINBOOL;
#pragma push_macro("BOOL")
#undef BOOL
#if !defined(__OBJC__) && !defined(__OBJC_BOOL) && !defined(__objc_INCLUDE_GNU) && !defined(_NO_BOOL_TYPEDEF)
  typedef int BOOL;
#endif
#define BOOL WINBOOL
typedef BOOL *PBOOL;
typedef BOOL *LPBOOL;
#pragma pop_macro("BOOL")
#endif /* _DEF_WINBOOL_ */

  typedef unsigned char BYTE;
  typedef unsigned short WORD;
  typedef unsigned __LONG32 DWORD;
  typedef float FLOAT;
  typedef FLOAT *PFLOAT;
  typedef BYTE *PBYTE;
  typedef BYTE *LPBYTE;
  typedef int *PINT;
  typedef int *LPINT;
  typedef WORD *PWORD;
  typedef WORD *LPWORD;
  typedef __LONG32 *LPLONG;
  typedef DWORD *PDWORD;
  typedef DWORD *LPDWORD;
  typedef void *LPVOID;
#ifndef _LPCVOID_DEFINED
#define _LPCVOID_DEFINED
  typedef CONST void *LPCVOID;
#endif
  typedef int INT;
  typedef unsigned int UINT;
  typedef unsigned int *PUINT;

#ifndef NT_INCLUDED
#include <winnt.h>
#endif

  typedef UINT_PTR WPARAM;
  typedef LONG_PTR LPARAM;
  typedef LONG_PTR LRESULT;

#ifndef __cplusplus
#ifndef NOMINMAX
#ifndef max
#define max(a, b) (((a) > (b)) ? (a) : (b))
#endif

#ifndef min
#define min(a, b) (((a) < (b)) ? (a) : (b))
#endif
#endif
#endif

#define MAKEWORD(a,b) ((WORD) (((BYTE) (((DWORD_PTR) (a)) & 0xff)) | ((WORD) ((BYTE) (((DWORD_PTR) (b)) & 0xff))) << 8))
#define MAKELONG(a, b) ((LONG) (((WORD) (((DWORD_PTR) (a)) & 0xffff)) | ((DWORD) ((WORD) (((DWORD_PTR) (b)) & 0xffff))) << 16))
#define LOWORD(l) ((WORD) (((DWORD_PTR) (l)) & 0xffff))
#define HIWORD(l) ((WORD) ((((DWORD_PTR) (l)) >> 16) & 0xffff))
#define LOBYTE(w) ((BYTE) (((DWORD_PTR) (w)) & 0xff))
#define HIBYTE(w) ((BYTE) ((((DWORD_PTR) (w)) >> 8) & 0xff))

  typedef HANDLE *SPHANDLE;
  typedef HANDLE *LPHANDLE;
  typedef HANDLE HGLOBAL;
  typedef HANDLE HLOCAL;
  typedef HANDLE GLOBALHANDLE;
  typedef HANDLE LOCALHANDLE;
#ifdef _WIN64
  typedef INT_PTR (WINAPI *FARPROC) ();
  typedef INT_PTR (WINAPI *NEARPROC) ();
  typedef INT_PTR (WINAPI *PROC) ();
#else
  typedef int (WINAPI *FARPROC) ();
  typedef int (WINAPI *NEARPROC) ();
  typedef int (WINAPI *PROC) ();
#endif

  typedef WORD ATOM;

  typedef int HFILE;
  DECLARE_HANDLE (HINSTANCE);
  DECLARE_HANDLE (HKEY);
  typedef HKEY *PHKEY;
  DECLARE_HANDLE (HKL);
  DECLARE_HANDLE (HLSURF);
  DECLARE_HANDLE (HMETAFILE);
  typedef HINSTANCE HMODULE;
  DECLARE_HANDLE (HRGN);
  DECLARE_HANDLE (HRSRC);
  DECLARE_HANDLE (HSPRITE);
  DECLARE_HANDLE (HSTR);
  DECLARE_HANDLE (HTASK);
  DECLARE_HANDLE (HWINSTA);

  typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
  } FILETIME,*PFILETIME,*LPFILETIME;
#define _FILETIME_

#ifdef __cplusplus
}
#endif

#endif
#endif
