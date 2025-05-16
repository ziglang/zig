/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_CORECRT_STARTUP
#define _INC_CORECRT_STARTUP

#include <corecrt.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _crt_app_type {
    _crt_unknown_app,
    _crt_console_app,
    _crt_gui_app
} _crt_app_type;

_CRTIMP _crt_app_type __cdecl _query_app_type(void);
_CRTIMP void __cdecl _set_app_type(_crt_app_type _Type);

typedef enum _crt_argv_mode {
    _crt_argv_no_arguments,
    _crt_argv_unexpanded_arguments,
    _crt_argv_expanded_arguments
} _crt_argv_mode;

_CRTIMP errno_t __cdecl _configure_narrow_argv(_crt_argv_mode mode);
_CRTIMP errno_t __cdecl _configure_wide_argv(_crt_argv_mode mode);

_CRTIMP int __cdecl _initialize_narrow_environment(void);
_CRTIMP int __cdecl _initialize_wide_environment(void);

_CRTIMP char** __cdecl _get_initial_narrow_environment(void);
_CRTIMP wchar_t** __cdecl _get_initial_wide_environment(void);

_CRTIMP char* __cdecl _get_narrow_winmain_command_line(void);
_CRTIMP wchar_t* __cdecl _get_wide_winmain_command_line(void);

_CRTIMP char **__cdecl __p__acmdln(void);
#define _acmdln (*__p__acmdln())

_CRTIMP wchar_t **__cdecl __p__wcmdln(void);
#define _wcmdln (*__p__wcmdln())

typedef void (__cdecl *_PVFV)(void);
typedef int (__cdecl *_PIFV)(void);
typedef void (__cdecl *_PVFI)(int);

_CRTIMP void __cdecl _initterm(_PVFV* _First, _PVFV* _Last);
_CRTIMP int __cdecl _initterm_e(_PIFV* _First, _PIFV* _Last);

typedef struct _onexit_table_t {
    _PVFV* _first;
    _PVFV* _last;
    _PVFV* _end;
} _onexit_table_t;

typedef int (__cdecl *_onexit_t)(void);

_CRTIMP int __cdecl _initialize_onexit_table(_onexit_table_t*);
_CRTIMP int __cdecl _register_onexit_function(_onexit_table_t*,_onexit_t);
_CRTIMP int __cdecl _execute_onexit_table(_onexit_table_t*);
_CRTIMP int __cdecl _crt_atexit(_PVFV func);
_CRTIMP int __cdecl _crt_at_quick_exit(_PVFV func);

#ifdef __cplusplus
}
#endif
#endif
