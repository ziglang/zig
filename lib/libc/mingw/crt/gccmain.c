/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <windows.h>
#include <stdlib.h>
#include <setjmp.h>

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

typedef void (*func_ptr) (void);
extern func_ptr __CTOR_LIST__[];
extern func_ptr __DTOR_LIST__[];

void __do_global_dtors (void);
void __do_global_ctors (void);
void __main (void);

void
__do_global_dtors (void)
{
  static func_ptr *p = __DTOR_LIST__ + 1;

  while (*p)
    {
      (*(p)) ();
      p++;
    }
}

#ifndef HAVE_CTOR_LIST
// If the linker didn't provide __CTOR_LIST__, we provided it ourselves,
// and then we also know we have __CTOR_END__ available.
extern func_ptr __CTOR_END__[];
extern func_ptr __DTOR_END__[];

void __do_global_ctors (void)
{
  static func_ptr *p = __CTOR_END__ - 1;
  while (*p != (func_ptr) -1) {
    (*(p))();
    p--;
  }
  atexit (__do_global_dtors);
}

#else
// old method that iterates the list twice because old linker scripts do not have __CTOR_END__

void
__do_global_ctors (void)
{
  unsigned long nptrs = (unsigned long) (ptrdiff_t) __CTOR_LIST__[0];
  unsigned long i;

  if (nptrs == (unsigned long) -1)
    {
      for (nptrs = 0; __CTOR_LIST__[nptrs + 1] != 0; nptrs++);
    }

  for (i = nptrs; i >= 1; i--)
    {
      __CTOR_LIST__[i] ();
    }

  atexit (__do_global_dtors);
}

#endif

static int initialized = 0;

void
__main (void)
{
  if (!initialized)
    {
      initialized = 1;
      __do_global_ctors ();
    }
}
