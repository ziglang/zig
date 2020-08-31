/* Prototype declarations for math classification macros helpers.
   Copyright (C) 2017-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

/* Classify given number.  */
__MATHDECL_ALIAS (int, __fpclassify,, (_Mdouble_ __value), fpclassify)
     __attribute__ ((__const__));

/* Test for negative number.  */
__MATHDECL_ALIAS (int, __signbit,, (_Mdouble_ __value), signbit)
     __attribute__ ((__const__));

/* Return 0 if VALUE is finite or NaN, +1 if it
   is +Infinity, -1 if it is -Infinity.  */
__MATHDECL_ALIAS (int, __isinf,, (_Mdouble_ __value), isinf)
  __attribute__ ((__const__));

/* Return nonzero if VALUE is finite and not NaN.  Used by isfinite macro.  */
__MATHDECL_ALIAS (int, __finite,, (_Mdouble_ __value), finite)
  __attribute__ ((__const__));

/* Return nonzero if VALUE is not a number.  */
__MATHDECL_ALIAS (int, __isnan,, (_Mdouble_ __value), isnan)
  __attribute__ ((__const__));

/* Test equality.  */
__MATHDECL_ALIAS (int, __iseqsig,, (_Mdouble_ __x, _Mdouble_ __y), iseqsig);

/* Test for signaling NaN.  */
__MATHDECL_ALIAS (int, __issignaling,, (_Mdouble_ __value), issignaling)
     __attribute__ ((__const__));