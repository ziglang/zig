/* Symbol version management.
   Copyright (C) 1995-2021 Free Software Foundation, Inc.
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

/* This file is included from <libc-symbols.h> for !_ISOMAC, and
   unconditionally from <shlib-compat.h>.  */

#ifndef _LIBC_SYMVER_H
#define _LIBC_SYMVER_H 1

#include <config.h>

/* Use symbol_version_reference to specify the version a symbol
   reference should link to.  Use symbol_version or
   default_symbol_version for the definition of a versioned symbol.
   The difference is that the latter is a no-op in non-shared
   builds.

   _set_symbol_version is similar to symbol_version_reference, except
   that this macro expects the name and symbol version as a single
   string or token sequence, with an @ or @@ separator.  (A string is
   used in C mode and a token sequence in assembler mode.)
   _set_symbol_version only be used for definitions because it may
   introduce an alias symbol that would not be globally unique for
   mere references.  The _set_symbol_version macro is used to define
   default_symbol_version and compat_symbol.  */

#ifdef __ASSEMBLER__
# define symbol_version_reference(real, name, version) \
     .symver real, name##@##version
#else
# define symbol_version_reference(real, name, version) \
  __asm__ (".symver " #real "," #name "@" #version)
#endif  /* !__ASSEMBLER__ */

#if SYMVER_NEEDS_ALIAS
/* If the assembler cannot support multiple versions for the same
   symbol, introduce __SInnn_ aliases to which the symbol version is
   attached.  */
# define __symbol_version_unique_concat(x, y) __SI ## x ## _ ## y
# define _symbol_version_unique_concat(x, y) \
  __symbol_version_unique_concat (x, y)
# define _symbol_version_unique_alias(name) \
  _symbol_version_unique_concat (name, __COUNTER__)
# ifdef __ASSEMBLER__
#  define _set_symbol_version_2(real, alias, name_version) \
  .globl alias ASM_LINE_SEP                                \
  .equiv alias, real ASM_LINE_SEP                          \
  .symver alias, name_version
# else
#  define _set_symbol_version_2(real, alias, name_version) \
  __asm__ (".globl " #alias "\n\t"                         \
           ".equiv " #alias ", " #real "\n\t"              \
           ".symver " #alias "," name_version)
# endif
# define _set_symbol_version_1(real, alias, name_version) \
  _set_symbol_version_2 (real, alias, name_version)
/* REAL must be globally unique, so that the counter also produces
   globally unique symbols.  */
# define _set_symbol_version(real, name_version)                   \
  _set_symbol_version_1 (real, _symbol_version_unique_alias (real), \
                               name_version)
# else  /* !SYMVER_NEEDS_ALIAS */
# ifdef __ASSEMBLER__
#  define _set_symbol_version(real, name_version) \
  .symver real, name_version
# else
#  define _set_symbol_version(real, name_version) \
  __asm__ (".symver " #real "," name_version)
# endif
#endif  /* !SYMVER_NEEDS_ALIAS */


#endif /* _LIBC_SYMVER_H */
