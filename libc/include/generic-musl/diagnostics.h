/* Copyright (C) 2017-2019 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#ifndef DIAGNOSTICS_H
#define DIAGNOSTICS_H

/* If at all possible, fix the source rather than using these macros
   to silence warnings.  If you do use these macros be aware that
   you'll need to condition their use on particular compiler versions,
   which can be done for gcc using ansidecl.h's GCC_VERSION macro.

   gcc versions between 4.2 and 4.6 do not allow pragma control of
   diagnostics inside functions, giving a hard error if you try to use
   the finer control available with later versions.
   gcc prior to 4.2 warns about diagnostic push and pop.

   The other macros have restrictions too, for example gcc-5, gcc-6
   and gcc-7 warn that -Wstringop-truncation is unknown, unless you
   also add DIAGNOSTIC_IGNORE ("-Wpragma").  */

#ifdef __GNUC__
# define DIAGNOSTIC_PUSH _Pragma ("GCC diagnostic push")
# define DIAGNOSTIC_POP _Pragma ("GCC diagnostic pop")

/* Stringification.  */
# define DIAGNOSTIC_STRINGIFY_1(x) #x
# define DIAGNOSTIC_STRINGIFY(x) DIAGNOSTIC_STRINGIFY_1 (x)

# define DIAGNOSTIC_IGNORE(option) \
  _Pragma (DIAGNOSTIC_STRINGIFY (GCC diagnostic ignored option))
#else
# define DIAGNOSTIC_PUSH
# define DIAGNOSTIC_POP
# define DIAGNOSTIC_IGNORE(option)
#endif

#if defined (__clang__) /* clang */

# define DIAGNOSTIC_IGNORE_SELF_MOVE DIAGNOSTIC_IGNORE ("-Wself-move")
# define DIAGNOSTIC_IGNORE_DEPRECATED_DECLARATIONS \
  DIAGNOSTIC_IGNORE ("-Wdeprecated-declarations")
# define DIAGNOSTIC_IGNORE_DEPRECATED_REGISTER \
  DIAGNOSTIC_IGNORE ("-Wdeprecated-register")
# define DIAGNOSTIC_IGNORE_UNUSED_FUNCTION \
  DIAGNOSTIC_IGNORE ("-Wunused-function")
# if __has_warning ("-Wenum-compare-switch")
#  define DIAGNOSTIC_IGNORE_SWITCH_DIFFERENT_ENUM_TYPES \
   DIAGNOSTIC_IGNORE ("-Wenum-compare-switch")
# endif

# define DIAGNOSTIC_IGNORE_FORMAT_NONLITERAL \
  DIAGNOSTIC_IGNORE ("-Wformat-nonliteral")

#elif defined (__GNUC__) /* GCC */

# define DIAGNOSTIC_IGNORE_UNUSED_FUNCTION \
  DIAGNOSTIC_IGNORE ("-Wunused-function")

# define DIAGNOSTIC_IGNORE_STRINGOP_TRUNCATION \
  DIAGNOSTIC_IGNORE ("-Wstringop-truncation")

# define DIAGNOSTIC_IGNORE_FORMAT_NONLITERAL \
  DIAGNOSTIC_IGNORE ("-Wformat-nonliteral")

#endif

#ifndef DIAGNOSTIC_IGNORE_SELF_MOVE
# define DIAGNOSTIC_IGNORE_SELF_MOVE
#endif

#ifndef DIAGNOSTIC_IGNORE_DEPRECATED_DECLARATIONS
# define DIAGNOSTIC_IGNORE_DEPRECATED_DECLARATIONS
#endif

#ifndef DIAGNOSTIC_IGNORE_DEPRECATED_REGISTER
# define DIAGNOSTIC_IGNORE_DEPRECATED_REGISTER
#endif

#ifndef DIAGNOSTIC_IGNORE_UNUSED_FUNCTION
# define DIAGNOSTIC_IGNORE_UNUSED_FUNCTION
#endif

#ifndef DIAGNOSTIC_IGNORE_SWITCH_DIFFERENT_ENUM_TYPES
# define DIAGNOSTIC_IGNORE_SWITCH_DIFFERENT_ENUM_TYPES
#endif

#ifndef DIAGNOSTIC_IGNORE_STRINGOP_TRUNCATION
# define DIAGNOSTIC_IGNORE_STRINGOP_TRUNCATION
#endif

#ifndef DIAGNOSTIC_IGNORE_FORMAT_NONLITERAL
# define DIAGNOSTIC_IGNORE_FORMAT_NONLITERAL
#endif

#endif /* DIAGNOSTICS_H */