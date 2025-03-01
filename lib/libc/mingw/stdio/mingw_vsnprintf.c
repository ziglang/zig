/* vsnprintf.c
 *
 * $Id: vsnprintf.c,v 1.3 2008/07/28 23:24:20 keithmarshall Exp $
 *
 * Provides an implementation of the "vsnprintf" function, conforming
 * generally to C99 and SUSv3/POSIX specifications, with extensions
 * to support Microsoft's non-standard format specifications.  This
 * is included in libmingwex.a, replacing the redirection through
 * libmoldnames.a, to the MSVCRT standard "_vsnprintf" function; (the
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

int __cdecl __vsnprintf (APICHAR *, size_t, const APICHAR *fmt, va_list) __MINGW_NOTHROW;
int __cdecl __vsnprintf(APICHAR *buf, size_t length, const APICHAR *fmt, va_list argv )
{
  register int retval;

  if( length == (size_t)(0) )
  {
#if defined(__BUILD_WIDEAPI) && defined(__BUILD_WIDEAPI_ISO)
    /* No buffer; for wide api ISO C95+ vswprintf() function
     * simply returns negative value as required by ISO C95+.
     */
    return -1;
#else
    /*
     * No buffer; simply compute and return the size required,
     * without actually emitting any data.
     */
    return __pformat( 0, buf, 0, fmt, argv);
#endif
  }

  /* If we get to here, then we have a buffer...
   * Emit data up to the limit of buffer length less one,
   * then add the requisite NUL terminator.
   */
  retval = __pformat( 0, buf, --length, fmt, argv );
  buf[retval < (int) length ? retval : (int)length] = '\0';

#if defined(__BUILD_WIDEAPI) && defined(__BUILD_WIDEAPI_ISO)
  /* For wide api ISO C95+ vswprintf() when requested length
   * is equal or larger than buffer length, returns negative
   * value as required by ISO C95+.
   */
  if( retval >= (int) length )
    retval = -1;
#endif

  return retval;
}

