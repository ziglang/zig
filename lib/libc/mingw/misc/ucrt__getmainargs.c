/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT

#include <corecrt_startup.h>
#include <internal.h>
#include <stdlib.h>
#include <new.h>

int __cdecl __getmainargs(int *argc, char ***argv, char ***env, int DoWildCard, _startupinfo *StartInfo)
{
  _initialize_narrow_environment();
  _configure_narrow_argv(DoWildCard ? _crt_argv_expanded_arguments : _crt_argv_unexpanded_arguments);
  *argc = *__p___argc();
  *argv = *__p___argv();
  *env = *__p__environ();
  _set_new_mode(StartInfo->newmode);
  return 0;
}
int __cdecl (*__MINGW_IMP_SYMBOL(__getmainargs))(int *, char ***, char ***, int, _startupinfo *) = __getmainargs;
