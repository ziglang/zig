/* snprintf.c
 *
 * $Id: snprintf.c,v 1.3 2008/07/28 23:24:20 keithmarshall Exp $
 *
 * Provides an implementation of the "snprintf" function, conforming
 * generally to C99 and SUSv3/POSIX specifications, with extensions
 * to support Microsoft's non-standard format specifications.  This
 * is included in libmingwex.a, replacing the redirection through
 * libmoldnames.a, to the MSVCRT standard "_snprintf" function; (the
 * standard MSVCRT function remains available, and may  be invoked
 * directly, using this fully qualified form of its name).
 *
 * Written by Keith Marshall <keithmarshall@users.sourceforge.net>
 *
 * This is free software.  You may redistribute and/or modify it as you
 * see fit, without restriction of copyright.
 *
 * This software is provided "as is", in the hope that it may be useful,
 * but WITHOUT WARRANTY OF ANY KIND, not even any implied warranty of
 * MERCHANTABILITY, nor of FITNESS FOR ANY PARTICULAR PURPOSE.  At no
 * time will the author accept any form of liability for any damages,
 * however caused, resulting from the use of this software.
 *
 */

#include <stdio.h>
#include <stdarg.h>

#include "mingw_pformat.h"

int __cdecl __snprintf (APICHAR *, size_t, const APICHAR *fmt, ...) __MINGW_NOTHROW;
int __cdecl __vsnprintf (APICHAR *, size_t, const APICHAR *fmt, va_list) __MINGW_NOTHROW;

int __cdecl __snprintf(APICHAR *buf, size_t length, const APICHAR *fmt, ...)
{
  va_list argv; va_start( argv, fmt );
  register int retval = __vsnprintf( buf, length, fmt, argv );
  va_end( argv );
  return retval;
}
