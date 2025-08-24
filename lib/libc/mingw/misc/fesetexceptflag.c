/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <internal.h>

/* 7.6.2.4
   The fesetexceptflag function sets the complete status for those
   exception flags indicated by the argument excepts, according to the
   representation in the object pointed to by flagp. The value of
   *flagp shall have been set by a previous call to fegetexceptflag
   whose second argument represented at least those exceptions
   represented by the argument excepts. This function does not raise
   exceptions, but only sets the state of the flags. */

int fesetexceptflag(const fexcept_t *status, int excepts)
{
    fenv_t env;

    excepts &= FE_ALL_EXCEPT;
    if(!excepts)
        return 0;

    fegetenv(&env);
    env._Fe_stat &= ~fenv_encode(excepts, excepts);
    env._Fe_stat |= *status & fenv_encode(excepts, excepts);
    return fesetenv(&env);
}
