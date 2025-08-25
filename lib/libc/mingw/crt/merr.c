/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>
#include <stdio.h>

int __CRTDECL
_matherr (struct _exception *pexcept)
{
  const char * type;

  switch(pexcept->type)
    {
      case _DOMAIN:
	type = "Argument domain error (DOMAIN)";
	break;

      case _SING:
	type = "Argument singularity (SIGN)";
	break;

      case _OVERFLOW:
	type = "Overflow range error (OVERFLOW)";
	break;

      case _PLOSS:
	type = "Partial loss of significance (PLOSS)";
	break;

      case _TLOSS:
	type = "Total loss of significance (TLOSS)";
	break;

      case _UNDERFLOW:
	type = "The result is too small to be represented (UNDERFLOW)";
	break;

      default:
	type = "Unknown error";
	break;
    }

  fprintf (stderr, "_matherr(): %s in %s(%g, %g)  (retval=%g)\n", 
	  type, pexcept->name, pexcept->arg1, pexcept->arg2, pexcept->retval);
  return 0;
}

