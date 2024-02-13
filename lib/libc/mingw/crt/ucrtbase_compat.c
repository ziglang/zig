/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifdef __GNUC__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Winline"
#endif

#undef __MSVCRT_VERSION__
#define _UCRT

#define __getmainargs crtimp___getmainargs
#define __wgetmainargs crtimp___wgetmainargs
#define _amsg_exit crtimp__amsg_exit
#define _get_output_format crtimp__get_output_format

#include <internal.h>
#include <sect_attribs.h>
#include <stdio.h>
#include <time.h>
#include <corecrt_startup.h>

#undef __getmainargs
#undef __wgetmainargs
#undef _amsg_exit
#undef _get_output_format



// Declarations of non-static functions implemented within this file (that aren't
// declared in any of the included headers, and that isn't mapped away with a define
// to get rid of the _CRTIMP in headers).
int __cdecl __getmainargs(int * _Argc, char *** _Argv, char ***_Env, int _DoWildCard, _startupinfo *_StartInfo);
int __cdecl __wgetmainargs(int * _Argc, wchar_t *** _Argv, wchar_t ***_Env, int _DoWildCard, _startupinfo *_StartInfo);
void __cdecl __MINGW_ATTRIB_NORETURN _amsg_exit(int ret);
unsigned int __cdecl _get_output_format(void);

int __cdecl __ms_fwprintf(FILE *, const wchar_t *, ...);

// Declarations of functions from ucrtbase.dll that we use below
_CRTIMP int* __cdecl __p___argc(void);
_CRTIMP char*** __cdecl __p___argv(void);
_CRTIMP wchar_t*** __cdecl __p___wargv(void);
_CRTIMP char*** __cdecl __p__environ(void);
_CRTIMP wchar_t*** __cdecl __p__wenviron(void);

_CRTIMP int __cdecl _initialize_narrow_environment(void);
_CRTIMP int __cdecl _initialize_wide_environment(void);
_CRTIMP int __cdecl _configure_narrow_argv(int mode);
_CRTIMP int __cdecl _configure_wide_argv(int mode);

// Declared in new.h, but only visible to C++
_CRTIMP int __cdecl _set_new_mode(int _NewMode);

extern char __mingw_module_is_dll;


// Wrappers with legacy msvcrt.dll style API, based on the new ucrtbase.dll functions.
int __cdecl __getmainargs(int * _Argc, char *** _Argv, char ***_Env, int _DoWildCard, _startupinfo *_StartInfo)
{
  _initialize_narrow_environment();
  _configure_narrow_argv(_DoWildCard ? 2 : 1);
  *_Argc = *__p___argc();
  *_Argv = *__p___argv();
  *_Env = *__p__environ();
  if (_StartInfo)
    _set_new_mode(_StartInfo->newmode);
  return 0;
}

int __cdecl __wgetmainargs(int * _Argc, wchar_t *** _Argv, wchar_t ***_Env, int _DoWildCard, _startupinfo *_StartInfo)
{
  _initialize_wide_environment();
  _configure_wide_argv(_DoWildCard ? 2 : 1);
  *_Argc = *__p___argc();
  *_Argv = *__p___wargv();
  *_Env = *__p__wenviron();
  if (_StartInfo)
    _set_new_mode(_StartInfo->newmode);
  return 0;
}

_onexit_t __cdecl _onexit(_onexit_t func)
{
  return _crt_atexit((_PVFV)func) == 0 ? func : NULL;
}

_onexit_t __cdecl (*__MINGW_IMP_SYMBOL(_onexit))(_onexit_t func) = _onexit;

int __cdecl at_quick_exit(void (__cdecl *func)(void))
{
  // In a DLL, we can't register a function with _crt_at_quick_exit, because
  // we can't unregister it when the DLL is unloaded. This matches how
  // at_quick_exit/quick_exit work with MSVC with a dynamically linked CRT.
  if (__mingw_module_is_dll)
    return 0;
  return _crt_at_quick_exit(func);
}

int __cdecl (*__MINGW_IMP_SYMBOL(at_quick_exit))(void (__cdecl *)(void)) = at_quick_exit;

void __cdecl __MINGW_ATTRIB_NORETURN _amsg_exit(int ret) {
  fprintf(stderr, "runtime error %d\n", ret);
  _exit(255);
}

unsigned int __cdecl _get_output_format(void)
{
  return 0;
}


// These are required to provide the unrepfixed data symbols "timezone"
// and "tzname"; we can't remap "timezone" via a define due to clashes
// with e.g. "struct timezone".
typedef void __cdecl (*_tzset_func)(void);
extern _tzset_func __MINGW_IMP_SYMBOL(_tzset);

// Default initial values until _tzset has been called; these are the same
// as the initial values in msvcrt/ucrtbase.
static char initial_tzname0[] = "PST";
static char initial_tzname1[] = "PDT";
static char *initial_tznames[] = { initial_tzname0, initial_tzname1 };
static long initial_timezone = 28800;
static int initial_daylight = 1;
char** __MINGW_IMP_SYMBOL(tzname) = initial_tznames;
long * __MINGW_IMP_SYMBOL(timezone) = &initial_timezone;
int * __MINGW_IMP_SYMBOL(daylight) = &initial_daylight;

void __cdecl _tzset(void)
{
  __MINGW_IMP_SYMBOL(_tzset)();
  // Redirect the __imp_ pointers to the actual data provided by the UCRT.
  // From this point, the exposed values should stay in sync.
  __MINGW_IMP_SYMBOL(tzname) = _tzname;
  __MINGW_IMP_SYMBOL(timezone) = __timezone();
  __MINGW_IMP_SYMBOL(daylight) = __daylight();
}

void __cdecl tzset(void)
{
  _tzset();
}

// This is called for wchar cases with __USE_MINGW_ANSI_STDIO enabled (where the
// char case just uses fputc).
int __cdecl __ms_fwprintf(FILE *file, const wchar_t *fmt, ...)
{
  va_list ap;
  int ret;
  va_start(ap, fmt);
  ret = __stdio_common_vfwprintf(_CRT_INTERNAL_PRINTF_LEGACY_WIDE_SPECIFIERS, file, fmt, NULL, ap);
  va_end(ap);
  return ret;
}

// Dummy/unused __imp_ wrappers, to make GNU ld not autoexport these symbols.
int __cdecl (*__MINGW_IMP_SYMBOL(__getmainargs))(int *, char ***, char ***, int, _startupinfo *) = __getmainargs;
int __cdecl (*__MINGW_IMP_SYMBOL(__wgetmainargs))(int *, wchar_t ***, wchar_t ***, int, _startupinfo *) = __wgetmainargs;
void __cdecl (*__MINGW_IMP_SYMBOL(_amsg_exit))(int) = _amsg_exit;
unsigned int __cdecl (*__MINGW_IMP_SYMBOL(_get_output_format))(void) = _get_output_format;
void __cdecl (*__MINGW_IMP_SYMBOL(tzset))(void) = tzset;
int __cdecl (*__MINGW_IMP_SYMBOL(__ms_fwprintf))(FILE *, const wchar_t *, ...) = __ms_fwprintf;
#ifdef __GNUC__
#pragma GCC diagnostic pop
#endif
