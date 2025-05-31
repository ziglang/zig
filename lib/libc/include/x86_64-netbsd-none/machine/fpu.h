#ifndef _AMD64_FPU_H_
#define _AMD64_FPU_H_

/*
 * This file is only present for backwards compatibility with
 * a few user programs, particularly firefox.
 */

#ifndef _KERNEL
#define fxsave64 fxsave
#include <x86/cpu_extended_state.h>
#endif

#endif