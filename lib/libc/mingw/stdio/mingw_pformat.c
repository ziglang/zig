/* pformat.c
 *
 * $Id: pformat.c,v 1.9 2011/01/07 22:57:00 keithmarshall Exp $
 *
 * Provides a core implementation of the formatting capabilities
 * common to the entire `printf()' family of functions; it conforms
 * generally to C99 and SUSv3/POSIX specifications, with extensions
 * to support Microsoft's non-standard format specifications.
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
 * The elements of this implementation which deal with the formatting
 * of floating point numbers, (i.e. the `%e', `%E', `%f', `%F', `%g'
 * and `%G' format specifiers, but excluding the hexadecimal floating
 * point `%a' and `%A' specifiers), make use of the `__gdtoa' function
 * written by David M. Gay, and are modelled on his sample code, which
 * has been deployed under its accompanying terms of use:--
 *
 ******************************************************************
 * Copyright (C) 1997, 1999, 2001 Lucent Technologies
 * All Rights Reserved
 *
 * Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose and without fee is hereby
 * granted, provided that the above copyright notice appear in all
 * copies and that both that the copyright notice and this
 * permission notice and warranty disclaimer appear in supporting
 * documentation, and that the name of Lucent or any of its entities
 * not be used in advertising or publicity pertaining to
 * distribution of the software without specific, written prior
 * permission.
 *
 * LUCENT DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS.
 * IN NO EVENT SHALL LUCENT OR ANY OF ITS ENTITIES BE LIABLE FOR ANY
 * SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
 * ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
 * THIS SOFTWARE.
 ******************************************************************
 *
 */

#define __LARGE_MBSTATE_T

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <locale.h>
#include <wchar.h>

#ifdef __ENABLE_DFP
#ifndef __STDC_WANT_DEC_FP__
#define __STDC_WANT_DEC_FP__ 1
#endif

#include "../math/DFP/dfp_internal.h"
#endif /* __ENABLE_DFP */

#include <math.h>

/* FIXME: The following belongs in values.h, but current MinGW
 * has nothing useful there!  OTOH, values.h is not a standard
 * header, and its use may be considered obsolete; perhaps it
 * is better to just keep these definitions here.
 */

#include <pshpack1.h>
/* workaround gcc bug */
#if defined(__GNUC__) && !defined(__clang__)
#define ATTRIB_GCC_STRUCT __attribute__((gcc_struct))
#else
#define ATTRIB_GCC_STRUCT
#endif
typedef struct ATTRIB_GCC_STRUCT __tI128 {
  int64_t digits[2];
} __tI128;

typedef struct ATTRIB_GCC_STRUCT __tI128_2 {
  uint32_t digits32[4];
} __tI128_2;

typedef union ATTRIB_GCC_STRUCT __uI128 {
  __tI128 t128;
  __tI128_2 t128_2;
} __uI128;
#include <poppack.h>

#ifndef _VALUES_H
/*
 * values.h
 *
 */
#define _VALUES_H

#include <limits.h>

#define _TYPEBITS(type)     (sizeof(type) * CHAR_BIT)

#if defined(__ENABLE_PRINTF128) || defined(__ENABLE_DFP)
#define LLONGBITS           _TYPEBITS(__tI128)
#else
#define LLONGBITS           _TYPEBITS(long long)
#endif

#endif /* !defined _VALUES_H -- end of file */

#include "mingw_pformat.h"

/* Bit-map constants, defining the internal format control
 * states, which propagate through the flags.
 */
#define PFORMAT_GROUPED     0x00001000
#define PFORMAT_HASHED      0x00000800
#define PFORMAT_LJUSTIFY    0x00000400
#define PFORMAT_ZEROFILL    0x00000200

#define PFORMAT_JUSTIFY    (PFORMAT_LJUSTIFY | PFORMAT_ZEROFILL)
#define PFORMAT_IGNORE      -1

#define PFORMAT_SIGNED      0x000001C0
#define PFORMAT_POSITIVE    0x00000100
#define PFORMAT_NEGATIVE    0x00000080
#define PFORMAT_ADDSPACE    0x00000040

#define PFORMAT_XCASE       0x00000020

#define PFORMAT_LDOUBLE     0x00000004

#ifdef __ENABLE_DFP
#define PFORMAT_DECIM32     0x00020000
#define PFORMAT_DECIM64     0x00040000
#define PFORMAT_DECIM128    0x00080000
#endif

/* `%o' format digit extraction mask, and shift count...
 * (These are constant, and do not propagate through the flags).
 */
#define PFORMAT_OMASK       0x00000007
#define PFORMAT_OSHIFT      0x00000003

/* `%x' and `%X' format digit extraction mask, and shift count...
 * (These are constant, and do not propagate through the flags).
 */
#define PFORMAT_XMASK       0x0000000F
#define PFORMAT_XSHIFT      0x00000004

/* The radix point character, used in floating point formats, is
 * localised on the basis of the active LC_NUMERIC locale category.
 * It is stored locally, as a `wchar_t' entity, which is converted
 * to a (possibly multibyte) character on output.  Initialisation
 * of the stored `wchar_t' entity, together with a record of its
 * effective multibyte character length, is required each time
 * `__pformat()' is entered, (static storage would not be thread
 * safe), but this initialisation is deferred until it is actually
 * needed; on entry, the effective character length is first set to
 * the following value, (and the `wchar_t' entity is zeroed), to
 * indicate that a call of `localeconv()' is needed, to complete
 * the initialisation.
 */
#define PFORMAT_RPINIT      -3

/* The floating point format handlers return the following value
 * for the radix point position index, when the argument value is
 * infinite, or not a number.
 */
#define PFORMAT_INFNAN      -32768

typedef union
{
  /* A data type agnostic representation,
   * for printf arguments of any integral data type...
   */
  signed long             __pformat_long_t;
  signed long long        __pformat_llong_t;
  unsigned long           __pformat_ulong_t;
  unsigned long long      __pformat_ullong_t;
  unsigned short          __pformat_ushort_t;
  unsigned char           __pformat_uchar_t;
  signed short            __pformat_short_t;
  signed char             __pformat_char_t;
  void *                  __pformat_ptr_t;
  __uI128                 __pformat_u128_t;
} __pformat_intarg_t;

typedef enum
{
  /* Format interpreter state indices...
   * (used to identify the active phase of format string parsing).
   */
  PFORMAT_INIT = 0,
  PFORMAT_SET_WIDTH,
  PFORMAT_GET_PRECISION,
  PFORMAT_SET_PRECISION,
  PFORMAT_END
} __pformat_state_t;

typedef enum
{
  /* Argument length classification indices...
   * (used for arguments representing integer data types).
   */
  PFORMAT_LENGTH_INT = 0,
  PFORMAT_LENGTH_SHORT,
  PFORMAT_LENGTH_LONG,
  PFORMAT_LENGTH_LLONG,
  PFORMAT_LENGTH_LLONG128,
  PFORMAT_LENGTH_CHAR
} __pformat_length_t;
/*
 * And a macro to map any arbitrary data type to an appropriate
 * matching index, selected from those above; the compiler should
 * collapse this to a simple assignment.
 */

#ifdef __GNUC__
/* provides for some deadcode elimination via compile time eval */
#define __pformat_arg_length(x) \
__builtin_choose_expr (                                         \
  __builtin_types_compatible_p (typeof (x), __tI128),           \
   PFORMAT_LENGTH_LLONG128,                                     \
    __builtin_choose_expr (                                     \
      __builtin_types_compatible_p (typeof (x), long long),     \
        PFORMAT_LENGTH_LLONG,                                   \
    __builtin_choose_expr (                                     \
      __builtin_types_compatible_p (typeof (x), long),          \
        PFORMAT_LENGTH_LONG,                                    \
    __builtin_choose_expr (                                     \
      __builtin_types_compatible_p (typeof (x), short),         \
        PFORMAT_LENGTH_SHORT,                                   \
    __builtin_choose_expr (                                     \
      __builtin_types_compatible_p (typeof (x), char),          \
        PFORMAT_LENGTH_CHAR,                                    \
    __builtin_choose_expr (                                     \
      __builtin_types_compatible_p (typeof (x), __uI128),       \
        PFORMAT_LENGTH_LLONG128,                                \
    __builtin_choose_expr (                                              \
      __builtin_types_compatible_p (typeof (x), unsigned long),          \
        PFORMAT_LENGTH_LONG,                                             \
    __builtin_choose_expr (                                              \
      __builtin_types_compatible_p (typeof (x), unsigned long long),     \
        PFORMAT_LENGTH_LLONG,                                            \
    __builtin_choose_expr (                                              \
      __builtin_types_compatible_p (typeof (x), unsigned short),         \
        PFORMAT_LENGTH_SHORT,                                            \
    __builtin_choose_expr (                                              \
      __builtin_types_compatible_p (typeof (x), unsigned char),          \
        PFORMAT_LENGTH_CHAR,                                             \
  PFORMAT_LENGTH_INT))))))))))

#else
#define __pformat_arg_length( type )    \
  sizeof( type ) == sizeof( __tI128 )   ? PFORMAT_LENGTH_LLONG128 : \
  sizeof( type ) == sizeof( long long ) ? PFORMAT_LENGTH_LLONG : \
  sizeof( type ) == sizeof( long )      ? PFORMAT_LENGTH_LONG  : \
  sizeof( type ) == sizeof( short )     ? PFORMAT_LENGTH_SHORT : \
  sizeof( type ) == sizeof( char )      ? PFORMAT_LENGTH_CHAR  : \
  /* should never need this default */    PFORMAT_LENGTH_INT
#endif

typedef struct
{
  /* Formatting and output control data...
   * An instance of this control block is created, (on the stack),
   * for each call to `__pformat()', and is passed by reference to
   * each of the output handlers, as required.
   */
  void *         dest;
  int            flags;
  int            width;
  int            precision;
  int            rplen;
  wchar_t        rpchr;
  int            thousands_chr_len;
  wchar_t        thousands_chr;
  int            count;
  int            quota;
  int            expmin;
} __pformat_t;

#if defined(__ENABLE_PRINTF128) || defined(__ENABLE_DFP)
/* trim leading, leave at least n characters */
static char * __bigint_trim_leading_zeroes(char *in, int n){
  char *src = in;
  int len = strlen(in);
  while( len > n && *++src == '0') len--;

  /* we want to null terminator too */
  memmove(in, src, strlen(src) + 1);
  return in;
}

/* LSB first */
static
void __bigint_to_string(const uint32_t *digits, const uint32_t digitlen, char *buff, const uint32_t bufflen){
  int64_t digitsize = sizeof(*digits) * 8;
  int64_t shiftpos = digitlen * digitsize - 1;
  memset(buff, 0, bufflen);

  while(shiftpos >= 0) {
    /* increment */
    for(uint32_t i = 0; i < bufflen - 1; i++){
      buff[i] += (buff[i] > 4) ? 3 : 0;
    }

    /* shift left */
    for(uint32_t i = 0; i < bufflen - 1; i++)
      buff[i] <<= 1;

    /* shift in */
    buff[bufflen - 2] |= digits[shiftpos / digitsize] & (0x1 << (shiftpos % digitsize)) ? 1 : 0;

    /* overflow check */
    for(uint32_t i = bufflen - 1; i > 0; i--){
      buff[i - 1] |= (buff[i] > 0xf);
      buff[i] &= 0x0f;
    }
    shiftpos--;
  }

  for(uint32_t i = 0; i < bufflen - 1; i++){
    buff[i] += '0';
  }
  buff[bufflen - 1] = '\0';
}

#if defined(__ENABLE_PRINTF128)
/* LSB first, hex version */
static
void __bigint_to_stringx(const uint32_t *digits, const uint32_t digitlen, char *buff, const uint32_t bufflen, int upper){
  int32_t stride = sizeof(*digits) * 2;
  uint32_t lastpos = 0;

  for(uint32_t i = 0; i < digitlen * stride; i++){
    int32_t buffpos = bufflen - i - 2;
    buff[buffpos] = (digits[ i / stride ] & (0xf << 4 * (i % stride))) >> ( 4 * (i % stride));
    buff[buffpos] += (buff[buffpos] > 9) ? ((upper) ? 0x7 : 0x27) : 0;
    buff[buffpos] += '0';
    lastpos = buffpos;
    if(buffpos == 0) break; /* sanity check */
  }
  memset(buff, '0', lastpos);
  buff[bufflen - 1] = '\0';
}

/* LSB first, octet version */
static
void __bigint_to_stringo(const uint32_t *digits, const uint32_t digitlen, char *buff, const uint32_t bufflen){
  const uint32_t digitsize = sizeof(*digits) * 8;
  const uint64_t bits = digitsize * digitlen;
  uint32_t pos = bufflen - 2;
  uint32_t reg = 0;
  for(uint32_t i = 0; i <= bits; i++){
    reg |= (digits[ i / digitsize] & (0x1 << (i % digitsize))) ? 1 << (i % 3) : 0;
    if( (i && ( i + 1) % 3 == 0) || (i + 1) == bits){ /* make sure all is committed after last bit */
      buff[pos] = '0' + reg;
      reg = 0;
      if(!pos) break; /* sanity check */
      pos--;
    }
  }
  if(pos < bufflen - 1)
    memset(buff,'0', pos + 1);
  buff[bufflen - 1] = '\0';
}
#endif /* defined(__ENABLE_PRINTF128) */
#endif /* defined(__ENABLE_PRINTF128) || defined(__ENABLE_DFP) */

static
void __pformat_putc( int c, __pformat_t *stream )
{
  /* Place a single character into the `__pformat()' output queue,
   * provided any specified output quota has not been exceeded.
   */
  if( (stream->flags & PFORMAT_NOLIMIT) || (stream->quota > stream->count) )
  {
    /* Either there was no quota specified,
     * or the active quota has not yet been reached.
     */
    if( stream->flags & PFORMAT_TO_FILE )
      /*
       * This is single character output to a FILE stream...
       */
      __fputc(c, (FILE *)(stream->dest));

    else
      /* Whereas, this is to an internal memory buffer...
       */
      ((APICHAR *)(stream->dest))[stream->count] = c;
  }
  ++stream->count;
}

static
void __pformat_putchars( const char *s, int count, __pformat_t *stream )
{
#ifndef __BUILD_WIDEAPI
  /* Handler for `%c' and (indirectly) `%s' conversion specifications.
   *
   * Transfer characters from the string buffer at `s', character by
   * character, up to the number of characters specified by `count', or
   * if `precision' has been explicitly set to a value less than `count',
   * stopping after the number of characters specified for `precision',
   * to the `__pformat()' output stream.
   *
   * Characters to be emitted are passed through `__pformat_putc()', to
   * ensure that any specified output quota is honoured.
   */
  if( (stream->precision >= 0) && (count > stream->precision) )
    /*
     * Ensure that the maximum number of characters transferred doesn't
     * exceed any explicitly set `precision' specification.
     */
    count = stream->precision;

  /* Establish the width of any field padding required...
   */
  if( stream->width > count )
    /*
     * as the number of spaces equivalent to the number of characters
     * by which those to be emitted is fewer than the field width...
     */
    stream->width -= count;

  else
    /* ignoring any width specification which is insufficient.
     */
    stream->width = PFORMAT_IGNORE;

  if( (stream->width > 0) && ((stream->flags & PFORMAT_LJUSTIFY) == 0) )
    /*
     * When not doing flush left justification, (i.e. the `-' flag
     * is not set), any residual unreserved field width must appear
     * as blank padding, to the left of the output string.
     */
    while( stream->width-- )
      __pformat_putc( '\x20', stream );

  /* Emit the data...
   */
  while( count-- )
    /*
     * copying the requisite number of characters from the input.
     */
    __pformat_putc( *s++, stream );

  /* If we still haven't consumed the entire specified field width,
   * we must be doing flush left justification; any residual width
   * must be filled with blanks, to the right of the output value.
   */
  while( stream->width-- > 0 )
    __pformat_putc( '\x20', stream );

#else  /* __BUILD_WIDEAPI */

  int len;

  if( (stream->precision >= 0) && (count > stream->precision) )
    count = stream->precision;

  if( (stream->flags & PFORMAT_TO_FILE) && (stream->flags & PFORMAT_NOLIMIT) )
  {
    int __cdecl __ms_fwprintf(FILE *, const wchar_t *, ...);

    if( stream->width > count )
    {
      if( (stream->flags & PFORMAT_LJUSTIFY) == 0 )
        len = __ms_fwprintf( (FILE *)(stream->dest), L"%*.*S", stream->width, count, s );
      else
        len = __ms_fwprintf( (FILE *)(stream->dest), L"%-*.*S", stream->width, count, s );
    }
    else
    {
      len = __ms_fwprintf( (FILE *)(stream->dest), L"%.*S", count, s );
    }
    if( len > 0 )
      stream->count += len;
    stream->width = PFORMAT_IGNORE;
    return;
  }

  if( stream->width > count )
    stream->width -= count;
  else
    stream->width = PFORMAT_IGNORE;

  if( (stream->width > 0) && ((stream->flags & PFORMAT_LJUSTIFY) == 0) )
    while( stream->width-- )
      __pformat_putc( '\x20', stream );

  {
    /* mbrtowc */
    size_t l;
    wchar_t w[12], *p;
    while( count > 0 )
    {
      mbstate_t ps;
      memset(&ps, 0, sizeof(ps) );
      --count;
      p = &w[0];
      l = mbrtowc (p, s, strlen (s), &ps);
      if (!l)
        break;
      if ((ssize_t)l < 0)
      {
        l = 1;
        w[0] = (wchar_t) *s;
      }
      s += l;
      __pformat_putc((int)w[0], stream);
    }
  }

  while( stream->width-- > 0 )
    __pformat_putc( '\x20', stream );

#endif  /* __BUILD_WIDEAPI */
}

static
void __pformat_puts( const char *s, __pformat_t *stream )
{
  /* Handler for `%s' conversion specifications.
   *
   * Transfer a NUL terminated character string, character by character,
   * stopping when the end of the string is encountered, or if `precision'
   * has been explicitly set, when the specified number of characters has
   * been emitted, if that is less than the length of the input string,
   * to the `__pformat()' output stream.
   *
   * This is implemented as a trivial call to `__pformat_putchars()',
   * passing the length of the input string as the character count,
   * (after first verifying that the input pointer is not NULL).
   */
  if( s == NULL ) s = "(null)";

  if( stream->precision >= 0 )
    __pformat_putchars( s, strnlen( s, stream->precision ), stream );
  else
    __pformat_putchars( s, strlen( s ), stream );
}

static
void __pformat_wputchars( const wchar_t *s, int count, __pformat_t *stream )
{
#ifndef __BUILD_WIDEAPI
  /* Handler for `%C'(`%lc') and `%S'(`%ls') conversion specifications;
   * (this is a wide character variant of `__pformat_putchars()').
   *
   * Each multibyte character sequence to be emitted is passed, byte
   * by byte, through `__pformat_putc()', to ensure that any specified
   * output quota is honoured.
   */
  char buf[16];
  mbstate_t state;
  int len = wcrtomb(buf, L'\0', &state);

  if( (stream->precision >= 0) && (count > stream->precision) )
    /*
     * Ensure that the maximum number of characters transferred doesn't
     * exceed any explicitly set `precision' specification.
     */
    count = stream->precision;

  /* Establish the width of any field padding required...
   */
  if( stream->width > count )
    /*
     * as the number of spaces equivalent to the number of characters
     * by which those to be emitted is fewer than the field width...
     */
    stream->width -= count;

  else
    /* ignoring any width specification which is insufficient.
     */
    stream->width = PFORMAT_IGNORE;

  if( (stream->width > 0) && ((stream->flags & PFORMAT_LJUSTIFY) == 0) )
    /*
     * When not doing flush left justification, (i.e. the `-' flag
     * is not set), any residual unreserved field width must appear
     * as blank padding, to the left of the output string.
     */
    while( stream->width-- )
      __pformat_putc( '\x20', stream );

  /* Emit the data, converting each character from the wide
   * to the multibyte domain as we go...
   */
  while( (count-- > 0) && ((len = wcrtomb( buf, *s++, &state )) > 0) )
  {
    char *p = buf;
    while( len-- > 0 )
      __pformat_putc( *p++, stream );
  }

  /* If we still haven't consumed the entire specified field width,
   * we must be doing flush left justification; any residual width
   * must be filled with blanks, to the right of the output value.
   */
  while( stream->width-- > 0 )
    __pformat_putc( '\x20', stream );

#else  /* __BUILD_WIDEAPI */

  int len;

  if( (stream->precision >= 0) && (count > stream->precision) )
    count = stream->precision;

  if( (stream->flags & PFORMAT_TO_FILE) && (stream->flags & PFORMAT_NOLIMIT) )
  {
    int __cdecl __ms_fwprintf(FILE *, const wchar_t *, ...);

    if( stream->width > count )
    {
      if( (stream->flags & PFORMAT_LJUSTIFY) == 0 )
        len = __ms_fwprintf( (FILE *)(stream->dest), L"%*.*s", stream->width, count, s );
      else
        len = __ms_fwprintf( (FILE *)(stream->dest), L"%-*.*s", stream->width, count, s );
    }
    else
    {
      len = __ms_fwprintf( (FILE *)(stream->dest), L"%.*s", count, s );
    }
    if( len > 0 )
      stream->count += len;
    stream->width = PFORMAT_IGNORE;
    return;
  }

  if( stream->width > count )
    stream->width -= count;
  else
    stream->width = PFORMAT_IGNORE;

  if( (stream->width > 0) && ((stream->flags & PFORMAT_LJUSTIFY) == 0) )
    while( stream->width-- )
      __pformat_putc( '\x20', stream );

  len = count;
  while(len-- > 0 && *s != 0)
  {
      __pformat_putc(*s++, stream);
  }

  while( stream->width-- > 0 )
    __pformat_putc( '\x20', stream );

#endif  /* __BUILD_WIDEAPI */
}

static
void __pformat_wcputs( const wchar_t *s, __pformat_t *stream )
{
  /* Handler for `%S' (`%ls') conversion specifications.
   *
   * Transfer a NUL terminated wide character string, character by
   * character, converting to its equivalent multibyte representation
   * on output, and stopping when the end of the string is encountered,
   * or if `precision' has been explicitly set, when the specified number
   * of characters has been emitted, if that is less than the length of
   * the input string, to the `__pformat()' output stream.
   *
   * This is implemented as a trivial call to `__pformat_wputchars()',
   * passing the length of the input string as the character count,
   * (after first verifying that the input pointer is not NULL).
   */
  if( s == NULL ) s = L"(null)";

  if( stream->precision >= 0 )
    __pformat_wputchars( s, wcsnlen( s, stream->precision ), stream );
  else
    __pformat_wputchars( s, wcslen( s ), stream );
}

static
int __pformat_int_bufsiz( int bias, int size, __pformat_t *stream )
{
  /* Helper to establish the size of the internal buffer, which
   * is required to queue the ASCII decomposition of an integral
   * data value, prior to transfer to the output stream.
   */
  size = ((size - 1 + LLONGBITS) / size) + bias;
  size += (stream->precision > 0) ? stream->precision : 0;
  if ((stream->flags & PFORMAT_GROUPED) != 0 && stream->thousands_chr != 0)
    size += (size / 3);
  return (size > stream->width) ? size : stream->width;
}

static
void __pformat_int( __pformat_intarg_t value, __pformat_t *stream )
{
  /* Handler for `%d', `%i' and `%u' conversion specifications.
   *
   * Transfer the ASCII representation of an integer value parameter,
   * formatted as a decimal number, to the `__pformat()' output queue;
   * output will be truncated, if any specified quota is exceeded.
   */
  int32_t bufflen = __pformat_int_bufsiz(1, PFORMAT_OSHIFT, stream);
#ifdef __ENABLE_PRINTF128
  char *tmp_buff = NULL;
#endif
  char *buf = NULL;
  char *p;
  int precision;

  buf = alloca(bufflen);
  p = buf;
  if( stream->flags & PFORMAT_NEGATIVE )
#ifdef __ENABLE_PRINTF128
  {
    /* The input value might be negative, (i.e. it is a signed value)...
     */
    if( value.__pformat_u128_t.t128.digits[1] < 0) {
      /*
       * It IS negative, but we want to encode it as unsigned,
       * displayed with a leading minus sign, so convert it...
       */
      /* two's complement */
      value.__pformat_u128_t.t128.digits[0] = ~value.__pformat_u128_t.t128.digits[0];
      value.__pformat_u128_t.t128.digits[1] = ~value.__pformat_u128_t.t128.digits[1];
      value.__pformat_u128_t.t128.digits[0] += 1;
      value.__pformat_u128_t.t128.digits[1] += (!value.__pformat_u128_t.t128.digits[0]) ? 1 : 0;
    } else
      /* It is unequivocally a POSITIVE value, so turn off the
       * request to prefix it with a minus sign...
       */
      stream->flags &= ~PFORMAT_NEGATIVE;
  }

  tmp_buff = alloca(bufflen);
  /* Encode the input value for display...
   */
  __bigint_to_string(value.__pformat_u128_t.t128_2.digits32,
    4, tmp_buff, bufflen);
  __bigint_trim_leading_zeroes(tmp_buff,1);

  memset(p,0,bufflen);
  for(int32_t i = strlen(tmp_buff) - 1; i >= 0; i--){
  if ( i && (stream->flags & PFORMAT_GROUPED) != 0 && stream->thousands_chr != 0
        && (i % 4) == 3)
      {
        *p++ = ',';
      }
      *p++ = tmp_buff[i];
    if( i > bufflen - 1) break; /* sanity chec */
    if(  tmp_buff[i] == '\0' ) break; /* end */
  }
#else
  {
    /* The input value might be negative, (i.e. it is a signed value)...
     */
    if( value.__pformat_llong_t < 0LL )
      /*
       * It IS negative, but we want to encode it as unsigned,
       * displayed with a leading minus sign, so convert it...
       */
      value.__pformat_llong_t = -value.__pformat_llong_t;

    else
      /* It is unequivocally a POSITIVE value, so turn off the
       * request to prefix it with a minus sign...
       */
      stream->flags &= ~PFORMAT_NEGATIVE;
  }
while( value.__pformat_ullong_t )
  {
    /* decomposing it into its constituent decimal digits,
     * in order from least significant to most significant, using
     * the local buffer as a LIFO queue in which to store them.
     */
    if (p != buf && (stream->flags & PFORMAT_GROUPED) != 0 && stream->thousands_chr != 0
        && ((p - buf) % 4) == 3)
      {
        *p++ = ',';
      }
    *p++ = '0' + (unsigned char)(value.__pformat_ullong_t % 10LL);
    value.__pformat_ullong_t /= 10LL;
  }
#endif

  if(  (stream->precision > 0)
  &&  ((precision = stream->precision - (p - buf)) > 0)  )
    /*
     * We have not yet queued sufficient digits to fill the field width
     * specified for minimum `precision'; pad with zeros to achieve this.
     */
    while( precision-- > 0 )
      *p++ = '0';

  if( (p == buf) && (stream->precision != 0) )
    /*
     * Input value was zero; make sure we print at least one digit,
     * unless the precision is also explicitly zero.
     */
    *p++ = '0';

  if( (stream->width > 0) && ((stream->width -= p - buf) > 0) )
  {
    /* We have now queued sufficient characters to display the input value,
     * at the desired precision, but this will not fill the output field...
     */
    if( stream->flags & PFORMAT_SIGNED )
      /*
       * We will fill one additional space with a sign...
       */
      stream->width--;

    if(  (stream->precision < 0)
    &&  ((stream->flags & PFORMAT_JUSTIFY) == PFORMAT_ZEROFILL)  )
      /*
       * and the `0' flag is in effect, so we pad the remaining spaces,
       * to the left of the displayed value, with zeros.
       */
      while( stream->width-- > 0 )
        *p++ = '0';

    else if( (stream->flags & PFORMAT_LJUSTIFY) == 0 )
      /*
       * the `0' flag is not in effect, and neither is the `-' flag,
       * so we pad to the left of the displayed value with spaces, so that
       * the value appears right justified within the output field.
       */
      while( stream->width-- > 0 )
        __pformat_putc( '\x20', stream );
  }

  if( stream->flags & PFORMAT_NEGATIVE )
    /*
     * A negative value needs a sign...
     */
    *p++ = '-';

  else if( stream->flags & PFORMAT_POSITIVE )
    /*
     * A positive value may have an optionally displayed sign...
     */
    *p++ = '+';

  else if( stream->flags & PFORMAT_ADDSPACE )
    /*
     * Space was reserved for displaying a sign, but none was emitted...
     */
    *p++ = '\x20';

  while( p > buf )
    /*
     * Emit the accumulated constituent digits,
     * in order from most significant to least significant...
     */
    __pformat_putc( *--p, stream );

  while( stream->width-- > 0 )
    /*
     * The specified output field has not yet been completely filled;
     * the `-' flag must be in effect, resulting in a displayed value which
     * appears left justified within the output field; we must pad the field
     * to the right of the displayed value, by emitting additional spaces,
     * until we reach the rightmost field boundary.
     */
    __pformat_putc( '\x20', stream );
}

static
void __pformat_xint( int fmt, __pformat_intarg_t value, __pformat_t *stream )
{
  /* Handler for `%o', `%p', `%x' and `%X' conversions.
   *
   * These can be implemented using a simple `mask and shift' strategy;
   * set up the mask and shift values appropriate to the conversion format,
   * and allocate a suitably sized local buffer, in which to queue encoded
   * digits of the formatted value, in preparation for output.
   */
  int width;
  int shift = (fmt == 'o') ? PFORMAT_OSHIFT : PFORMAT_XSHIFT;
  int bufflen = __pformat_int_bufsiz(2, shift, stream);
  char *buf = NULL;
#ifdef __ENABLE_PRINTF128
  char *tmp_buf = NULL;
#endif
  char *p;
  buf = alloca(bufflen);
  p = buf;
#ifdef __ENABLE_PRINTF128
  tmp_buf = alloca(bufflen);
  if(fmt == 'o'){
    __bigint_to_stringo(value.__pformat_u128_t.t128_2.digits32,4,tmp_buf,bufflen);
  } else {
    __bigint_to_stringx(value.__pformat_u128_t.t128_2.digits32,4,tmp_buf,bufflen, !(fmt & PFORMAT_XCASE));
  }
  __bigint_trim_leading_zeroes(tmp_buf,0);

  memset(buf,0,bufflen);
  for(int32_t i = strlen(tmp_buf); i >= 0; i--)
    *p++ = tmp_buf[i];
#else
  int mask = (fmt == 'o') ? PFORMAT_OMASK : PFORMAT_XMASK;
  while( value.__pformat_ullong_t )
  {
    /* Encode the specified non-zero input value as a sequence of digits,
     * in the appropriate `base' encoding and in reverse digit order, each
     * encoded in its printable ASCII form, with no leading zeros, using
     * the local buffer as a LIFO queue in which to store them.
     */
    char *q;
    if( (*(q = p++) = '0' + (value.__pformat_ullong_t & mask)) > '9' )
      *q = (*q + 'A' - '9' - 1) | (fmt & PFORMAT_XCASE);
    value.__pformat_ullong_t >>= shift;
  }
#endif

  if( p == buf )
    /*
     * Nothing was queued; input value must be zero, which should never be
     * emitted in the `alternative' PFORMAT_HASHED style.
     */
    stream->flags &= ~PFORMAT_HASHED;

  if( ((width = stream->precision) > 0) && ((width -= p - buf) > 0) )
    /*
     * We have not yet queued sufficient digits to fill the field width
     * specified for minimum `precision'; pad with zeros to achieve this.
     */
    while( width-- > 0 )
      *p++ = '0';

  else if( (fmt == 'o') && (stream->flags & PFORMAT_HASHED) )
    /*
     * The field width specified for minimum `precision' has already
     * been filled, but the `alternative' PFORMAT_HASHED style for octal
     * output requires at least one initial zero; that will not have
     * been queued, so add it now.
     */
    *p++ = '0';

  if( (p == buf) && (stream->precision != 0) )
    /*
     * Still nothing queued for output, but the `precision' has not been
     * explicitly specified as zero, (which is necessary if no output for
     * an input value of zero is desired); queue exactly one zero digit.
     */
    *p++ = '0';

  if( stream->width > (width = p - buf) )
    /*
     * Specified field width exceeds the minimum required...
     * Adjust so that we retain only the additional padding width.
     */
    stream->width -= width;

  else
    /* Ignore any width specification which is insufficient.
     */
    stream->width = PFORMAT_IGNORE;

  if( ((width = stream->width) > 0)
  &&  (fmt != 'o') && (stream->flags & PFORMAT_HASHED)  )
    /*
     * For `%#x' or `%#X' formats, (which have the `#' flag set),
     * further reduce the padding width to accommodate the radix
     * indicating prefix.
     */
    width -= 2;

  if(  (width > 0) && (stream->precision < 0)
  &&  ((stream->flags & PFORMAT_JUSTIFY) == PFORMAT_ZEROFILL)  )
    /*
     * When the `0' flag is set, and not overridden by the `-' flag,
     * or by a specified precision, add sufficient leading zeros to
     * consume the remaining field width.
     */
    while( width-- > 0 )
      *p++ = '0';

  if( (fmt != 'o') && (stream->flags & PFORMAT_HASHED) )
  {
    /* For formats other than octal, the PFORMAT_HASHED output style
     * requires the addition of a two character radix indicator, as a
     * prefix to the actual encoded numeric value.
     */
    *p++ = fmt;
    *p++ = '0';
  }

  if( (width > 0) && ((stream->flags & PFORMAT_LJUSTIFY) == 0) )
    /*
     * When not doing flush left justification, (i.e. the `-' flag
     * is not set), any residual unreserved field width must appear
     * as blank padding, to the left of the output value.
     */
    while( width-- > 0 )
      __pformat_putc( '\x20', stream );

  while( p > buf )
    /*
     * Move the queued output from the local buffer to the ultimate
     * destination, in LIFO order.
     */
    __pformat_putc( *--p, stream );

  /* If we still haven't consumed the entire specified field width,
   * we must be doing flush left justification; any residual width
   * must be filled with blanks, to the right of the output value.
   */
  while( width-- > 0 )
    __pformat_putc( '\x20', stream );
}

typedef union
{
  /* A multifaceted representation of an IEEE extended precision,
   * (80-bit), floating point number, facilitating access to its
   * component parts.
   */
  double                 __pformat_fpreg_double_t;
  long double            __pformat_fpreg_ldouble_t;
  struct
  { unsigned long long   __pformat_fpreg_mantissa;
    signed short         __pformat_fpreg_exponent;
  };
  unsigned short         __pformat_fpreg_bitmap[5];
  unsigned long          __pformat_fpreg_bits;
} __pformat_fpreg_t;

#ifdef _WIN32
/* TODO: make this unconditional in final release...
 * (see note at head of associated `#else' block.
 */
#include "../gdtoa/gdtoa.h"

static __pformat_fpreg_t init_fpreg_ldouble( long double val )
{
  __pformat_fpreg_t x;
  x.__pformat_fpreg_ldouble_t = val;

  if( sizeof( double ) == sizeof( long double ) )
  {
    /* Here, __pformat_fpreg_t expects to be initialized with a 80 bit long
     * double, but this platform doesn't have long doubles that differ from
     * regular 64 bit doubles. Therefore manually convert the 64 bit float
     * value to an 80 bit float value.
     */
    int exp = (x.__pformat_fpreg_mantissa >> 52) & 0x7ff;
    unsigned long long mant = x.__pformat_fpreg_mantissa & 0x000fffffffffffffULL;
    int topbit = exp ? 1 : 0;
    int signbit = x.__pformat_fpreg_mantissa >> 63;

    if (exp == 0x7ff)
      exp = 0x7fff;
    else if (exp != 0)
      exp = exp - 1023 + 16383;
    else if (mant != 0) {
      /* Denormal when stored as a 64 bit double, but becomes a normal when
       * converted to 80 bit long double form. */
      exp = 1 - 1023 + 16383;
      while (!(mant & 0x0010000000000000ULL)) {
        /* Normalize the mantissa. */
        mant <<= 1;
        exp--;
      }
      topbit = 1; /* The top bit, which is implicit in the 64 bit form. */
    }
    x.__pformat_fpreg_mantissa = (mant << 11) | ((unsigned long long)topbit << 63);
    x.__pformat_fpreg_exponent = exp | (signbit << 15);
  }

  return x;
}

static
char *__pformat_cvt( int mode, long double val, int nd, int *dp, int *sign )
{
  /* Helper function, derived from David M. Gay's `g_xfmt()', calling
   * his `__gdtoa()' function in a manner to provide extended precision
   * replacements for `ecvt()' and `fcvt()'.
   */
  int k; unsigned int e = 0; char *ep;
  static FPI fpi = { 64, 1-16383-64+1, 32766-16383-64+1, FPI_Round_near, 0, 14 /* Int_max */ };
  __pformat_fpreg_t x = init_fpreg_ldouble( val );

  k = __fpclassifyl( val );

  /* Classify the argument into an appropriate `__gdtoa()' category...
   */
  if( k & FP_NAN )
    /*
     * identifying infinities or not-a-number...
     */
    k = (k & FP_NORMAL) ? STRTOG_Infinite : STRTOG_NaN;

  else if( k & FP_NORMAL )
  {
    /* normal and near-zero `denormals'...
     */
    if( k & FP_ZERO )
    {
      /* with appropriate exponent adjustment for a `denormal'...
       */
      k = STRTOG_Denormal;
      e = 1 - 0x3FFF - 63;
    }
    else
    {
      /* or with `normal' exponent adjustment...
       */
      k = STRTOG_Normal;
      e = (x.__pformat_fpreg_exponent & 0x7FFF) - 0x3FFF - 63;
    }
  }

  else
    /* or, if none of the above, it's a zero, (positive or negative).
     */
    k = STRTOG_Zero;

  /* Check for negative values, always treating NaN as unsigned...
   * (return value is zero for positive/unsigned; non-zero for negative).
   */
  *sign = (k == STRTOG_NaN) ? 0 : x.__pformat_fpreg_exponent & 0x8000;

  /* Finally, get the raw digit string, and radix point position index.
   */
  return __gdtoa( &fpi, e, &x.__pformat_fpreg_bits, &k, mode, nd, dp, &ep );
}

static
char *__pformat_ecvt( long double x, int precision, int *dp, int *sign )
{
  /* A convenience wrapper for the above...
   * it emulates `ecvt()', but takes a `long double' argument.
   */
  return __pformat_cvt( 2, x, precision, dp, sign );
}

static
char *__pformat_fcvt( long double x, int precision, int *dp, int *sign )
{
  /* A convenience wrapper for the above...
   * it emulates `fcvt()', but takes a `long double' argument.
   */
  return __pformat_cvt( 3, x, precision, dp, sign );
}

/* The following are required, to clean up the `__gdtoa()' memory pool,
 * after processing the data returned by the above.
 */
#define __pformat_ecvt_release( value ) __freedtoa( value )
#define __pformat_fcvt_release( value ) __freedtoa( value )

#else
/*
 * TODO: remove this before final release; it is included here as a
 * convenience for testing, without requiring a working `__gdtoa()'.
 */
static
char *__pformat_ecvt( long double x, int precision, int *dp, int *sign )
{
  /* Define in terms of `ecvt()'...
   */
  char *retval = ecvt( (double)(x), precision, dp, sign );
  if( isinf( x ) || isnan( x ) )
  {
    /* emulating `__gdtoa()' reporting for infinities and NaN.
     */
    *dp = PFORMAT_INFNAN;
    if( *retval == '-' )
    {
      /* Need to force the `sign' flag, (particularly for NaN).
       */
      ++retval; *sign = 1;
    }
  }
  return retval;
}

static
char *__pformat_fcvt( long double x, int precision, int *dp, int *sign )
{
  /* Define in terms of `fcvt()'...
   */
  char *retval = fcvt( (double)(x), precision, dp, sign );
  if( isinf( x ) || isnan( x ) )
  {
    /* emulating `__gdtoa()' reporting for infinities and NaN.
     */
    *dp = PFORMAT_INFNAN;
    if( *retval == '-' )
    {
      /* Need to force the `sign' flag, (particularly for NaN).
       */
      ++retval; *sign = 1;
    }
  }
  return retval;
}

/* No memory pool clean up needed, for these emulated cases...
 */
#define __pformat_ecvt_release( value ) /* nothing to be done */
#define __pformat_fcvt_release( value ) /* nothing to be done */

/* TODO: end of conditional to be removed. */
#endif

static
void __pformat_emit_radix_point( __pformat_t *stream )
{
  /* Helper to place a localised representation of the radix point
   * character at the ultimate destination, when formatting fixed or
   * floating point numbers.
   */
  if( stream->rplen == PFORMAT_RPINIT )
  {
    /* Radix point initialisation not yet completed;
     * establish a multibyte to `wchar_t' converter...
     */
    int len; wchar_t rpchr; mbstate_t state;

    /* Initialise the conversion state...
     */
    memset( &state, 0, sizeof( state ) );

    /* Fetch and convert the localised radix point representation...
     */
    if( (len = mbrtowc( &rpchr, localeconv()->decimal_point, 16, &state )) > 0 )
      /*
       * and store it, if valid.
       */
      stream->rpchr = rpchr;

    /* In any case, store the reported effective multibyte length,
     * (or the error flag), marking initialisation as `done'.
     */
    stream->rplen = len;
  }

  if( stream->rpchr != (wchar_t)(0) )
  {
    /* We have a localised radix point mark;
     * establish a converter to make it a multibyte character...
     */
#ifdef __BUILD_WIDEAPI
   __pformat_putc (stream->rpchr, stream);
#else
    int len; char buf[len = stream->rplen]; mbstate_t state;

    /* Initialise the conversion state...
     */
    memset( &state, 0, sizeof( state ) );

    /* Convert the `wchar_t' representation to multibyte...
     */
    if( (len = wcrtomb( buf, stream->rpchr, &state )) > 0 )
    {
      /* and copy to the output destination, when valid...
       */
      char *p = buf;
      while( len-- > 0 )
        __pformat_putc( *p++, stream );
    }

    else
      /* otherwise fall back to plain ASCII '.'...
       */
      __pformat_putc( '.', stream );
#endif
  }
  else
    /* No localisation: just use ASCII '.'...
     */
    __pformat_putc( '.', stream );
}

static
void __pformat_emit_numeric_value( int c, __pformat_t *stream )
{
  /* Convenience helper to transfer numeric data from an internal
   * formatting buffer to the ultimate destination...
   */
  if( c == '.' )
    /*
     * converting this internal representation of the the radix
     * point to the appropriately localised representation...
     */
    __pformat_emit_radix_point( stream );
  else if (c == ',')
    {
      wchar_t wcs;
      if ((wcs = stream->thousands_chr) != 0)
        __pformat_wputchars (&wcs, 1, stream);
    }
  else
    /* and passing all other characters through, unmodified.
     */
    __pformat_putc( c, stream );
}

static
void __pformat_emit_inf_or_nan( int sign, char *value, __pformat_t *stream )
{
  /* Helper to emit INF or NAN where a floating point value
   * resolves to one of these special states.
   */
  int i;
  char buf[4];
  char *p = buf;

  /* We use the string formatting helper to display INF/NAN,
   * but we don't want truncation if the precision set for the
   * original floating point output request was insufficient;
   * ignore it!
   */
  stream->precision = PFORMAT_IGNORE;

  if( sign )
    /*
     * Negative infinity: emit the sign...
     */
    *p++ = '-';

  else if( stream->flags & PFORMAT_POSITIVE )
    /*
     * Not negative infinity, but '+' flag is in effect;
     * thus, we emit a positive sign...
     */
    *p++ = '+';

  else if( stream->flags & PFORMAT_ADDSPACE )
    /*
     * No sign required, but space was reserved for it...
     */
    *p++ = '\x20';

  /* Copy the appropriate status indicator, up to a maximum of
   * three characters, transforming to the case corresponding to
   * the format specification...
   */
  for( i = 3; i > 0; --i )
    *p++ = (*value++ & ~PFORMAT_XCASE) | (stream->flags & PFORMAT_XCASE);

  /* and emit the result.
   */
  __pformat_putchars( buf, p - buf, stream );
}

static
void __pformat_emit_float( int sign, char *value, int len, __pformat_t *stream )
{
  /* Helper to emit a fixed point representation of numeric data,
   * as encoded by a prior call to `ecvt()' or `fcvt()'; (this does
   * NOT include the exponent, for floating point format).
   */
  if( len > 0 )
  {
    /* The magnitude of `x' is greater than or equal to 1.0...
     * reserve space in the output field, for the required number of
     * decimal digits to be placed before the decimal point...
     */
    if( stream->width >= len)
      /*
       * adjusting as appropriate, when width is sufficient...
       */
      stream->width -= len;

    else
      /* or simply ignoring the width specification, if not.
       */
      stream->width = PFORMAT_IGNORE;
  }

  else if( stream->width > 0 )
    /*
     * The magnitude of `x' is less than 1.0...
     * reserve space for exactly one zero before the decimal point.
     */
    stream->width--;

  /* Reserve additional space for the digits which will follow the
   * decimal point...
   */
  if( (stream->width >= 0) && (stream->width > stream->precision) )
    /*
     * adjusting appropriately, when sufficient width remains...
     * (note that we must check both of these conditions, because
     * precision may be more negative than width, as a result of
     * adjustment to provide extra padding when trailing zeros
     * are to be discarded from "%g" format conversion with a
     * specified field width, but if width itself is negative,
     * then there is explicitly to be no padding anyway).
     */
    stream->width -= stream->precision;

  else
    /* or again, ignoring the width specification, if not.
     */
    stream->width = PFORMAT_IGNORE;

  /* Reserve space in the output field, for display of the decimal point,
   * unless the precision is explicity zero, with the `#' flag not set.
   */
  if ((stream->width > 0)
      && ((stream->precision > 0) || (stream->flags & PFORMAT_HASHED)))
    stream->width--;

  if (len > 0 && (stream->flags & PFORMAT_GROUPED) != 0 && stream->thousands_chr != 0)
    {
      int cths = ((len + 2) / 3) - 1;
      while (cths > 0 && stream->width > 0)
        {
          --cths; stream->width--;
        }
    }

  /* Reserve space in the output field, for display of the sign of the
   * formatted value, if required; (i.e. if the value is negative, or if
   * either the `space' or `+' formatting flags are set).
   */
  if( (stream->width > 0) && (sign || (stream->flags & PFORMAT_SIGNED)) )
    stream->width--;

  /* Emit any padding space, as required to correctly right justify
   * the output within the alloted field width.
   */
  if( (stream->width > 0) && ((stream->flags & PFORMAT_JUSTIFY) == 0) )
    while( stream->width-- > 0 )
      __pformat_putc( '\x20', stream );

  /* Emit the sign indicator, as appropriate...
   */
  if( sign )
    /*
     * mandatory, for negative values...
     */
    __pformat_putc( '-', stream );

  else if( stream->flags & PFORMAT_POSITIVE )
    /*
     * optional, for positive values...
     */
    __pformat_putc( '+', stream );

  else if( stream->flags & PFORMAT_ADDSPACE )
    /*
     * or just fill reserved space, when the space flag is in effect.
     */
    __pformat_putc( '\x20', stream );

  /* If the `0' flag is in effect, and not overridden by the `-' flag,
   * then zero padding, to fill out the field, goes here...
   */
  if(  (stream->width > 0)
  &&  ((stream->flags & PFORMAT_JUSTIFY) == PFORMAT_ZEROFILL)  )
    while( stream->width-- > 0 )
      __pformat_putc( '0', stream );

  /* Emit the digits of the encoded numeric value...
   */
  if( len > 0 )
  {
    /*
     * ...beginning with those which precede the radix point,
     * and appending any necessary significant trailing zeros.
     */
    do {
      __pformat_putc( *value ? *value++ : '0', stream);
      --len;
      if (len != 0 && (stream->flags & PFORMAT_GROUPED) != 0 && stream->thousands_chr != 0
          && (len % 3) == 0)
        __pformat_wputchars (&stream->thousands_chr, 1, stream);
    }
    while (len > 0);
  }
  else
    /* The magnitude of the encoded value is less than 1.0, so no
     * digits precede the radix point; we emit a mandatory initial
     * zero, followed immediately by the radix point.
     */
    __pformat_putc( '0', stream );

  /* Unless the encoded value is integral, AND the radix point
   * is not expressly demanded by the `#' flag, we must insert
   * the appropriately localised radix point mark here...
   */
  if( (stream->precision > 0) || (stream->flags & PFORMAT_HASHED) )
    __pformat_emit_radix_point( stream );

  /* When the radix point offset, `len', is negative, this implies
   * that additional zeros must appear, following the radix point,
   * and preceding the first significant digit...
   */
  if( len < 0 )
  {
    /* To accommodate these, we adjust the precision, (reducing it
     * by adding a negative value), and then we emit as many zeros
     * as are required.
     */
    stream->precision += len;
    do __pformat_putc( '0', stream );
       while( ++len < 0 );
  }

  /* Now we emit any remaining significant digits, or trailing zeros,
   * until the required precision has been achieved.
   */
  while( stream->precision-- > 0 )
    __pformat_putc( *value ? *value++ : '0', stream );
}

static
void __pformat_emit_efloat( int sign, char *value, int e, __pformat_t *stream )
{
  /* Helper to emit a floating point representation of numeric data,
   * as encoded by a prior call to `ecvt()' or `fcvt()'; (this DOES
   * include the following exponent).
   */
  int exp_width = 1;
  __pformat_intarg_t exponent; exponent.__pformat_llong_t = e -= 1;

  /* Determine how many digit positions are required for the exponent.
   */
  while( (e /= 10) != 0 )
    exp_width++;

  /* Ensure that this is at least as many as the standard requirement.
   * The C99 standard requires the expenent to contain at least two
   * digits, unless specified explicitly otherwise.
   */
  if (stream->expmin == -1)
    stream->expmin = 2;
  if( exp_width < stream->expmin )
    exp_width = stream->expmin;

  /* Adjust the residual field width allocation, to allow for the
   * number of exponent digits to be emitted, together with a sign
   * and exponent separator...
   */
  if( stream->width > (exp_width += 2) )
    stream->width -= exp_width;

  else
    /* ignoring the field width specification, if insufficient.
     */
    stream->width = PFORMAT_IGNORE;

  /* Emit the significand, as a fixed point value with one digit
   * preceding the radix point.
   */
  __pformat_emit_float( sign, value, 1, stream );

  /* Reset precision, to ensure the mandatory minimum number of
   * exponent digits will be emitted, and set the flags to ensure
   * the sign is displayed.
   */
  stream->precision = stream->expmin;
  stream->flags |= PFORMAT_SIGNED;

  /* Emit the exponent separator.
   */
  __pformat_putc( ('E' | (stream->flags & PFORMAT_XCASE)), stream );

  /* Readjust the field width setting, such that it again allows
   * for the digits of the exponent, (which had been discounted when
   * computing any left side padding requirement), so that they are
   * correctly included in the computation of any right side padding
   * requirement, (but here we exclude the exponent separator, which
   * has been emitted, and so counted already).
   */
  stream->width += exp_width - 1;

  /* And finally, emit the exponent itself, as a signed integer,
   * with any padding required to achieve flush left justification,
   * (which will be added automatically, by `__pformat_int()').
   */
  __pformat_int( exponent, stream );
}

static
void __pformat_float( long double x, __pformat_t *stream )
{
  /* Handler for `%f' and `%F' format specifiers.
   *
   * This wraps calls to `__pformat_cvt()', `__pformat_emit_float()'
   * and `__pformat_emit_inf_or_nan()', as appropriate, to achieve
   * output in fixed point format.
   */
  int sign, intlen; char *value;

  /* Establish the precision for the displayed value, defaulting to six
   * digits following the decimal point, if not explicitly specified.
   */
  if( stream->precision < 0 )
    stream->precision = 6;

  /* Encode the input value as ASCII, for display...
   */
  value = __pformat_fcvt( x, stream->precision, &intlen, &sign );

  if( intlen == PFORMAT_INFNAN )
    /*
     * handle cases of `infinity' or `not-a-number'...
     */
    __pformat_emit_inf_or_nan( sign, value, stream );

  else
  { /* or otherwise, emit the formatted result.
     */
    __pformat_emit_float( sign, value, intlen, stream );

    /* and, if there is any residual field width as yet unfilled,
     * then we must be doing flush left justification, so pad out to
     * the right hand field boundary.
     */
    while( stream->width-- > 0 )
      __pformat_putc( '\x20', stream );
  }

  /* Clean up `__pformat_fcvt()' memory allocation for `value'...
   */
  __pformat_fcvt_release( value );
}

#ifdef __ENABLE_DFP

typedef struct decimal128_decode {
  int64_t significand[2];
  int32_t exponent;
  int sig_neg;
  int exp_neg;
} decimal128_decode;

static uint32_t dec128_decode(decimal128_decode *result, const _Decimal128 deci){
  int64_t significand2;
  int64_t significand1;
  int32_t exp_part;
  int8_t sig_sign;
  ud128 in;
  in.d = deci;

  if(in.t0.bits == 0x3){ /*case 11 */
    /* should not enter here */
    sig_sign = in.t2.sign;
    exp_part = in.t2.exponent;
    significand1 = in.t2.mantissaL;
    significand2 = (in.t2.mantissaH | (0x1ULL << 49));
  } else {
    sig_sign = in.t1.sign;
    exp_part = in.t1.exponent;
    significand1 = in.t1.mantissaL;
    significand2 = in.t1.mantissaH;
  }
  exp_part -= 6176; /* exp bias */

  result->significand[0] = significand1;
  result->significand[1] = significand2; /* higher */
  result->exponent = exp_part;
  result->exp_neg = (exp_part < 0 )? 1 : 0;
  result->sig_neg = sig_sign;

  return 0;
}

static
void  __pformat_efloat_decimal(_Decimal128 x, __pformat_t *stream ){
  decimal128_decode in;
  char str_exp[8];
  char str_sig[40];
  int floatclass = __fpclassifyd128(x);

  /* precision control */
  int32_t prec = ( (stream->precision < 0) || (stream->precision > 38) ) ?
    6 : stream->precision;
  int32_t max_prec;
  int32_t exp_strlen;

  dec128_decode(&in,x);

  if((floatclass & FP_INFINITE) == FP_INFINITE){
    stream->precision = 3;
    if(stream->flags & PFORMAT_SIGNED)
      __pformat_putc( in.sig_neg ? '-' : '+', stream );
    __pformat_puts( (stream->flags & PFORMAT_XCASE) ? "inf" : "INF", stream);
    return;
  } else if(floatclass & FP_NAN){
    stream->precision = 3;
    if(stream->flags & PFORMAT_SIGNED)
      __pformat_putc( in.sig_neg ? '-' : '+', stream );
    __pformat_puts( (stream->flags & PFORMAT_XCASE) ? "nan" : "NAN", stream);
    return;
  }

  /* Stringify significand */
  __bigint_to_string(
    (uint32_t[4]){in.significand[0] & 0x0ffffffff, in.significand[0] >> 32, in.significand[1] & 0x0ffffffff, in.significand[1] >> 32 },
    4, str_sig, sizeof(str_sig));
  __bigint_trim_leading_zeroes(str_sig,1);
  max_prec = strlen(str_sig+1);

  /* Try to canonize exponent */
  in.exponent += max_prec;
  in.exp_neg = (in.exponent < 0 ) ? 1 : 0;

  /* stringify exponent */
  __bigint_to_string(
    (uint32_t[1]) { in.exp_neg ? -in.exponent : in.exponent},
    1, str_exp, sizeof(str_exp));
  exp_strlen = strlen(__bigint_trim_leading_zeroes(str_exp,3));

  /* account for dot, +-e */
  for(int32_t spacers = 0; spacers < stream->width - max_prec - exp_strlen - 4; spacers++)
    __pformat_putc( ' ', stream );

  /* optional sign */
  if (in.sig_neg || (stream->flags & PFORMAT_SIGNED)) {
    __pformat_putc( in.sig_neg ? '-' : '+', stream );
  } else if( stream->width - max_prec - exp_strlen - 4 > 0 ) {
    __pformat_putc( ' ', stream );
  }
  stream->width = 0;
  /* s.sss form */
  __pformat_putc(str_sig[0], stream);
  if(prec) {
    /* str_sig[prec+1] = '\0';*/
    __pformat_emit_radix_point(stream);
    __pformat_putchars(str_sig+1, prec, stream);

    /* Pad with 0s */
    for(int i = max_prec; i < prec; i++)
      __pformat_putc('0', stream);
  }

  stream->precision = exp_strlen; /* force puts to emit */

  __pformat_putc( ('E' | (stream->flags & PFORMAT_XCASE)), stream );
  __pformat_putc( in.exp_neg ? '-' : '+', stream );

  for(int32_t trailing = 0; trailing < 3 - exp_strlen; trailing++)
    __pformat_putc('0', stream);
  __pformat_putchars(str_exp, exp_strlen,stream);
}

static
void  __pformat_float_decimal(_Decimal128 x, __pformat_t *stream ){
  decimal128_decode in;
  char str_exp[8];
  char str_sig[40];
  int floatclass = __fpclassifyd128(x);

  /* precision control */
  int prec = ( (stream->precision < 0) || (stream->precision > 38) ) ?
    6 : stream->precision;
  int max_prec;

  dec128_decode(&in,x);

  if((floatclass & FP_INFINITE) == FP_INFINITE){
    stream->precision = 3;
    if(stream->flags & PFORMAT_SIGNED)
      __pformat_putc( in.sig_neg ? '-' : '+', stream );
    __pformat_puts( (stream->flags & PFORMAT_XCASE) ? "inf" : "INF", stream);
    return;
  } else if(floatclass & FP_NAN){
    stream->precision = 3;
    if(stream->flags & PFORMAT_SIGNED)
      __pformat_putc( in.sig_neg ? '-' : '+', stream );
    __pformat_puts( (stream->flags & PFORMAT_XCASE) ? "nan" : "NAN", stream);
    return;
  }

  /* Stringify significand */
  __bigint_to_string(
    (uint32_t[4]){in.significand[0] & 0x0ffffffff, in.significand[0] >> 32, in.significand[1] & 0x0ffffffff, in.significand[1] >> 32 },
    4, str_sig, sizeof(str_sig));
  __bigint_trim_leading_zeroes(str_sig,0);
  max_prec = strlen(str_sig);

  /* stringify exponent */
  __bigint_to_string(
    (uint32_t[1]) { in.exp_neg ? -in.exponent : in.exponent},
    1, str_exp, sizeof(str_exp));
  __bigint_trim_leading_zeroes(str_exp,0);

  int32_t decimal_place = max_prec + in.exponent;
  int32_t sig_written = 0;

  /*account for . +- */
  for(int32_t spacers = 0; spacers < stream->width - decimal_place - prec - 2; spacers++)
    __pformat_putc( ' ', stream );

  if (in.sig_neg || (stream->flags & PFORMAT_SIGNED)) {
    __pformat_putc( in.sig_neg ? '-' : '+', stream );
  } else if(stream->width - decimal_place - prec - 1 > 0){
    __pformat_putc( ' ', stream );
  }

  if(decimal_place <= 0){ /* easy mode */
    __pformat_putc( '0', stream );
    points:
    __pformat_emit_radix_point(stream);
    for(int32_t written = 0; written < prec; written++){
      if(decimal_place < 0){ /* leading 0s */
        decimal_place++;
        __pformat_putc( '0', stream );
      /* significand */
      } else if ( sig_written < max_prec ){
        __pformat_putc( str_sig[sig_written], stream );
        sig_written++;
      } else { /* trailing 0s */
        __pformat_putc( '0', stream );
      }
    }
  } else { /* hard mode */
    for(; sig_written < decimal_place; sig_written++){
      __pformat_putc( str_sig[sig_written], stream );
      if(sig_written == max_prec - 1) break;
    }
    decimal_place -= sig_written;
    for(; decimal_place > 0; decimal_place--)
      __pformat_putc( '0', stream );
      goto points;
  }

  return;
}

static
void  __pformat_gfloat_decimal(_Decimal128 x, __pformat_t *stream ){
  int prec = ( (stream->precision < 0)) ?
    6 : stream->precision;
  decimal128_decode in;
  dec128_decode(&in,x);
  if(in.exponent > prec) __pformat_efloat_decimal(x,stream);
  else __pformat_float_decimal(x,stream);
}

#endif /* __ENABLE_DFP */

static
void __pformat_efloat( long double x, __pformat_t *stream )
{
  /* Handler for `%e' and `%E' format specifiers.
   *
   * This wraps calls to `__pformat_cvt()', `__pformat_emit_efloat()'
   * and `__pformat_emit_inf_or_nan()', as appropriate, to achieve
   * output in floating point format.
   */
  int sign, intlen; char *value;

  /* Establish the precision for the displayed value, defaulting to six
   * digits following the decimal point, if not explicitly specified.
   */
  if( stream->precision < 0 )
    stream->precision = 6;

  /* Encode the input value as ASCII, for display...
   */
  value = __pformat_ecvt( x, stream->precision + 1, &intlen, &sign );

  if( intlen == PFORMAT_INFNAN )
    /*
     * handle cases of `infinity' or `not-a-number'...
     */
    __pformat_emit_inf_or_nan( sign, value, stream );

  else
    /* or otherwise, emit the formatted result.
     */
    __pformat_emit_efloat( sign, value, intlen, stream );

  /* Clean up `__pformat_ecvt()' memory allocation for `value'...
   */
  __pformat_ecvt_release( value );
}

static
void __pformat_gfloat( long double x, __pformat_t *stream )
{
  /* Handler for `%g' and `%G' format specifiers.
   *
   * This wraps calls to `__pformat_cvt()', `__pformat_emit_float()',
   * `__pformat_emit_efloat()' and `__pformat_emit_inf_or_nan()', as
   * appropriate, to achieve output in the more suitable of either
   * fixed or floating point format.
   */
  int sign, intlen; char *value;

  /* Establish the precision for the displayed value, defaulting to
   * six significant digits, if not explicitly specified...
   */
  if( stream->precision < 0 )
    stream->precision = 6;

  /* or to a minimum of one digit, otherwise...
   */
  else if( stream->precision == 0 )
    stream->precision = 1;

  /* Encode the input value as ASCII, for display.
   */
  value = __pformat_ecvt( x, stream->precision, &intlen, &sign );

  if( intlen == PFORMAT_INFNAN )
    /*
     * Handle cases of `infinity' or `not-a-number'.
     */
    __pformat_emit_inf_or_nan( sign, value, stream );

  else if( (-4 < intlen) && (intlen <= stream->precision) )
  {
    /* Value lies in the acceptable range for fixed point output,
     * (i.e. the exponent is no less than minus four, and the number
     * of significant digits which precede the radix point is fewer
     * than the least number which would overflow the field width,
     * specified or implied by the established precision).
     */
    if( (stream->flags & PFORMAT_HASHED) == PFORMAT_HASHED )
      /*
       * The `#' flag is in effect...
       * Adjust precision to retain the specified number of significant
       * digits, with the proper number preceding the radix point, and
       * the balance following it...
       */
      stream->precision -= intlen;

    else
      /* The `#' flag is not in effect...
       * Here we adjust the precision to accommodate all digits which
       * precede the radix point, but we truncate any balance following
       * it, to suppress output of non-significant trailing zeros...
       */
      if( ((stream->precision = strlen( value ) - intlen) < 0)
        /*
         * This may require a compensating adjustment to the field
         * width, to accommodate significant trailing zeros, which
         * precede the radix point...
         */
      && (stream->width > 0)  )
        stream->width += stream->precision;

    /* Now, we format the result as any other fixed point value.
     */
    __pformat_emit_float( sign, value, intlen, stream );

    /* If there is any residual field width as yet unfilled, then
     * we must be doing flush left justification, so pad out to the
     * right hand field boundary.
     */
    while( stream->width-- > 0 )
      __pformat_putc( '\x20', stream );
  }

  else
  { /* Value lies outside the acceptable range for fixed point;
     * one significant digit will precede the radix point, so we
     * decrement the precision to retain only the appropriate number
     * of additional digits following it, when we emit the result
     * in floating point format.
     */
    if( (stream->flags & PFORMAT_HASHED) == PFORMAT_HASHED )
      /*
       * The `#' flag is in effect...
       * Adjust precision to emit the specified number of significant
       * digits, with one preceding the radix point, and the balance
       * following it, retaining any non-significant trailing zeros
       * which are required to exactly match the requested precision...
       */
      stream->precision--;

    else
      /* The `#' flag is not in effect...
       * Adjust precision to emit only significant digits, with one
       * preceding the radix point, and any others following it, but
       * suppressing non-significant trailing zeros...
       */
      stream->precision = strlen( value ) - 1;

    /* Now, we format the result as any other floating point value.
     */
    __pformat_emit_efloat( sign, value, intlen, stream );
  }

  /* Clean up `__pformat_ecvt()' memory allocation for `value'.
   */
  __pformat_ecvt_release( value );
}

static
void __pformat_emit_xfloat( __pformat_fpreg_t value, __pformat_t *stream )
{
  /* Helper for emitting floating point data, originating as
   * either `double' or `long double' type, as a hexadecimal
   * representation of the argument value.
   */
  char buf[18 + 6], *p = buf;
  __pformat_intarg_t exponent; short exp_width = 2;

  if (value.__pformat_fpreg_mantissa != 0 ||
     value.__pformat_fpreg_exponent != 0)
  {
    /* Reduce the exponent since the leading digit emited will start at
     * the 4th bit from the highest order bit instead, the later being
     * the leading digit of the floating point. Don't do this adjustment
     * if the value is an actual zero.
     */
    value.__pformat_fpreg_exponent -= 3;
  }

  /* The mantissa field of the argument value representation can
   * accommodate at most 16 hexadecimal digits, of which one will
   * be placed before the radix point, leaving at most 15 digits
   * to satisfy any requested precision; thus...
   */
  if( (stream->precision >= 0) && (stream->precision < 15) )
  {
    /* When the user specifies a precision within this range,
     * we want to adjust the mantissa, to retain just the number
     * of digits required, rounding up when the high bit of the
     * leftmost discarded digit is set; (mask of 0x08 accounts
     * for exactly one digit discarded, shifting 4 bits per
     * digit, with up to 14 additional digits, to consume the
     * full availability of 15 precision digits).
     */

    /* We then shift the mantissa one bit position back to the
     * right, to guard against possible overflow when the rounding
     * adjustment is added.
     */
    value.__pformat_fpreg_mantissa >>= 1;

    /* We now add the rounding adjustment, noting that to keep the
     * 0x08 mask aligned with the shifted mantissa, we also need to
     * shift it right by one bit initially, changing its starting
     * value to 0x04...
     */
    value.__pformat_fpreg_mantissa += 0x04LL << (4 * (14 - stream->precision));
    if( (value.__pformat_fpreg_mantissa & (LLONG_MAX + 1ULL)) == 0ULL )
      /*
       * When the rounding adjustment would not have overflowed,
       * then we shift back to the left again, to fill the vacated
       * bit we reserved to accommodate the carry.
       */
      value.__pformat_fpreg_mantissa <<= 1;

    else
    {
      /* Otherwise the rounding adjustment would have overflowed,
       * so the carry has already filled the vacated bit; the effect
       * of this is equivalent to an increment of the exponent. We will
       * discard a whole digit to match glibc's behavior.
       */
      value.__pformat_fpreg_exponent += 4;
      value.__pformat_fpreg_mantissa >>= 3;
    }

    /* We now complete the rounding to the required precision, by
     * shifting the unwanted digits out, from the right hand end of
     * the mantissa.
     */
    value.__pformat_fpreg_mantissa >>= 4 * (15 - stream->precision);
  }

  /* Don't print anything if mantissa is zero unless we have to satisfy
   * desired precision.
   */
  if( value.__pformat_fpreg_mantissa || stream->precision > 0 )
  {
    /* Encode the significant digits of the mantissa in hexadecimal
     * ASCII notation, ready for transfer to the output stream...
     */
    for( int i=stream->precision >= 15 || stream->precision < 0 ? 16 : stream->precision + 1; i>0; --i )
    {
      /* taking the rightmost digit in each pass...
       */
      unsigned c = value.__pformat_fpreg_mantissa & 0xF;
      if( i == 1 )
      {
        /* inserting the radix point, when we reach the last,
         * (i.e. the most significant digit), unless we found no
         * less significant digits, with no mandatory radix point
         * inclusion, and no additional required precision...
         */
        if( (p > buf)
        ||  (stream->flags & PFORMAT_HASHED) || (stream->precision > 0)  )
        {
          /*
           * Internally, we represent the radix point as an ASCII '.';
           * we will replace it with any locale specific alternative,
           * at the time of transfer to the ultimate destination.
           */
          *p++ = '.';
        }
      }

      else if( stream->precision > 0 )
        /*
        * we have not yet fulfilled the desired precision,
        * and we have not yet found the most significant digit,
        * so account for the current digit, within the field
        * width required to meet the specified precision.
        */
        stream->precision--;

      if( (c > 0) || (p > buf) || (stream->precision >= 0) )
      {
        /*
         * Ignoring insignificant trailing zeros, (unless required to
         * satisfy specified precision), store the current encoded digit
         * into the pending output buffer, in LIFO order, and using the
         * appropriate case for digits in the `A'..`F' range.
         */
        *p++ = c > 9 ? (c - 10 + 'A') | (stream->flags & PFORMAT_XCASE) : c + '0';
      }
      /* Shift out the current digit, (4-bit logical shift right),
       * to align the next more significant digit to be extracted,
       * and encoded in the next pass.
       */
      value.__pformat_fpreg_mantissa >>= 4;
    }
  }

  if( p == buf )
  {
    /* Nothing has been queued for output...
     * We need at least one zero, and possibly a radix point.
     */
    if( (stream->precision > 0) || (stream->flags & PFORMAT_HASHED) )
      *p++ = '.';

    *p++ = '0';
  }

  if( stream->width > 0 )
  {
  /* Adjust the user specified field width, to account for the
   * number of digits minimally required, to display the encoded
   * value, at the requested precision.
   *
   * FIXME: this uses the minimum number of digits possible for
   * representation of the binary exponent, in strict conformance
   * with C99 and POSIX specifications.  Although there appears to
   * be no Microsoft precedent for doing otherwise, we may wish to
   * relate this to the `_get_output_format()' result, to maintain
   * consistency with `%e', `%f' and `%g' styles.
   */
    int min_width = p - buf;
    int exponent2 = value.__pformat_fpreg_exponent;

    /* If we have not yet queued sufficient digits to fulfil the
     * requested precision, then we must adjust the minimum width
     * specification, to accommodate the additional digits which
     * are required to do so.
     */
    if( stream->precision > 0 )
      min_width += stream->precision;

    /* Adjust the minimum width requirement, to accomodate the
     * sign, radix indicator and at least one exponent digit...
     */
    min_width += stream->flags & PFORMAT_SIGNED ? 6 : 5;
    while( (exponent2 = exponent2 / 10) != 0 )
    {
      /* and increase as required, if additional exponent digits
       * are needed, also saving the exponent field width adjustment,
       * for later use when that is emitted.
       */
      min_width++;
      exp_width++;
    }

    if( stream->width > min_width )
    {
      /* When specified field width exceeds the minimum required,
       * adjust to retain only the excess...
       */
      stream->width -= min_width;

      /* and then emit any required left side padding spaces.
       */
      if( (stream->flags & PFORMAT_JUSTIFY) == 0 )
        while( stream->width-- > 0 )
          __pformat_putc( '\x20', stream );
    }

    else
      /* Specified field width is insufficient; just ignore it!
       */
      stream->width = PFORMAT_IGNORE;
  }

  /* Emit the sign of the encoded value, as required...
   */
  if( stream->flags & PFORMAT_NEGATIVE )
    /*
     * this is mandatory, to indicate a negative value...
     */
    __pformat_putc( '-', stream );

  else if( stream->flags & PFORMAT_POSITIVE )
    /*
     * but this is optional, for a positive value...
     */
    __pformat_putc( '+', stream );

  else if( stream->flags & PFORMAT_ADDSPACE )
    /*
     * with this optional alternative.
     */
    __pformat_putc( '\x20', stream );

  /* Prefix a `0x' or `0X' radix indicator to the encoded value,
   * with case appropriate to the format specification.
   */
  __pformat_putc( '0', stream );
  __pformat_putc( 'X' | (stream->flags & PFORMAT_XCASE), stream );

  /* If the `0' flag is in effect...
   * Zero padding, to fill out the field, goes here...
   */
  if( (stream->width > 0) && (stream->flags & PFORMAT_ZEROFILL) )
    while( stream->width-- > 0 )
      __pformat_putc( '0', stream );

  /* Next, we emit the encoded value, without its exponent...
   */
  while( p > buf )
    __pformat_emit_numeric_value( *--p, stream );

  /* followed by any additional zeros needed to satisfy the
   * precision specification...
   */
  while( stream->precision-- > 0 )
    __pformat_putc( '0', stream );

  /* then the exponent prefix, (C99 and POSIX specify `p'),
   * in the case appropriate to the format specification...
   */
  __pformat_putc( 'P' | (stream->flags & PFORMAT_XCASE), stream );

  /* and finally, the decimal representation of the binary exponent,
   * as a signed value with mandatory sign displayed, in a field width
   * adjusted to accommodate it, LEFT justified, with any additional
   * right side padding remaining from the original field width.
   */
  stream->width += exp_width;
  stream->flags |= PFORMAT_SIGNED;
  /* sign extend */
  exponent.__pformat_u128_t.t128.digits[1] = (value.__pformat_fpreg_exponent < 0) ? -1 : 0;
  exponent.__pformat_u128_t.t128.digits[0] = value.__pformat_fpreg_exponent;
  __pformat_int( exponent, stream );
}

static
void __pformat_xldouble( long double x, __pformat_t *stream )
{
  /* Handler for `%La' and `%LA' format specifiers, (with argument
   * value specified as `long double' type).
   */
  unsigned sign_bit = 0;
  __pformat_fpreg_t z = init_fpreg_ldouble( x );

  /* First check for NaN; it is emitted unsigned...
   */
  if( isnan( x ) )
    __pformat_emit_inf_or_nan( sign_bit, "NaN", stream );

  else
  { /* Capture the sign bit up-front, so we can show it correctly
     * even when the argument value is zero or infinite.
     */
    if( (sign_bit = (z.__pformat_fpreg_exponent & 0x8000)) != 0 )
      stream->flags |= PFORMAT_NEGATIVE;

    /* Check for infinity, (positive or negative)...
     */
    if( isinf( x ) )
      /*
       * displaying the appropriately signed indicator,
       * when appropriate.
       */
      __pformat_emit_inf_or_nan( sign_bit, "Inf", stream );

    else
    { /* The argument value is a representable number...
       * extract the effective value of the biased exponent...
       */
      z.__pformat_fpreg_exponent &= 0x7FFF;
      if( z.__pformat_fpreg_exponent == 0 )
      {
        /* A biased exponent value of zero means either a
         * true zero value, if the mantissa field also has
         * a zero value, otherwise...
         */
        if( z.__pformat_fpreg_mantissa != 0 )
        {
          /* ...this mantissa represents a subnormal value.
           */
          z.__pformat_fpreg_exponent = 1 - 0x3FFF;
        }
      }
      else
        /* This argument represents a non-zero normal number;
         * eliminate the bias from the exponent...
         */
        z.__pformat_fpreg_exponent -= 0x3FFF;

      /* Finally, hand the adjusted representation off to the
       * generalised hexadecimal floating point format handler...
       */
      __pformat_emit_xfloat( z, stream );
    }
  }
}

static
void __pformat_xdouble( double x, __pformat_t *stream )
{
  /* Handler for `%la' and `%lA' format specifiers, (with argument
   * value specified as `double' type).
   */
  unsigned sign_bit = 0;
  __pformat_fpreg_t z = init_fpreg_ldouble( (long double)x );

  /* First check for NaN; it is emitted unsigned...
   */
  if( isnan( x ) )
    __pformat_emit_inf_or_nan( sign_bit, "NaN", stream );

  else
  { /* Capture the sign bit up-front, so we can show it correctly
     * even when the argument value is zero or infinite.
     */
    if( (sign_bit = (z.__pformat_fpreg_exponent & 0x8000)) != 0 )
      stream->flags |= PFORMAT_NEGATIVE;

    /* Check for infinity, (positive or negative)...
     */
    if( isinf( x ) )
      /*
       * displaying the appropriately signed indicator,
       * when appropriate.
       */
      __pformat_emit_inf_or_nan( sign_bit, "Inf", stream );

    else
    { /* The argument value is a representable number...
       * extract the effective value of the biased exponent...
       */
      z.__pformat_fpreg_exponent &= 0x7FFF;

      /* If the double value was a denormalized number, it might have been renormalized by
       * the conversion to long double. We will redenormalize it.
       */
      if( z.__pformat_fpreg_exponent != 0 && z.__pformat_fpreg_exponent <= (0x3FFF - 0x3FF) )
      {
        int shifted = (0x3FFF - 0x3FF) - z.__pformat_fpreg_exponent + 1;
        z.__pformat_fpreg_mantissa >>= shifted;
        z.__pformat_fpreg_exponent += shifted;
      }

      if( z.__pformat_fpreg_exponent == 0 )
      {
        /* A biased exponent value of zero means either a
         * true zero value, if the mantissa field also has
         * a zero value, otherwise...
         */
        if( z.__pformat_fpreg_mantissa != 0 )
        {
          /* ...this mantissa represents a subnormal value.
           */
          z.__pformat_fpreg_exponent = 1 - 0x3FF + 3;
        }
      }
      else
        /* This argument represents a non-zero normal number;
         * eliminate the bias from the exponent...
         */
        z.__pformat_fpreg_exponent -= 0x3FFF - 3;

      /* Shift the mantissa so the leading 4 bits digit is 0 or 1.
       * The exponent was also adjusted by 3 previously.
       */
      z.__pformat_fpreg_mantissa >>= 3;

      /* Finally, hand the adjusted representation off to the
       * generalised hexadecimal floating point format handler...
       */
      __pformat_emit_xfloat( z, stream );
    }
  }
}

int
__pformat (int flags, void *dest, int max, const APICHAR *fmt, va_list argv)
{
  int c;
  int saved_errno = errno;

  __pformat_t stream =
  {
    /* Create and initialise a format control block
     * for this output request.
     */
    dest,                                       /* output goes to here        */
    flags &= PFORMAT_TO_FILE | PFORMAT_NOLIMIT, /* only these valid initially */
    PFORMAT_IGNORE,                             /* no field width yet         */
    PFORMAT_IGNORE,                             /* nor any precision spec     */
    PFORMAT_RPINIT,                             /* radix point uninitialised  */
    (wchar_t)(0),                               /* leave it unspecified       */
    0,
    (wchar_t)(0),                               /* leave it unspecified       */
    0,                                          /* zero output char count     */
    max,                                        /* establish output limit     */
    -1                                          /* exponent chars preferred;
                                                   -1 means to be determined. */
  };

#ifdef __BUILD_WIDEAPI
  const APICHAR *literal_string_start = NULL;
#endif

  format_scan: while( (c = *fmt++) != 0 )
  {
    /* Format string parsing loop...
     * The entry point is labelled, so that we can return to the start state
     * from within the inner `conversion specification' interpretation loop,
     * as soon as a conversion specification has been resolved.
     */
    if( c == '%' )
    {
      /* Initiate parsing of a `conversion specification'...
       */
      __pformat_intarg_t argval;
      __pformat_state_t  state = PFORMAT_INIT;
      __pformat_length_t length = PFORMAT_LENGTH_INT;

      /* Save the current format scan position, so that we can backtrack
       * in the event of encountering an invalid format specification...
       */
      const APICHAR *backtrack = fmt;

      /* Restart capture for dynamic field width and precision specs...
       */
      int *width_spec = &stream.width;

  #ifdef __BUILD_WIDEAPI
      if (literal_string_start)
      {
        stream.width = stream.precision = PFORMAT_IGNORE;
        __pformat_wputchars( literal_string_start, fmt - literal_string_start - 1, &stream );
        literal_string_start = NULL;
      }
  #endif

      /* Reset initial state for flags, width and precision specs...
       */
      stream.flags = flags;
      stream.width = stream.precision = PFORMAT_IGNORE;

      while( *fmt )
      {
        switch( c = *fmt++ )
        {
          /* Data type specifiers...
           * All are terminal, so exit the conversion spec parsing loop
           * with a `goto format_scan', thus resuming at the outer level
           * in the regular format string parser.
           */
          case '%':
            /*
             * Not strictly a data type specifier...
             * it simply converts as a literal `%' character.
             *
             * FIXME: should we require this to IMMEDIATELY follow the
             * initial `%' of the "conversion spec"?  (glibc `printf()'
             * on GNU/Linux does NOT appear to require this, but POSIX
             * and SUSv3 do seem to demand it).
             */
    #ifndef __BUILD_WIDEAPI
            __pformat_putc( c, &stream );
    #else
        stream.width = stream.precision = PFORMAT_IGNORE;
        __pformat_wputchars( L"%", 1, &stream );
    #endif
            goto format_scan;

          case 'C':
            /*
             * Equivalent to `%lc'; set `length' accordingly,
             * and simply fall through.
             */
            length = PFORMAT_LENGTH_LONG;

          case 'c':
            /*
             * Single, (or single multibyte), character output...
             *
             * We handle these by copying the argument into our local
             * `argval' buffer, and then we pass the address of that to
             * either `__pformat_putchars()' or `__pformat_wputchars()',
             * as appropriate, effectively formatting it as a string of
             * the appropriate type, with a length of one.
             *
             * A side effect of this method of handling character data
             * is that, if the user sets a precision of zero, then no
             * character is actually emitted; we don't want that, so we
             * forcibly override any user specified precision.
             */
            stream.precision = PFORMAT_IGNORE;

            /* Now we invoke the appropriate format handler...
             */
            if( (length == PFORMAT_LENGTH_LONG)
            ||  (length == PFORMAT_LENGTH_LLONG)  )
            {
              /* considering any `long' type modifier as a reference to
               * `wchar_t' data, (which is promoted to an `int' argument)...
               */
              wchar_t iargval = (wchar_t)(va_arg( argv, int ));
              __pformat_wputchars( &iargval, 1, &stream );
            }
            else
            { /* while anything else is simply taken as `char', (which
               * is also promoted to an `int' argument)...
               */
              argval.__pformat_uchar_t = (unsigned char)(va_arg( argv, int ));
              __pformat_putchars( (char *)(&argval), 1, &stream );
            }
            goto format_scan;

          case 'S':
            /*
             * Equivalent to `%ls'; set `length' accordingly,
             * and simply fall through.
             */
            length = PFORMAT_LENGTH_LONG;

          case 's':
            if( (length == PFORMAT_LENGTH_LONG)
                 || (length == PFORMAT_LENGTH_LLONG))
            {
              /* considering any `long' type modifier as a reference to
               * a `wchar_t' string...
               */
              __pformat_wcputs( va_arg( argv, wchar_t * ), &stream );
            }
            else
              /* This is normal string output;
               * we simply invoke the appropriate handler...
               */
              __pformat_puts( va_arg( argv, char * ), &stream );
            goto format_scan;
          case 'm': /* strerror (errno)  */
            __pformat_puts (strerror (saved_errno), &stream);
            goto format_scan;

          case 'o':
          case 'u':
          case 'x':
          case 'X':
            /*
             * Unsigned integer values; octal, decimal or hexadecimal format...
             */
            stream.flags &= ~PFORMAT_POSITIVE;
#if __ENABLE_PRINTF128
        argval.__pformat_u128_t.t128.digits[1] = 0LL; /* no sign extend needed */
            if( length == PFORMAT_LENGTH_LLONG128 )
              argval.__pformat_u128_t.t128 = va_arg( argv, __tI128 );
            else
#endif
        if( length == PFORMAT_LENGTH_LLONG ) {
              /*
               * with an `unsigned long long' argument, which we
               * process `as is'...
               */
              argval.__pformat_ullong_t = va_arg( argv, unsigned long long );

            } else if( length == PFORMAT_LENGTH_LONG ) {
              /*
               * or with an `unsigned long', which we promote to
               * `unsigned long long'...
               */
              argval.__pformat_ullong_t = va_arg( argv, unsigned long );

            } else
            { /* or for any other size, which will have been promoted
               * to `unsigned int', we select only the appropriately sized
               * least significant segment, and again promote to the same
               * size as `unsigned long long'...
               */
              argval.__pformat_ullong_t = va_arg( argv, unsigned int );
              if( length == PFORMAT_LENGTH_SHORT )
                /*
                 * from `unsigned short'...
                 */
                argval.__pformat_ullong_t = argval.__pformat_ushort_t;

              else if( length == PFORMAT_LENGTH_CHAR )
                /*
                 * or even from `unsigned char'...
                 */
                argval.__pformat_ullong_t = argval.__pformat_uchar_t;
            }

            /* so we can pass any size of argument to either of two
             * common format handlers...
             */
            if( c == 'u' )
              /*
               * depending on whether output is to be encoded in
               * decimal format...
               */
              __pformat_int( argval, &stream );

            else
              /* or in octal or hexadecimal format...
               */
              __pformat_xint( c, argval, &stream );

            goto format_scan;

          case 'd':
          case 'i':
            /*
             * Signed integer values; decimal format...
             * This is similar to `u', but must process `argval' as signed,
             * and be prepared to handle negative numbers.
             */
            stream.flags |= PFORMAT_NEGATIVE;
#if __ENABLE_PRINTF128
            if( length == PFORMAT_LENGTH_LLONG128 ) {
              argval.__pformat_u128_t.t128 = va_arg( argv, __tI128 );
          goto skip_sign; /* skip sign extend */
            } else
#endif
            if( length == PFORMAT_LENGTH_LLONG ){
              /*
               * The argument is a `long long' type...
               */
              argval.__pformat_u128_t.t128.digits[0] = va_arg( argv, long long );
            } else if( length == PFORMAT_LENGTH_LONG ) {
              /*
               * or here, a `long' type...
               */
              argval.__pformat_u128_t.t128.digits[0] = va_arg( argv, long );
            } else
            { /* otherwise, it's an `int' type...
               */
              argval.__pformat_u128_t.t128.digits[0] = va_arg( argv, int );
              if( length == PFORMAT_LENGTH_SHORT )
                /*
                 * but it was promoted from a `short' type...
                 */
                argval.__pformat_u128_t.t128.digits[0] = argval.__pformat_short_t;
              else if( length == PFORMAT_LENGTH_CHAR )
                /*
                 * or even from a `char' type...
                 */
                argval.__pformat_u128_t.t128.digits[0] = argval.__pformat_char_t;
            }

            /* In any case, all share a common handler...
             */
        argval.__pformat_u128_t.t128.digits[1] = (argval.__pformat_llong_t < 0) ? -1LL : 0LL;
#if __ENABLE_PRINTF128
        skip_sign:
#endif
            __pformat_int( argval, &stream );
            goto format_scan;

          case 'p':
            /*
             * Pointer argument; format as hexadecimal, subject to...
             */
            if( (state == PFORMAT_INIT) && (stream.flags == flags) )
            {
              /* Here, the user didn't specify any particular
               * formatting attributes.  We must choose a default
               * which will be compatible with Microsoft's (broken)
               * scanf() implementation, (i.e. matching the default
               * used by MSVCRT's printf(), which appears to resemble
               * "%0.8X" for 32-bit pointers); in particular, we MUST
               * NOT adopt a GNU-like format resembling "%#x", because
               * Microsoft's scanf() will choke on the "0x" prefix.
               */
              stream.flags |= PFORMAT_ZEROFILL;
              stream.precision = 2 * sizeof( uintptr_t );
            }
            argval.__pformat_u128_t.t128.digits[0] = va_arg( argv, uintptr_t );
            argval.__pformat_u128_t.t128.digits[1] = 0;
            __pformat_xint( 'x', argval, &stream );
            goto format_scan;

          case 'e':
            /*
             * Floating point format, with lower case exponent indicator
             * and lower case `inf' or `nan' representation when required;
             * select lower case mode, and simply fall through...
             */
            stream.flags |= PFORMAT_XCASE;

          case 'E':
            /*
             * Floating point format, with upper case exponent indicator
             * and upper case `INF' or `NAN' representation when required,
             * (or lower case for all of these, on fall through from above);
             * select lower case mode, and simply fall through...
             */
#ifdef __ENABLE_DFP
            if( stream.flags & PFORMAT_DECIM32 )
              /* Is a 32bit decimal float */
              __pformat_efloat_decimal((_Decimal128)va_arg( argv, _Decimal32 ), &stream );
            else if( stream.flags & PFORMAT_DECIM64 )
              /*
               * Is a 64bit decimal float
               */
              __pformat_efloat_decimal((_Decimal128)va_arg( argv, _Decimal64 ), &stream );
            else if( stream.flags & PFORMAT_DECIM128 )
              /*
               * Is a 128bit decimal float
               */
              __pformat_efloat_decimal(va_arg( argv, _Decimal128 ), &stream );
            else
#endif /* __ENABLE_DFP */
            if( stream.flags & PFORMAT_LDOUBLE )
              /*
               * for a `long double' argument...
               */
              __pformat_efloat( va_arg( argv, long double ), &stream );

            else
              /* or just a `double', which we promote to `long double',
               * so the two may share a common format handler.
               */
              __pformat_efloat( (long double)(va_arg( argv, double )), &stream );

            goto format_scan;

          case 'f':
            /*
             * Fixed point format, using lower case for `inf' and
             * `nan', when appropriate; select lower case mode, and
             * simply fall through...
             */
            stream.flags |= PFORMAT_XCASE;

          case 'F':
            /*
             * Fixed case format using upper case, or lower case on
             * fall through from above, for `INF' and `NAN'...
             */
#ifdef __ENABLE_DFP
            if( stream.flags & PFORMAT_DECIM32 )
              /* Is a 32bit decimal float */
              __pformat_float_decimal((_Decimal128)va_arg( argv, _Decimal32 ), &stream );
            else if( stream.flags & PFORMAT_DECIM64 )
              /*
               * Is a 64bit decimal float
               */
              __pformat_float_decimal((_Decimal128)va_arg( argv, _Decimal64 ), &stream );
            else if( stream.flags & PFORMAT_DECIM128 )
              /*
               * Is a 128bit decimal float
               */
              __pformat_float_decimal(va_arg( argv, _Decimal128 ), &stream );
            else
#endif /* __ENABLE_DFP */
            if( stream.flags & PFORMAT_LDOUBLE )
              /*
               * for a `long double' argument...
               */
              __pformat_float( va_arg( argv, long double ), &stream );

            else
              /* or just a `double', which we promote to `long double',
               * so the two may share a common format handler.
               */
              __pformat_float( (long double)(va_arg( argv, double )), &stream );

            goto format_scan;

          case 'g':
            /*
             * Generalised floating point format, with lower case
             * exponent indicator when required; select lower case
             * mode, and simply fall through...
             */
            stream.flags |= PFORMAT_XCASE;

          case 'G':
            /*
             * Generalised floating point format, with upper case,
             * or on fall through from above, with lower case exponent
             * indicator when required...
             */
#ifdef __ENABLE_DFP
            if( stream.flags & PFORMAT_DECIM32 )
              /* Is a 32bit decimal float */
              __pformat_gfloat_decimal((_Decimal128)va_arg( argv, _Decimal32 ), &stream );
            else if( stream.flags & PFORMAT_DECIM64 )
              /*
               * Is a 64bit decimal float
               */
              __pformat_gfloat_decimal((_Decimal128)va_arg( argv, _Decimal64 ), &stream );
            else if( stream.flags & PFORMAT_DECIM128 )
              /*
               * Is a 128bit decimal float
               */
              __pformat_gfloat_decimal(va_arg( argv, _Decimal128 ), &stream );
            else
#endif /* __ENABLE_DFP */
           if( stream.flags & PFORMAT_LDOUBLE )
              /*
               * for a `long double' argument...
               */
              __pformat_gfloat( va_arg( argv, long double ), &stream );

            else
              /* or just a `double', which we promote to `long double',
               * so the two may share a common format handler.
               */
              __pformat_gfloat( (long double)(va_arg( argv, double )), &stream );

            goto format_scan;

          case 'a':
            /*
             * Hexadecimal floating point format, with lower case radix
             * and exponent indicators; select the lower case mode, and
             * fall through...
             */
            stream.flags |= PFORMAT_XCASE;

          case 'A':
            /*
             * Hexadecimal floating point format; handles radix and
             * exponent indicators in either upper or lower case...
             */
            if( sizeof( double ) != sizeof( long double ) && stream.flags & PFORMAT_LDOUBLE )
              /*
               * with a `long double' argument...
               */
              __pformat_xldouble( va_arg( argv, long double ), &stream );

            else
              /* or just a `double'.
               */
              __pformat_xdouble( va_arg( argv, double ), &stream );

            goto format_scan;

          case 'n':
            /*
             * Save current output character count...
             */
            if( length == PFORMAT_LENGTH_CHAR )
              /*
               * to a signed `char' destination...
               */
              *va_arg( argv, char * ) = stream.count;

            else if( length == PFORMAT_LENGTH_SHORT )
              /*
               * or to a signed `short'...
               */
              *va_arg( argv, short * ) = stream.count;

            else if( length == PFORMAT_LENGTH_LONG )
              /*
               * or to a signed `long'...
               */
              *va_arg( argv, long * ) = stream.count;

            else if( length == PFORMAT_LENGTH_LLONG )
              /*
               * or to a signed `long long'...
               */
              *va_arg( argv, long long * ) = stream.count;

            else
              /*
               * or, by default, to a signed `int'.
               */
              *va_arg( argv, int * ) = stream.count;

            goto format_scan;

          /* Argument length modifiers...
           * These are non-terminal; each sets the format parser
           * into the PFORMAT_END state, and ends with a `break'.
           */
          case 'h':
            /*
             * Interpret the argument as explicitly of a `short'
             * or `char' data type, truncated from the standard
             * length defined for integer promotion.
             */
            if( *fmt == 'h' )
            {
              /* Modifier is `hh'; data type is `char' sized...
               * Skip the second `h', and set length accordingly.
               */
              ++fmt;
              length = PFORMAT_LENGTH_CHAR;
            }

            else
              /* Modifier is `h'; data type is `short' sized...
               */
              length = PFORMAT_LENGTH_SHORT;

            state = PFORMAT_END;
            break;

          case 'j':
            /*
             * Interpret the argument as being of the same size as
             * a `intmax_t' entity...
             */
            length = __pformat_arg_length( intmax_t );
            state = PFORMAT_END;
            break;

#         ifdef _WIN32

            case 'I':
              /*
               * The MSVCRT implementation of the printf() family of
               * functions explicitly uses...
               */
#ifdef __ENABLE_PRINTF128
              if( (fmt[0] == '1') && (fmt[1] == '2') && (fmt[2] == '8')){
                length = PFORMAT_LENGTH_LLONG128;
                fmt += 3;
              } else
#endif
              if( (fmt[0] == '6') && (fmt[1] == '4') )
              {
                /* I64' instead of `ll',
                 * when referring to `long long' integer types...
                 */
                length = PFORMAT_LENGTH_LLONG;
                fmt += 2;
              } else
              if( (fmt[0] == '3') && (fmt[1] == '2') )
              {
                /* and `I32' instead of `l',
                 * when referring to `long' integer types...
                 */
                length = PFORMAT_LENGTH_LONG;
                fmt += 2;
              }

              else
                /* or unqualified `I' instead of `t' or `z',
                 * when referring to `ptrdiff_t' or `size_t' entities;
                 * (we will choose to map it to `ptrdiff_t').
                 */
                length = __pformat_arg_length( ptrdiff_t );

              state = PFORMAT_END;
              break;

#         endif

#ifdef __ENABLE_DFP
          case 'H':
              stream.flags |= PFORMAT_DECIM32;
              state = PFORMAT_END;
              break;

          case 'D':
            /*
             * Interpret the argument as explicitly of a
             * `_Decimal64' or `_Decimal128' data type.
             */
            if( *fmt == 'D' )
            {
              /* Modifier is `DD'; data type is `_Decimal128' sized...
               * Skip the second `D', and set length accordingly.
               */
              ++fmt;
              stream.flags |= PFORMAT_DECIM128;
            }

            else
              /* Modifier is `D'; data type is `_Decimal64' sized...
               */
              stream.flags |= PFORMAT_DECIM64;

              state = PFORMAT_END;
              break;
#endif /* __ENABLE_DFP */
          case 'l':
            /*
             * Interpret the argument as explicitly of a
             * `long' or `long long' data type.
             */
            if( *fmt == 'l' )
            {
              /* Modifier is `ll'; data type is `long long' sized...
               * Skip the second `l', and set length accordingly.
               */
              ++fmt;
              length = PFORMAT_LENGTH_LLONG;
            }

            else
              /* Modifier is `l'; data type is `long' sized...
               */
              length = PFORMAT_LENGTH_LONG;

            state = PFORMAT_END;
            break;

          case 'L':
            /*
             * Identify the appropriate argument as a `long double',
             * when associated with `%a', `%A', `%e', `%E', `%f', `%F',
             * `%g' or `%G' format specifications.
             */
            stream.flags |= PFORMAT_LDOUBLE;
            state = PFORMAT_END;
            break;

          case 't':
            /*
             * Interpret the argument as being of the same size as
             * a `ptrdiff_t' entity...
             */
            length = __pformat_arg_length( ptrdiff_t );
            state = PFORMAT_END;
            break;

          case 'z':
            /*
             * Interpret the argument as being of the same size as
             * a `size_t' entity...
             */
            length = __pformat_arg_length( size_t );
            state = PFORMAT_END;
            break;

          /* Precision indicator...
           * May appear once only; it must precede any modifier
           * for argument length, or any data type specifier.
           */
          case '.':
            if( state < PFORMAT_GET_PRECISION )
            {
              /* We haven't seen a precision specification yet,
               * so initialise it to zero, (in case no digits follow),
               * and accept any following digits as the precision.
               */
              stream.precision = 0;
              width_spec = &stream.precision;
              state = PFORMAT_GET_PRECISION;
            }

            else
              /* We've already seen a precision specification,
               * so this is just junk; proceed to end game.
               */
              state = PFORMAT_END;

            /* Either way, we must not fall through here.
             */
            break;

          /* Variable field width, or precision specification,
           * derived from the argument list...
           */
          case '*':
            /*
             * When this appears...
             */
            if(   width_spec
            &&  ((state == PFORMAT_INIT) || (state == PFORMAT_GET_PRECISION)) )
            {
              /* in proper context; assign to field width
               * or precision, as appropriate.
               */
              if( (*width_spec = va_arg( argv, int )) < 0 )
              {
                /* Assigned value was negative...
                 */
                if( state == PFORMAT_INIT )
                {
                  /* For field width, this is equivalent to
                   * a positive value with the `-' flag...
                   */
                  stream.flags |= PFORMAT_LJUSTIFY;
                  stream.width = -stream.width;
                }

                else
                  /* while as a precision specification,
                   * it should simply be ignored.
                   */
                  stream.precision = PFORMAT_IGNORE;
              }
            }

            else
              /* out of context; give up on width and precision
               * specifications for this conversion.
               */
              state = PFORMAT_END;

            /* Mark as processed...
             * we must not see `*' again, in this context.
             */
            width_spec = NULL;
            break;

          /* Formatting flags...
           * Must appear while in the PFORMAT_INIT state,
           * and are non-terminal, so again, end with `break'.
           */
          case '#':
            /*
             * Select alternate PFORMAT_HASHED output style.
             */
            if( state == PFORMAT_INIT )
              stream.flags |= PFORMAT_HASHED;
            break;

          case '+':
            /*
             * Print a leading sign with numeric output,
             * for both positive and negative values.
             */
            if( state == PFORMAT_INIT )
              stream.flags |= PFORMAT_POSITIVE;
            break;

          case '-':
            /*
             * Select left justification of displayed output
             * data, within the output field width, instead of
             * the default flush right justification.
             */
            if( state == PFORMAT_INIT )
              stream.flags |= PFORMAT_LJUSTIFY;
            break;

            case '\'':
              /*
               * This is an XSI extension to the POSIX standard,
               * which we do not support, at present.
               */
              if (state == PFORMAT_INIT)
              {
                stream.flags |= PFORMAT_GROUPED; /* $$$$ */
                int len; wchar_t rpchr; mbstate_t cstate;
                memset (&cstate, 0, sizeof(state));
                if ((len = mbrtowc( &rpchr, localeconv()->thousands_sep, 16, &cstate)) > 0)
                    stream.thousands_chr = rpchr;
                stream.thousands_chr_len = len;
              }
              break;

          case '\x20':
            /*
             * Reserve a single space, within the output field,
             * for display of the sign of signed data; this will
             * be occupied by the minus sign, if the data value
             * is negative, or by a plus sign if the data value
             * is positive AND the `+' flag is also present, or
             * by a space otherwise.  (Technically, this flag
             * is redundant, if the `+' flag is present).
             */
            if( state == PFORMAT_INIT )
              stream.flags |= PFORMAT_ADDSPACE;
            break;

          case '0':
            /*
             * May represent a flag, to activate the `pad with zeros'
             * option, or it may simply be a digit in a width or in a
             * precision specification...
             */
            if( state == PFORMAT_INIT )
            {
              /* This is the flag usage...
               */
              stream.flags |= PFORMAT_ZEROFILL;
              break;
            }

          default:
            /*
             * If we didn't match anything above, then we will check
             * for digits, which we may accumulate to generate field
             * width or precision specifications...
             */
            if( (state < PFORMAT_END) && ('9' >= c) && (c >= '0') )
            {
              if( state == PFORMAT_INIT )
                /*
                 * Initial digits explicitly relate to field width...
                 */
                state = PFORMAT_SET_WIDTH;

              else if( state == PFORMAT_GET_PRECISION )
                /*
                 * while those following a precision indicator
                 * explicitly relate to precision.
                 */
                state = PFORMAT_SET_PRECISION;

              if( width_spec )
              {
                /* We are accepting a width or precision specification...
                 */
                if( *width_spec < 0 )
                  /*
                   * and accumulation hasn't started yet; we simply
                   * initialise the accumulator with the current digit
                   * value, converting from ASCII to decimal.
                   */
                  *width_spec = c - '0';

                else
                  /* Accumulation has already started; we perform a
                   * `leftwise decimal digit shift' on the accumulator,
                   * (i.e. multiply it by ten), then add the decimal
                   * equivalent value of the current digit.
                   */
                  *width_spec = *width_spec * 10 + c - '0';
              }
            }

            else
            {
              /* We found a digit out of context, or some other character
               * with no designated meaning; reject this format specification,
               * backtrack, and emit it as literal text...
               */
              fmt = backtrack;
      #ifndef __BUILD_WIDEAPI
              __pformat_putc( '%', &stream );
      #else
          stream.width = stream.precision = PFORMAT_IGNORE;
          __pformat_wputchars( L"%", 1, &stream );
      #endif
              goto format_scan;
            }
        }
      }
    }

    else
      /* We just parsed a character which is not included within any format
       * specification; we simply emit it as a literal.
       */
  #ifndef __BUILD_WIDEAPI
      __pformat_putc( c, &stream );
  #else
      if (literal_string_start == NULL)
        literal_string_start = fmt - 1;
  #endif
  }

  /* When we have fully dispatched the format string, the return value is the
   * total number of bytes we transferred to the output destination.
   */
#ifdef __BUILD_WIDEAPI
  if (literal_string_start)
  {
    stream.width = stream.precision = PFORMAT_IGNORE;
    __pformat_wputchars( literal_string_start, fmt - literal_string_start - 1, &stream );
  }
#endif

  return stream.count;
}

/* $RCSfile: pformat.c,v $Revision: 1.9 $: end of file */

