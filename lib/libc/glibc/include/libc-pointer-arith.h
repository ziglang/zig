/* Helper macros for pointer arithmetic.
   Copyright (C) 2012-2020 Free Software Foundation, Inc.
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

#ifndef _LIBC_POINTER_ARITH_H
#define _LIBC_POINTER_ARITH_H 1

#include <stdint.h>

/* 1 if 'type' is a pointer type, 0 otherwise.  */
# define __pointer_type(type) (__builtin_classify_type ((type) 0) == 5)

/* intptr_t if P is true, or T if P is false.  */
# define __integer_if_pointer_type_sub(T, P) \
  __typeof__ (*(0 ? (__typeof__ (0 ? (T *) 0 : (void *) (P))) 0 \
		  : (__typeof__ (0 ? (intptr_t *) 0 : (void *) (!(P)))) 0))

/* intptr_t if EXPR has a pointer type, or the type of EXPR otherwise.  */
# define __integer_if_pointer_type(expr) \
  __integer_if_pointer_type_sub(__typeof__ ((__typeof__ (expr)) 0), \
				__pointer_type (__typeof__ (expr)))

/* Cast an integer or a pointer VAL to integer with proper type.  */
# define cast_to_integer(val) ((__integer_if_pointer_type (val)) (val))

/* Align a value by rounding down to closest size.
   e.g. Using size of 4096, we get this behavior:
	{4095, 4096, 4097} = {0, 4096, 4096}.  */
#define ALIGN_DOWN(base, size)	((base) & -((__typeof__ (base)) (size)))

/* Align a value by rounding up to closest size.
   e.g. Using size of 4096, we get this behavior:
	{4095, 4096, 4097} = {4096, 4096, 8192}.

  Note: The size argument has side effects (expanded multiple times).  */
#define ALIGN_UP(base, size)	ALIGN_DOWN ((base) + (size) - 1, (size))

/* Same as ALIGN_DOWN(), but automatically casts when base is a pointer.  */
#define PTR_ALIGN_DOWN(base, size) \
  ((__typeof__ (base)) ALIGN_DOWN ((uintptr_t) (base), (size)))

/* Same as ALIGN_UP(), but automatically casts when base is a pointer.  */
#define PTR_ALIGN_UP(base, size) \
  ((__typeof__ (base)) ALIGN_UP ((uintptr_t) (base), (size)))

#endif
