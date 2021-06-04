/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_CORECRT_STARTUP
#define _INC_CORECRT_STARTUP

#ifdef __cplusplus
extern "C" {
#endif

_CRTIMP char **__cdecl __p__acmdln(void);
#define _acmdln (*__p__acmdln())

_CRTIMP wchar_t **__cdecl __p__wcmdln(void);
#define _wcmdln (*__p__wcmdln())

typedef void (__cdecl *_PVFV)(void);
typedef int (__cdecl *_PIFV)(void);
typedef void (__cdecl *_PVFI)(int);

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
