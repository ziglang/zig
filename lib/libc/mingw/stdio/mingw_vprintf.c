/* vprintf.c
 *
 * $Id: vprintf.c,v 1.1 2008/08/11 22:41:55 keithmarshall Exp $
 *
 * Provides an implementation of the "vprintf" function, conforming
 * generally to C99 and SUSv3/POSIX specifications, with extensions
 * to support Microsoft's non-standard format specifications.  This
 * is included in libmingwex.a, whence it may replace the Microsoft
 * function of the same name.
 *
 * Written by Keith Marshall <keithmarshall@users.sourceforge.net>
 *
 * This implementation of "vprintf" will normally be invoked by calling
 * "__mingw_vprintf()" in preference to a direct reference to "vprintf()"
 * itself; this leaves the MSVCRT implementation as the default, which
 * will be deployed when user code invokes "vprint()".  Users who then
 * wish to use this implementation may either call "__mingw_vprintf()"
 * directly, or may use conditional preprocessor defines, to redirect
 * references to "vprintf()" to "__mingw_vprintf()".
 *
 * Compiling this module with "-D INSTALL_AS_DEFAULT" will change this
 * recommended convention, such that references to "vprintf()" in user
 * code will ALWAYS be redirected to "__mingw_vprintf()"; if this option
 * is adopted, then users wishing to use the MSVCRT implementation of
 * "vprintf()" will be forced to use a "back-door" mechanism to do so.
 * Such a "back-door" mechanism is provided with MinGW, allowing the
 * MSVCRT implementation to be called as "__msvcrt_vprintf()"; however,
 * since users may not expect this behaviour, a standard libmingwex.a
 * installation does not employ this option.
 *
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

int __cdecl __vprintf (const APICHAR *, va_list) __MINGW_NOTHROW;

int __cdecl __vprintf(const APICHAR *fmt, va_list argv)
{
  register int retval;

  _lock_file( stdout );
  retval = __pformat( PFORMAT_TO_FILE | PFORMAT_NOLIMIT, stdout, 0, fmt, argv );
  _unlock_file( stdout );

  return retval;
}
