/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_PROCESS
#define _INC_PROCESS

#include <crtdefs.h>
#include <corecrt_startup.h>

/* Includes a definition of _pid_t and pid_t */
#include <sys/types.h>

#ifndef _POSIX_
#ifdef __cplusplus
extern "C" {
#endif

#ifndef _P_WAIT
#define _P_WAIT 0
#define _P_NOWAIT 1
#define _OLD_P_OVERLAY 2
#define _P_NOWAITO 3
#define _P_DETACH 4
#define _P_OVERLAY 2

#define _WAIT_CHILD 0
#define _WAIT_GRANDCHILD 1
#endif

  typedef void (__cdecl *_beginthread_proc_type)(void *);
  typedef unsigned (__stdcall *_beginthreadex_proc_type)(void *);

  _CRTIMP uintptr_t __cdecl _beginthread(_beginthread_proc_type _StartAddress,unsigned _StackSize,void *_ArgList);
  _CRTIMP void __cdecl _endthread(void) __MINGW_ATTRIB_NORETURN;
  _CRTIMP uintptr_t __cdecl _beginthreadex(void *_Security,unsigned _StackSize,_beginthreadex_proc_type _StartAddress,void *_ArgList,unsigned _InitFlag,unsigned *_ThrdAddr);
  _CRTIMP void __cdecl _endthreadex(unsigned _Retval) __MINGW_ATTRIB_NORETURN;

#ifndef _CRT_TERMINATE_DEFINED
#define _CRT_TERMINATE_DEFINED
  void __cdecl __MINGW_NOTHROW exit(int _Code) __MINGW_ATTRIB_NORETURN;
  void __cdecl __MINGW_NOTHROW _exit(int _Code) __MINGW_ATTRIB_NORETURN;

#if !defined __NO_ISOCEXT /* extern stub in static libmingwex.a */
  /* C99 function name */
  void __cdecl _Exit(int) __MINGW_ATTRIB_NORETURN;
#ifndef __CRT__NO_INLINE
  __CRT_INLINE __MINGW_ATTRIB_NORETURN void  __cdecl _Exit(int status)
  {  _exit(status); }
#endif /* !__CRT__NO_INLINE */
#endif /* Not  __NO_ISOCEXT */

#pragma push_macro("abort")
#undef abort
  void __cdecl __MINGW_ATTRIB_NORETURN abort(void);
#pragma pop_macro("abort")

#endif /* _CRT_TERMINATE_DEFINED */

  typedef void (__stdcall *_tls_callback_type)(void*,unsigned long,void*);
  _CRTIMP void __cdecl _register_thread_local_exe_atexit_callback(_tls_callback_type callback);

  void __cdecl __MINGW_NOTHROW _cexit(void);
  void __cdecl __MINGW_NOTHROW _c_exit(void);
#ifdef _CRT_USE_WINAPI_FAMILY_DESKTOP_APP
  _CRTIMP int __cdecl _getpid(void);
  _CRTIMP intptr_t __cdecl _cwait(int *_TermStat,intptr_t _ProcHandle,int _Action);
  _CRTIMP intptr_t __cdecl _execl(const char *_Filename,const char *_ArgList,...);
  _CRTIMP intptr_t __cdecl _execle(const char *_Filename,const char *_ArgList,...);
  _CRTIMP intptr_t __cdecl _execlp(const char *_Filename,const char *_ArgList,...);
  _CRTIMP intptr_t __cdecl _execlpe(const char *_Filename,const char *_ArgList,...);
  _CRTIMP intptr_t __cdecl _execv(const char *_Filename,const char *const *_ArgList);
  _CRTIMP intptr_t __cdecl _execve(const char *_Filename,const char *const *_ArgList,const char *const *_Env);
  _CRTIMP intptr_t __cdecl _execvp(const char *_Filename,const char *const *_ArgList);
  _CRTIMP intptr_t __cdecl _execvpe(const char *_Filename,const char *const *_ArgList,const char *const *_Env);
  _CRTIMP intptr_t __cdecl _spawnl(int _Mode,const char *_Filename,const char *_ArgList,...);
  _CRTIMP intptr_t __cdecl _spawnle(int _Mode,const char *_Filename,const char *_ArgList,...);
  _CRTIMP intptr_t __cdecl _spawnlp(int _Mode,const char *_Filename,const char *_ArgList,...);
  _CRTIMP intptr_t __cdecl _spawnlpe(int _Mode,const char *_Filename,const char *_ArgList,...);

#ifndef _SPAWNV_DEFINED
#define _SPAWNV_DEFINED
  _CRTIMP intptr_t __cdecl _spawnv(int _Mode,const char *_Filename,const char *const *_ArgList);
  _CRTIMP intptr_t __cdecl _spawnve(int _Mode,const char *_Filename,const char *const *_ArgList,const char *const *_Env);
  _CRTIMP intptr_t __cdecl _spawnvp(int _Mode,const char *_Filename,const char *const *_ArgList);
  _CRTIMP intptr_t __cdecl _spawnvpe(int _Mode,const char *_Filename,const char *const *_ArgList,const char *const *_Env);
#endif

#ifndef _CRT_SYSTEM_DEFINED
#define _CRT_SYSTEM_DEFINED
  int __cdecl system(const char *_Command);
#endif

#ifndef _WEXEC_DEFINED
#define _WEXEC_DEFINED
  _CRTIMP intptr_t __cdecl _wexecl(const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wexecle(const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wexeclp(const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wexeclpe(const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wexecv(const wchar_t *_Filename,const wchar_t *const *_ArgList);
  _CRTIMP intptr_t __cdecl _wexecve(const wchar_t *_Filename,const wchar_t *const *_ArgList,const wchar_t *const *_Env);
  _CRTIMP intptr_t __cdecl _wexecvp(const wchar_t *_Filename,const wchar_t *const *_ArgList);
  _CRTIMP intptr_t __cdecl _wexecvpe(const wchar_t *_Filename,const wchar_t *const *_ArgList,const wchar_t *const *_Env);
#endif

#ifndef _WSPAWN_DEFINED
#define _WSPAWN_DEFINED
  _CRTIMP intptr_t __cdecl _wspawnl(int _Mode,const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wspawnle(int _Mode,const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wspawnlp(int _Mode,const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wspawnlpe(int _Mode,const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wspawnv(int _Mode,const wchar_t *_Filename,const wchar_t *const *_ArgList);
  _CRTIMP intptr_t __cdecl _wspawnve(int _Mode,const wchar_t *_Filename,const wchar_t *const *_ArgList,const wchar_t *const *_Env);
  _CRTIMP intptr_t __cdecl _wspawnvp(int _Mode,const wchar_t *_Filename,const wchar_t *const *_ArgList);
  _CRTIMP intptr_t __cdecl _wspawnvpe(int _Mode,const wchar_t *_Filename,const wchar_t *const *_ArgList,const wchar_t *const *_Env);
#endif

#ifndef _CRT_WSYSTEM_DEFINED
#define _CRT_WSYSTEM_DEFINED
  _CRTIMP int __cdecl _wsystem(const wchar_t *_Command);
#endif
#endif /* _CRT_USE_WINAPI_FAMILY_DESKTOP_APP */

#ifdef _CRT_USE_WINAPI_FAMILY_DESKTOP_APP
  intptr_t __cdecl _loaddll(char *_Filename);
  int __cdecl _unloaddll(intptr_t _Handle);
  int (__cdecl *__cdecl _getdllprocaddr(intptr_t _Handle,char *_ProcedureName,intptr_t _Ordinal))(void);
#endif /* _CRT_USE_WINAPI_FAMILY_DESKTOP_APP */

#ifdef _DECL_DLLMAIN
#ifdef _WINDOWS_
  WINBOOL WINAPI DllMain(HANDLE _HDllHandle,DWORD _Reason,LPVOID _Reserved);
  WINBOOL WINAPI _CRT_INIT(HANDLE _HDllHandle,DWORD _Reason,LPVOID _Reserved);
  WINBOOL WINAPI _wCRT_INIT(HANDLE _HDllHandle,DWORD _Reason,LPVOID _Reserved);
  extern WINBOOL (WINAPI *const _pRawDllMain)(HANDLE,DWORD,LPVOID);
#else
  int __stdcall DllMain(void *_HDllHandle,unsigned _Reason,void *_Reserved);
  int __stdcall _CRT_INIT(void *_HDllHandle,unsigned _Reason,void *_Reserved);
  int __stdcall _wCRT_INIT(void *_HDllHandle,unsigned _Reason,void *_Reserved);
  extern int (__stdcall *const _pRawDllMain)(void *,unsigned,void *);
#endif
#endif

#ifndef	NO_OLDNAMES
#define P_WAIT _P_WAIT
#define P_NOWAIT _P_NOWAIT
#define P_OVERLAY _P_OVERLAY
#define OLD_P_OVERLAY _OLD_P_OVERLAY
#define P_NOWAITO _P_NOWAITO
#define P_DETACH _P_DETACH
#define WAIT_CHILD _WAIT_CHILD
#define WAIT_GRANDCHILD _WAIT_GRANDCHILD

#if defined(_CRT_USE_WINAPI_FAMILY_DESKTOP_APP) || defined(WINSTORECOMPAT)
#ifndef _CRT_GETPID_DEFINED
#define _CRT_GETPID_DEFINED  /* Also in unistd.h */
  int __cdecl getpid(void) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
#endif /* _CRT_USE_WINAPI_FAMILY_DESKTOP_APP || WINSTORECOMPAT */
#ifdef _CRT_USE_WINAPI_FAMILY_DESKTOP_APP
  intptr_t __cdecl cwait(int *_TermStat,intptr_t _ProcHandle,int _Action) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#ifdef __GNUC__
  int __cdecl execl(const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl execle(const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl execlp(const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl execlpe(const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#else
  intptr_t __cdecl execl(const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  intptr_t __cdecl execle(const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  intptr_t __cdecl execlp(const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  intptr_t __cdecl execlpe(const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
  intptr_t __cdecl spawnl(int,const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  intptr_t __cdecl spawnle(int,const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  intptr_t __cdecl spawnlp(int,const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  intptr_t __cdecl spawnlpe(int,const char *_Filename,const char *_ArgList,...) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#ifdef __GNUC__
  /* Those methods are predefined by gcc builtins to return int. So to prevent
     stupid warnings, define them in POSIX way.  This is save, because those
     methods do not return in success case, so that the return value is not
     really dependent to its scalar width.  */
  _CRTIMP int __cdecl execv(const char *_Filename,char *const _ArgList[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP int __cdecl execve(const char *_Filename,char *const _ArgList[],char *const _Env[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP int __cdecl execvp(const char *_Filename,char *const _ArgList[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP int __cdecl execvpe(const char *_Filename,char *const _ArgList[],char *const _Env[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#else
  _CRTIMP intptr_t __cdecl execv(const char *_Filename,char *const _ArgList[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP intptr_t __cdecl execve(const char *_Filename,char *const _ArgList[],char *const _Env[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP intptr_t __cdecl execvp(const char *_Filename,char *const _ArgList[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP intptr_t __cdecl execvpe(const char *_Filename,char *const _ArgList[],char *const _Env[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
  _CRTIMP intptr_t __cdecl spawnv(int,const char *_Filename,char *const _ArgList[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP intptr_t __cdecl spawnve(int,const char *_Filename,char *const _ArgList[],char *const _Env[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP intptr_t __cdecl spawnvp(int,const char *_Filename,char *const _ArgList[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP intptr_t __cdecl spawnvpe(int,const char *_Filename,char *const _ArgList[],char *const _Env[]) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
#endif /* _CRT_USE_WINAPI_FAMILY_DESKTOP_APP */

#ifdef __cplusplus
}
#endif
#endif
#endif
