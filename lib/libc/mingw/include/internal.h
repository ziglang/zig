/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_INTERNAL
#define _INC_INTERNAL

#include <crtdefs.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <limits.h>
#include <windows.h>

#pragma pack(push,_CRT_PACKING)

#define __IOINFO_TM_ANSI 0
#define __IOINFO_TM_UTF8 1
#define __IOINFO_TM_UTF16LE 2

#ifdef _MSC_VER
#pragma warning(push)
#pragma warning(disable:4214)
#pragma warning(disable:4820)
#endif

  typedef struct {
    intptr_t osfhnd;
    char osfile;
    char pipech;
    int lockinitflag;
    CRITICAL_SECTION lock;
    char textmode : 7;
    char unicode : 1;
    char pipech2[2];
  } ioinfo;

#ifdef _MSC_VER
#pragma warning(pop)
#endif

#define IOINFO_ARRAY_ELTS (1 << 5)

#define _pioinfo(i) (__pioinfo[(i) >> 5] + ((i) & (IOINFO_ARRAY_ELTS - 1)))
#define _osfile(i) (_pioinfo(i)->osfile)
#define _pipech2(i) (_pioinfo(i)->pipech2)
#define _textmode(i) (_pioinfo(i)->textmode)
#define _tm_unicode(i) (_pioinfo(i)->unicode)
#define _pioinfo_safe(i) ((((i) != -1) && ((i) != -2)) ? _pioinfo(i) : &__badioinfo)
#define _osfhnd_safe(i) (_pioinfo_safe(i)->osfhnd)
#define _osfile_safe(i) (_pioinfo_safe(i)->osfile)
#define _pipech_safe(i) (_pioinfo_safe(i)->pipech)
#define _pipech2_safe(i) (_pioinfo_safe(i)->pipech2)
#define _textmode_safe(i) (_pioinfo_safe(i)->textmode)
#define _tm_unicode_safe(i) (_pioinfo_safe(i)->unicode)

#ifndef __badioinfo
  extern ioinfo ** __MINGW_IMP_SYMBOL(__badioinfo)[];
#define __badioinfo (* __MINGW_IMP_SYMBOL(__badioinfo))
#endif

#ifndef __pioinfo
  extern ioinfo ** __MINGW_IMP_SYMBOL(__pioinfo)[];
#define __pioinfo (* __MINGW_IMP_SYMBOL(__pioinfo))
#endif

#define _NO_CONSOLE_FILENO (intptr_t)-2

#ifndef _FILE_DEFINED
#define _FILE_DEFINED
  struct _iobuf {
    char *_ptr;
    int _cnt;
    char *_base;
    int _flag;
    int _file;
    int _charbuf;
    int _bufsiz;
    char *_tmpfname;
  };
  typedef struct _iobuf FILE;
#endif

#if !defined (_FILEX_DEFINED) && defined (_WINDOWS_)
#define _FILEX_DEFINED
  typedef struct {
    FILE f;
    CRITICAL_SECTION lock;
  } _FILEX;
#endif

  extern int _dowildcard;
  extern int _newmode;

#ifndef __winitenv
extern wchar_t *** __MINGW_IMP_SYMBOL(__winitenv);
#define __winitenv (* __MINGW_IMP_SYMBOL(__winitenv))
#endif

#if !defined(__initenv) && !defined(__arm__)
extern char *** __MINGW_IMP_SYMBOL(__initenv);
#define __initenv (* __MINGW_IMP_SYMBOL(__initenv))
#endif

  _CRTIMP void __cdecl _amsg_exit(int);

  int __CRTDECL _setargv(void);
  int __CRTDECL __setargv(void);
  int __CRTDECL _wsetargv(void);
  int __CRTDECL __wsetargv(void);

  int __CRTDECL main(int _Argc, char **_Argv, char **_Env);
  int __CRTDECL wmain(int _Argc, wchar_t **_Argv, wchar_t **_Env);

#ifndef _STARTUP_INFO_DEFINED
#define _STARTUP_INFO_DEFINED
  typedef struct {
    int newmode;
  } _startupinfo;
#endif

  _CRTIMP int __cdecl __getmainargs(int * _Argc, char *** _Argv, char ***_Env, int _DoWildCard, _startupinfo *_StartInfo);
  _CRTIMP int __cdecl __wgetmainargs(int * _Argc, wchar_t ***_Argv, wchar_t ***_Env, int _DoWildCard, _startupinfo *_StartInfo);

#define _CONSOLE_APP 1
#define _GUI_APP 2

  typedef enum __enative_startup_state {
    __uninitialized = 0, __initializing, __initialized
  } __enative_startup_state;

  extern volatile __enative_startup_state __native_startup_state;
  extern volatile void *__native_startup_lock;

  extern volatile unsigned int __native_dllmain_reason;
  extern volatile unsigned int __native_vcclrit_reason;

  _CRTIMP void __cdecl __set_app_type (int);

  typedef LONG NTSTATUS;

#include <crtdbg.h>
#include <errno.h>

  BOOL __cdecl _ValidateImageBase (PBYTE pImageBase);
  PIMAGE_SECTION_HEADER __cdecl _FindPESection (PBYTE pImageBase, DWORD_PTR rva);
  BOOL __cdecl _IsNonwritableInCurrentImage (PBYTE pTarget);

#ifdef __cplusplus
}
#endif

#pragma pack(pop)
#endif
