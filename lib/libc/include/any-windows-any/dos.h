/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_DOS
#define _INC_DOS

#include <crtdefs.h>
#include <io.h>

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _CRT_USE_WINAPI_FAMILY_DESKTOP_APP
#ifndef _DISKFREE_T_DEFINED
#define _DISKFREE_T_DEFINED

  struct _diskfree_t {
    unsigned total_clusters;
    unsigned avail_clusters;
    unsigned sectors_per_cluster;
    unsigned bytes_per_sector;
  };
#endif

#define _A_NORMAL 0x00
#define _A_RDONLY 0x01
#define _A_HIDDEN 0x02
#define _A_SYSTEM 0x04
#define _A_VOLID  0x08
#define _A_SUBDIR 0x10
#define _A_ARCH   0x20

#ifndef _GETDISKFREE_DEFINED
#define _GETDISKFREE_DEFINED
  _CRTIMP unsigned __cdecl _getdiskfree(unsigned _Drive,struct _diskfree_t *_DiskFree);
#endif
#endif /* _CRT_USE_WINAPI_FAMILY_DESKTOP_APP */

#if (defined(_X86_) && !defined(__x86_64))
  void __cdecl _disable(void);
  void __cdecl _enable(void);
#endif

#ifndef	NO_OLDNAMES
#define diskfree_t _diskfree_t
#endif

#ifdef __cplusplus
}
#endif

#pragma pack(pop)
#endif
