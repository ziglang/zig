/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_STAT
#define _INC_STAT

#ifndef _WIN32
#error Only Win32 target is supported!
#endif

#include <crtdefs.h>
#include <io.h>

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _CRTIMP
#define _CRTIMP __declspec(dllimport)
#endif

#include <sys/types.h>

#ifdef _USE_32BIT_TIME_T
#ifdef _WIN64
#undef _USE_32BIT_TIME_T
#endif
#endif

#ifndef _TIME32_T_DEFINED
  typedef long __time32_t;
#define _TIME32_T_DEFINED
#endif

#ifndef _TIME64_T_DEFINED
  __MINGW_EXTENSION typedef __int64 __time64_t;
#define _TIME64_T_DEFINED
#endif

#ifndef _TIME_T_DEFINED
#ifdef _USE_32BIT_TIME_T
  typedef __time32_t time_t;
#else
  typedef __time64_t time_t;
#endif
#define _TIME_T_DEFINED
#endif

#ifndef _WCHAR_T_DEFINED
  typedef unsigned short wchar_t;
#define _WCHAR_T_DEFINED
#endif

#include <_mingw_stat64.h>

#define _S_IFMT 0xF000
#define _S_IFDIR 0x4000
#define _S_IFCHR 0x2000
#define _S_IFIFO 0x1000
#define _S_IFREG 0x8000
#define _S_IREAD 0x0100
#define _S_IWRITE 0x0080
#define _S_IEXEC 0x0040

  _CRTIMP int __cdecl _fstat32(int _FileDes,struct _stat32 *_Stat);
  _CRTIMP int __cdecl _stat32(const char *_Name,struct _stat32 *_Stat);
  _CRTIMP int __cdecl _fstat64(int _FileDes,struct _stat64 *_Stat);
  _CRTIMP int __cdecl _fstat32i64(int _FileDes,struct _stat32i64 *_Stat);
  int __cdecl _fstat64i32(int _FileDes,struct _stat64i32 *_Stat);
#ifndef __CRT__NO_INLINE
  __CRT_INLINE int __cdecl _fstat64i32(int _FileDes,struct _stat64i32 *_Stat)
  {
    struct _stat64 st;
    int __ret=_fstat64(_FileDes,&st);
    if (__ret == -1) {
      memset(_Stat,0,sizeof(struct _stat64i32));
      return -1;
    }
    _Stat->st_dev=st.st_dev;
    _Stat->st_ino=st.st_ino;
    _Stat->st_mode=st.st_mode;
    _Stat->st_nlink=st.st_nlink;
    _Stat->st_uid=st.st_uid;
    _Stat->st_gid=st.st_gid;
    _Stat->st_rdev=st.st_rdev;
    _Stat->st_size=(_off_t) st.st_size;
    _Stat->st_atime=st.st_atime;
    _Stat->st_mtime=st.st_mtime;
    _Stat->st_ctime=st.st_ctime;
    return __ret;
  }
#endif /* __CRT__NO_INLINE */
  _CRTIMP int __cdecl _stat64(const char *_Name,struct _stat64 *_Stat);
  _CRTIMP int __cdecl _stat32i64(const char *_Name,struct _stat32i64 *_Stat);
  int __cdecl _stat64i32(const char *_Name,struct _stat64i32 *_Stat);
#ifndef __CRT__NO_INLINE
  __CRT_INLINE int __cdecl _stat64i32(const char *_Name,struct _stat64i32 *_Stat)
  {
    struct _stat64 st;
    int __ret=_stat64(_Name,&st);
    if (__ret == -1) {
      memset(_Stat,0,sizeof(struct _stat64i32));
      return -1;
    }
    _Stat->st_dev=st.st_dev;
    _Stat->st_ino=st.st_ino;
    _Stat->st_mode=st.st_mode;
    _Stat->st_nlink=st.st_nlink;
    _Stat->st_uid=st.st_uid;
    _Stat->st_gid=st.st_gid;
    _Stat->st_rdev=st.st_rdev;
    _Stat->st_size=(_off_t) st.st_size;
    _Stat->st_atime=st.st_atime;
    _Stat->st_mtime=st.st_mtime;
    _Stat->st_ctime=st.st_ctime;
    return __ret;
  }
#endif /* __CRT__NO_INLINE */

#ifndef _WSTAT_DEFINED
#define _WSTAT_DEFINED
  _CRTIMP int __cdecl _wstat32(const wchar_t *_Name,struct _stat32 *_Stat);
  _CRTIMP int __cdecl _wstat32i64(const wchar_t *_Name,struct _stat32i64 *_Stat);
  int __cdecl _wstat64i32(const wchar_t *_Name,struct _stat64i32 *_Stat);
  _CRTIMP int __cdecl _wstat64(const wchar_t *_Name,struct _stat64 *_Stat);
#endif

#ifndef	NO_OLDNAMES
#define	_S_IFBLK	0x3000	/* Block: Is this ever set under w32? */

#define S_IFMT _S_IFMT
#define S_IFDIR _S_IFDIR
#define S_IFCHR _S_IFCHR
#define S_IFREG _S_IFREG
#define S_IREAD _S_IREAD
#define S_IWRITE _S_IWRITE
#define S_IEXEC _S_IEXEC
#define	S_IFIFO		_S_IFIFO
#define	S_IFBLK		_S_IFBLK

#define	_S_IRWXU	(_S_IREAD | _S_IWRITE | _S_IEXEC)
#define	_S_IXUSR	_S_IEXEC
#define	_S_IWUSR	_S_IWRITE

#define	S_IRWXU		_S_IRWXU
#define	S_IXUSR		_S_IXUSR
#define	S_IWUSR		_S_IWUSR
#define	S_IRUSR		_S_IRUSR
#define	_S_IRUSR	_S_IREAD

#define S_IRGRP    (S_IRUSR >> 3)
#define S_IWGRP    (S_IWUSR >> 3)
#define S_IXGRP    (S_IXUSR >> 3)
#define S_IRWXG    (S_IRWXU >> 3)

#define S_IROTH    (S_IRGRP >> 3)
#define S_IWOTH    (S_IWGRP >> 3)
#define S_IXOTH    (S_IXGRP >> 3)
#define S_IRWXO    (S_IRWXG >> 3)

#define	S_ISDIR(m)	(((m) & S_IFMT) == S_IFDIR)
#define	S_ISFIFO(m)	(((m) & S_IFMT) == S_IFIFO)
#define	S_ISCHR(m)	(((m) & S_IFMT) == S_IFCHR)
#define	S_ISBLK(m)	(((m) & S_IFMT) == S_IFBLK)
#define	S_ISREG(m)	(((m) & S_IFMT) == S_IFREG)

#endif

#if !defined (RC_INVOKED) && !defined (NO_OLDNAMES)
int __cdecl fstat(int _Desc,struct stat *_Stat);
#ifdef _UCRT
  __mingw_ovr int __cdecl stat(const char *_Filename,struct stat *_Stat)
  {
    return _stat(_Filename, (struct _stat *)_Stat);
  }
  __mingw_ovr int __cdecl wstat(const wchar_t *_Filename,struct stat *_Stat)
  {
    return _wstat(_Filename, (struct _stat *)_Stat);
  }
#else
int __cdecl stat(const char *_Filename,struct stat *_Stat);
int __cdecl wstat(const wchar_t *_Filename,struct stat *_Stat);
#endif

#ifndef __CRT__NO_INLINE
#ifdef _USE_32BIT_TIME_T
__CRT_INLINE int __cdecl
 fstat(int _Desc,struct stat *_Stat) {
  struct _stat32 st;
  int __ret=_fstat32(_Desc,&st);
  if (__ret == -1) {
    memset(_Stat,0,sizeof(struct stat));
    return -1;
  }
  /* struct stat and struct _stat32
     are the same for this case. */
  memcpy(_Stat, &st, sizeof(struct _stat32));
  return __ret;
}
/* Disable it for making sure trailing slash issue is fixed.  */
#if 0
__CRT_INLINE int __cdecl
 stat(const char *_Filename,struct stat *_Stat) {
  struct _stat32 st;
  int __ret=_stat32(_Filename,&st);
  if (__ret == -1) {
    memset(_Stat,0,sizeof(struct stat));
    return -1;
  }
  /* struct stat and struct _stat32
     are the same for this case. */
  memcpy(_Stat, &st, sizeof(struct _stat32));
  return __ret;
}
#endif
#else
__CRT_INLINE int __cdecl
 fstat(int _Desc,struct stat *_Stat) {
  struct _stat64 st;
  int __ret=_fstat64(_Desc,&st);
  if (__ret == -1) {
    memset(_Stat,0,sizeof(struct stat));
    return -1;
  }
  /* struct stat and struct _stat64i32
     are the same for this case. */
  _Stat->st_dev=st.st_dev;
  _Stat->st_ino=st.st_ino;
  _Stat->st_mode=st.st_mode;
  _Stat->st_nlink=st.st_nlink;
  _Stat->st_uid=st.st_uid;
  _Stat->st_gid=st.st_gid;
  _Stat->st_rdev=st.st_rdev;
  _Stat->st_size=(_off_t) st.st_size;
  _Stat->st_atime=st.st_atime;
  _Stat->st_mtime=st.st_mtime;
  _Stat->st_ctime=st.st_ctime;
  return __ret;
}
/* Disable it for making sure trailing slash issue is fixed.  */
#if 0
__CRT_INLINE int __cdecl
 stat(const char *_Filename,struct stat *_Stat) {
  struct _stat64 st;
  int __ret=_stat64(_Filename,&st);
  if (__ret == -1) {
    memset(_Stat,0,sizeof(struct stat));
    return -1;
  }
  /* struct stat and struct _stat64i32
     are the same for this case. */
  _Stat->st_dev=st.st_dev;
  _Stat->st_ino=st.st_ino;
  _Stat->st_mode=st.st_mode;
  _Stat->st_nlink=st.st_nlink;
  _Stat->st_uid=st.st_uid;
  _Stat->st_gid=st.st_gid;
  _Stat->st_rdev=st.st_rdev;
  _Stat->st_size=(_off_t) st.st_size;
  _Stat->st_atime=st.st_atime;
  _Stat->st_mtime=st.st_mtime;
  _Stat->st_ctime=st.st_ctime;
  return __ret;
}
#endif
#endif /* _USE_32BIT_TIME_T */
#endif /* __CRT__NO_INLINE */
#endif /* !RC_INVOKED && !NO_OLDNAMES */

#if defined(_FILE_OFFSET_BITS) && (_FILE_OFFSET_BITS == 64)
#ifdef _USE_32BIT_TIME_T
#define stat _stat32i64
#define fstat _fstat32i64
#else
#define stat _stat64
#define fstat _fstat64
#endif
#endif

#ifdef __cplusplus
}
#endif

#pragma pack(pop)

#endif /* _INC_STAT */

