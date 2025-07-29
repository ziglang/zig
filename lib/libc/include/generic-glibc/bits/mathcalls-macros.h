/* Macros for math function declarations.
   Copyright (C) 2024-2025 Free Software Foundation, Inc.
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

#define __SIMD_DECL(function) __CONCAT (__DECL_SIMD_, function)

#define __MATHCALL_VEC(function, suffix, args) 	\
  __SIMD_DECL (__MATH_PRECNAME (function, suffix)) \
  __MATHCALL (function, suffix, args)

#define __MATHDECL_VEC(type, function,suffix, args) \
  __SIMD_DECL (__MATH_PRECNAME (function, suffix)) \
  __MATHDECL(type, function,suffix, args)

#define __MATHCALL(function,suffix, args)	\
  __MATHDECL (_Mdouble_,function,suffix, args)
#define __MATHDECL(type, function,suffix, args) \
  __MATHDECL_1(type, function,suffix, args); \
  __MATHDECL_1(type, __CONCAT(__,function),suffix, args)
#define __MATHCALLX(function,suffix, args, attrib)	\
  __MATHDECLX (_Mdouble_,function,suffix, args, attrib)
#define __MATHDECLX(type, function,suffix, args, attrib) \
  __MATHDECL_1(type, function,suffix, args) __attribute__ (attrib);
#define __MATHDECL_1_IMPL(type, function, suffix, args) \
  extern type __MATH_PRECNAME(function,suffix) args __THROW
#define __MATHDECL_1(type, function, suffix, args) \
  __MATHDECL_1_IMPL(type, function, suffix, args)
/* Ignore the alias by default.  The alias is only useful with
   redirections.  */
#define __MATHDECL_ALIAS(type, function, suffix, args, alias) \
  __MATHDECL_1(type, function, suffix, args)

#define __MATHREDIR(type, function, suffix, args, to) \
  extern type __REDIRECT_NTH (__MATH_PRECNAME (function, suffix), args, to)