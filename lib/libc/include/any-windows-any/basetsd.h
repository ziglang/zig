/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#include <_mingw.h>

#ifndef _BASETSD_H_
#define _BASETSD_H_

#if (defined (__x86_64__) || defined (__ia64__)) && !(defined (__WIDL__) || defined (RC_INVOKED))
__MINGW_EXTENSION typedef unsigned __int64 POINTER_64_INT;
#else
typedef unsigned long POINTER_64_INT;
#endif

#define POINTER_32
#define POINTER_64
#define FIRMWARE_PTR

#define POINTER_SIGNED
#define POINTER_UNSIGNED
#define SPOINTER_32 POINTER_SIGNED POINTER_32
#define UPOINTER_32 POINTER_UNSIGNED POINTER_32

#ifdef __cplusplus
extern "C" {
#endif

  typedef signed char INT8,*PINT8;
  typedef signed short INT16,*PINT16;
  typedef signed int INT32,*PINT32;
  __MINGW_EXTENSION typedef signed __int64 INT64,*PINT64;
  typedef unsigned char UINT8,*PUINT8;
  typedef unsigned short UINT16,*PUINT16;
  typedef unsigned int UINT32,*PUINT32;
  __MINGW_EXTENSION typedef unsigned __int64 UINT64,*PUINT64;
  typedef signed int LONG32,*PLONG32;
  typedef unsigned int ULONG32,*PULONG32;
  typedef unsigned int DWORD32,*PDWORD32;

#ifndef _W64
#define _W64
#endif

#ifdef _WIN64
  __MINGW_EXTENSION typedef __int64 INT_PTR,*PINT_PTR;
  __MINGW_EXTENSION typedef unsigned __int64 UINT_PTR,*PUINT_PTR;
  __MINGW_EXTENSION typedef __int64 LONG_PTR,*PLONG_PTR;
  __MINGW_EXTENSION typedef unsigned __int64 ULONG_PTR,*PULONG_PTR;
#define __int3264 __int64
#else
  typedef int INT_PTR,*PINT_PTR;
  typedef unsigned int UINT_PTR,*PUINT_PTR;
  typedef long LONG_PTR,*PLONG_PTR;
  typedef unsigned long ULONG_PTR,*PULONG_PTR;
#define __int3264 int
#endif

#ifdef _WIN64
#define ADDRESS_TAG_BIT 0x40000000000ULL

  __MINGW_EXTENSION typedef __int64 SHANDLE_PTR;
  __MINGW_EXTENSION typedef unsigned __int64 HANDLE_PTR;
  typedef unsigned int UHALF_PTR,*PUHALF_PTR;
  typedef int HALF_PTR,*PHALF_PTR;

#ifndef __WIDL__
  static __inline unsigned __LONG32 HandleToULong (const void *h) { return ((unsigned __LONG32) (ULONG_PTR) h); }
  static __inline __LONG32 HandleToLong (const void *h) { return ((__LONG32) (LONG_PTR) h); }
  static __inline void *ULongToHandle (const unsigned __LONG32 h) { return ((void *) (UINT_PTR) h); }
  static __inline void *LongToHandle (const __LONG32 h) { return ((void *) (INT_PTR) h); }
  static __inline unsigned __LONG32 PtrToUlong (const void *p) { return ((unsigned __LONG32) (ULONG_PTR) p); }
  static __inline unsigned int PtrToUint (const void *p) { return ((unsigned int) (UINT_PTR) p); }
  static __inline unsigned short PtrToUshort (const void *p) { return ((unsigned short) (unsigned __LONG32) (ULONG_PTR) p); }
  static __inline __LONG32 PtrToLong (const void *p) { return ((__LONG32) (LONG_PTR) p); }
  static __inline int PtrToInt (const void *p) { return ((int) (INT_PTR) p); }
  static __inline short PtrToShort (const void *p) { return ((short) (__LONG32) (LONG_PTR) p); }
  static __inline void *IntToPtr (const int i) { return ((void *) (INT_PTR)i); }
  static __inline void *UIntToPtr (const unsigned int ui) { return ((void *) (UINT_PTR)ui); }
  static __inline void *LongToPtr (const __LONG32 l) { return ((void *) (LONG_PTR)l); }
  static __inline void *ULongToPtr (const unsigned __LONG32 ul) { return ((void *) (ULONG_PTR)ul); }

#define PtrToPtr64(p) ((void *POINTER_64) p)
#define Ptr64ToPtr(p) ((void *) p)
#define HandleToHandle64(h) (PtrToPtr64 (h))
#define Handle64ToHandle(h) (Ptr64ToPtr (h))

  static __inline void *Ptr32ToPtr (const void *POINTER_32 p) { return ((void *) (ULONG_PTR) (unsigned __LONG32) (ULONG_PTR) p); }
  static __inline void *Handle32ToHandle (const void *POINTER_32 h) { return ((void *) (LONG_PTR) (__LONG32) (ULONG_PTR) h); }
  static __inline void *POINTER_32 PtrToPtr32 (const void *p) { return ((void *POINTER_32) (ULONG_PTR) (unsigned __LONG32) (ULONG_PTR) p); }

#define HandleToHandle32(h) (PtrToPtr32 (h))
#endif
#else
#define ADDRESS_TAG_BIT __MSABI_LONG (0x80000000U)

  typedef unsigned short UHALF_PTR,*PUHALF_PTR;
  typedef short HALF_PTR,*PHALF_PTR;
  typedef __LONG32 SHANDLE_PTR;
  typedef unsigned __LONG32 HANDLE_PTR;

#define HandleToULong(h) ((ULONG) (ULONG_PTR) (h))
#define HandleToLong(h) ((LONG) (LONG_PTR) (h))
#define ULongToHandle(ul) ((HANDLE) (ULONG_PTR) (ul))
#define LongToHandle(h) ((HANDLE) (LONG_PTR) (h))
#define PtrToUlong(p) ((ULONG) (ULONG_PTR) (p))
#define PtrToLong(p) ((LONG) (LONG_PTR) (p))
#define PtrToUint(p) ((UINT) (UINT_PTR) (p))
#define PtrToInt(p) ((INT) (INT_PTR) (p))
#define PtrToUshort(p) ((unsigned short) (ULONG_PTR) (p))
#define PtrToShort(p) ((short) (LONG_PTR) (p))
#define IntToPtr(i) ((VOID *) (INT_PTR) ((int)i))
#define UIntToPtr(ui) ((VOID *) (UINT_PTR) ((unsigned int)ui))
#define LongToPtr(l) ((VOID *) (LONG_PTR) ((__LONG32) l))
#define ULongToPtr(ul) ((VOID *) (ULONG_PTR) ((unsigned __LONG32) ul))

#ifndef __WIDL__
  static __inline void *POINTER_64 PtrToPtr64 (const void *p) { return ((void *POINTER_64) (ULONG_PTR) p); }
  static __inline void *Ptr64ToPtr (const void *POINTER_64 p) { return ((void *) (ULONG_PTR) p); }
  static __inline void *POINTER_64 HandleToHandle64 (const void *h) { return ((void *POINTER_64) (LONG_PTR) h); }
  static __inline void *Handle64ToHandle (const void *POINTER_64 h) { return ((void *) (ULONG_PTR) h); }
#endif

#define Ptr32ToPtr(p) ((void *) p)
#define Handle32ToHandle(h) (Ptr32ToPtr (h))
#define PtrToPtr32(p) ((void *POINTER_32) p)
#define HandleToHandle32(h) (PtrToPtr32 (h))
#endif

#define HandleToUlong(h) HandleToULong (h)
#define UlongToHandle(ul) ULongToHandle (ul)
#define UlongToPtr(ul) ULongToPtr (ul)
#define UintToPtr(ui) UIntToPtr (ui)

#define MAXUINT_PTR (~ ((UINT_PTR)0))
#define MAXINT_PTR ((INT_PTR) (MAXUINT_PTR >> 1))
#define MININT_PTR (~MAXINT_PTR)

#define MAXULONG_PTR (~ ((ULONG_PTR)0))
#define MAXLONG_PTR ((LONG_PTR) (MAXULONG_PTR >> 1))
#define MINLONG_PTR (~MAXLONG_PTR)

#define MAXUHALF_PTR ((UHALF_PTR)~0)
#define MAXHALF_PTR ((HALF_PTR) (MAXUHALF_PTR >> 1))
#define MINHALF_PTR (~MAXHALF_PTR)

  __MINGW_EXTENSION typedef ULONG_PTR SIZE_T,*PSIZE_T;
  __MINGW_EXTENSION typedef LONG_PTR SSIZE_T,*PSSIZE_T;

#if _WIN32_WINNT >= 0x0600 || (defined (__cplusplus) && defined (WINDOWS_ENABLE_CPLUSPLUS))

#define MAXUINT8 ((UINT8)~ ((UINT8)0))
#define MAXINT8 ((INT8) (MAXUINT8 >> 1))
#define MININT8 ((INT8)~MAXINT8)

#define MAXUINT16 ((UINT16)~ ((UINT16)0))
#define MAXINT16 ((INT16) (MAXUINT16 >> 1))
#define MININT16 ((INT16)~MAXINT16)

#define MAXUINT32 ((UINT32)~ ((UINT32)0))
#define MAXINT32 ((INT32) (MAXUINT32 >> 1))
#define MININT32 ((INT32)~MAXINT32)

#define MAXUINT64 ((UINT64)~ ((UINT64)0))
#define MAXINT64 ((INT64) (MAXUINT64 >> 1))
#define MININT64 ((INT64)~MAXINT64)

#define MAXULONG32 ((ULONG32)~ ((ULONG32)0))
#define MAXLONG32 ((LONG32) (MAXULONG32 >> 1))
#define MINLONG32 ((LONG32)~MAXLONG32)

#define MAXULONG64 ((ULONG64)~ ((ULONG64)0))
#define MAXLONG64 ((LONG64) (MAXULONG64 >> 1))
#define MINLONG64 ((LONG64)~MAXLONG64)

#define MAXULONGLONG ((ULONGLONG)~ ((ULONGLONG)0))
#define MINLONGLONG ((LONGLONG)~MAXLONGLONG)

#define MAXSIZE_T ((SIZE_T)~ ((SIZE_T)0))
#define MAXSSIZE_T ((SSIZE_T) (MAXSIZE_T >> 1))
#define MINSSIZE_T ((SSIZE_T)~MAXSSIZE_T)

#define MAXUINT ((UINT)~ ((UINT)0))
#define MAXINT ((INT) (MAXUINT >> 1))
#define MININT ((INT)~MAXINT)

#define MAXDWORD32 ((DWORD32)~ ((DWORD32)0))
#define MAXDWORD64 ((DWORD64)~ ((DWORD64)0))
#endif

  __MINGW_EXTENSION typedef ULONG_PTR DWORD_PTR,*PDWORD_PTR;
  __MINGW_EXTENSION typedef __int64 LONG64,*PLONG64;
  __MINGW_EXTENSION typedef unsigned __int64 ULONG64,*PULONG64;
  __MINGW_EXTENSION typedef unsigned __int64 DWORD64,*PDWORD64;
  __MINGW_EXTENSION typedef ULONG_PTR KAFFINITY;
  __MINGW_EXTENSION typedef KAFFINITY *PKAFFINITY;

#ifdef __cplusplus
}
#endif
#endif
