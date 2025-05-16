/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <fenv.h>

/* 7.6.4.4
   The feupdateenv function saves the currently raised exceptions in
   its automatic storage, installs the floating-point environment
   represented by the object pointed to by envp, and then raises the
   saved exceptions. The argument envp shall point to an object
   set by a call to feholdexcept or fegetenv, or equal the macro
   FE_DFL_ENV or an implementation-defined environment macro. */

int feupdateenv(const fenv_t *env)
{
    int except = fetestexcept(FE_ALL_EXCEPT);
    return fesetenv(env) || feraiseexcept(except);
}

