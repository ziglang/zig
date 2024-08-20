/* Copyright (C) 1997-2024 Free Software Foundation, Inc.
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

/*
 *	ISO C99: 7.8 Format conversion of integer types	<inttypes.h>
 */

#ifndef _INTTYPES_H
#define _INTTYPES_H	1

#include <features.h>
/* Get the type definitions.  */
#include <stdint.h>

/* Get a definition for wchar_t.  But we must not define wchar_t itself.  */
#ifndef ____gwchar_t_defined
# ifdef __cplusplus
#  define __gwchar_t wchar_t
# elif defined __WCHAR_TYPE__
typedef __WCHAR_TYPE__ __gwchar_t;
# else
#  define __need_wchar_t
#  include <stddef.h>
typedef wchar_t __gwchar_t;
# endif
# define ____gwchar_t_defined	1
#endif

# if __WORDSIZE == 64
#  define __PRI64_PREFIX	"l"
#  define __PRIPTR_PREFIX	"l"
# else
#  define __PRI64_PREFIX	"ll"
#  define __PRIPTR_PREFIX
# endif

/* Macros for printing format specifiers.  */

/* Decimal notation.  */
# define PRId8		"d"
# define PRId16		"d"
# define PRId32		"d"
# define PRId64		__PRI64_PREFIX "d"

# define PRIdLEAST8	"d"
# define PRIdLEAST16	"d"
# define PRIdLEAST32	"d"
# define PRIdLEAST64	__PRI64_PREFIX "d"

# define PRIdFAST8	"d"
# define PRIdFAST16	__PRIPTR_PREFIX "d"
# define PRIdFAST32	__PRIPTR_PREFIX "d"
# define PRIdFAST64	__PRI64_PREFIX "d"


# define PRIi8		"i"
# define PRIi16		"i"
# define PRIi32		"i"
# define PRIi64		__PRI64_PREFIX "i"

# define PRIiLEAST8	"i"
# define PRIiLEAST16	"i"
# define PRIiLEAST32	"i"
# define PRIiLEAST64	__PRI64_PREFIX "i"

# define PRIiFAST8	"i"
# define PRIiFAST16	__PRIPTR_PREFIX "i"
# define PRIiFAST32	__PRIPTR_PREFIX "i"
# define PRIiFAST64	__PRI64_PREFIX "i"

/* Octal notation.  */
# define PRIo8		"o"
# define PRIo16		"o"
# define PRIo32		"o"
# define PRIo64		__PRI64_PREFIX "o"

# define PRIoLEAST8	"o"
# define PRIoLEAST16	"o"
# define PRIoLEAST32	"o"
# define PRIoLEAST64	__PRI64_PREFIX "o"

# define PRIoFAST8	"o"
# define PRIoFAST16	__PRIPTR_PREFIX "o"
# define PRIoFAST32	__PRIPTR_PREFIX "o"
# define PRIoFAST64	__PRI64_PREFIX "o"

/* Unsigned integers.  */
# define PRIu8		"u"
# define PRIu16		"u"
# define PRIu32		"u"
# define PRIu64		__PRI64_PREFIX "u"

# define PRIuLEAST8	"u"
# define PRIuLEAST16	"u"
# define PRIuLEAST32	"u"
# define PRIuLEAST64	__PRI64_PREFIX "u"

# define PRIuFAST8	"u"
# define PRIuFAST16	__PRIPTR_PREFIX "u"
# define PRIuFAST32	__PRIPTR_PREFIX "u"
# define PRIuFAST64	__PRI64_PREFIX "u"

/* lowercase hexadecimal notation.  */
# define PRIx8		"x"
# define PRIx16		"x"
# define PRIx32		"x"
# define PRIx64		__PRI64_PREFIX "x"

# define PRIxLEAST8	"x"
# define PRIxLEAST16	"x"
# define PRIxLEAST32	"x"
# define PRIxLEAST64	__PRI64_PREFIX "x"

# define PRIxFAST8	"x"
# define PRIxFAST16	__PRIPTR_PREFIX "x"
# define PRIxFAST32	__PRIPTR_PREFIX "x"
# define PRIxFAST64	__PRI64_PREFIX "x"

/* UPPERCASE hexadecimal notation.  */
# define PRIX8		"X"
# define PRIX16		"X"
# define PRIX32		"X"
# define PRIX64		__PRI64_PREFIX "X"

# define PRIXLEAST8	"X"
# define PRIXLEAST16	"X"
# define PRIXLEAST32	"X"
# define PRIXLEAST64	__PRI64_PREFIX "X"

# define PRIXFAST8	"X"
# define PRIXFAST16	__PRIPTR_PREFIX "X"
# define PRIXFAST32	__PRIPTR_PREFIX "X"
# define PRIXFAST64	__PRI64_PREFIX "X"


/* Macros for printing `intmax_t' and `uintmax_t'.  */
# define PRIdMAX	__PRI64_PREFIX "d"
# define PRIiMAX	__PRI64_PREFIX "i"
# define PRIoMAX	__PRI64_PREFIX "o"
# define PRIuMAX	__PRI64_PREFIX "u"
# define PRIxMAX	__PRI64_PREFIX "x"
# define PRIXMAX	__PRI64_PREFIX "X"


/* Macros for printing `intptr_t' and `uintptr_t'.  */
# define PRIdPTR	__PRIPTR_PREFIX "d"
# define PRIiPTR	__PRIPTR_PREFIX "i"
# define PRIoPTR	__PRIPTR_PREFIX "o"
# define PRIuPTR	__PRIPTR_PREFIX "u"
# define PRIxPTR	__PRIPTR_PREFIX "x"
# define PRIXPTR	__PRIPTR_PREFIX "X"

/* Binary notation.  */
# if __GLIBC_USE (ISOC23)
#  define PRIb8		"b"
#  define PRIb16	"b"
#  define PRIb32	"b"
#  define PRIb64	__PRI64_PREFIX "b"

#  define PRIbLEAST8	"b"
#  define PRIbLEAST16	"b"
#  define PRIbLEAST32	"b"
#  define PRIbLEAST64	__PRI64_PREFIX "b"

#  define PRIbFAST8	"b"
#  define PRIbFAST16	__PRIPTR_PREFIX "b"
#  define PRIbFAST32	__PRIPTR_PREFIX "b"
#  define PRIbFAST64	__PRI64_PREFIX "b"

#  define PRIbMAX	__PRI64_PREFIX "b"
#  define PRIbPTR	__PRIPTR_PREFIX "b"

#  define PRIB8		"B"
#  define PRIB16	"B"
#  define PRIB32	"B"
#  define PRIB64	__PRI64_PREFIX "B"

#  define PRIBLEAST8	"B"
#  define PRIBLEAST16	"B"
#  define PRIBLEAST32	"B"
#  define PRIBLEAST64	__PRI64_PREFIX "B"

#  define PRIBFAST8	"B"
#  define PRIBFAST16	__PRIPTR_PREFIX "B"
#  define PRIBFAST32	__PRIPTR_PREFIX "B"
#  define PRIBFAST64	__PRI64_PREFIX "B"

#  define PRIBMAX	__PRI64_PREFIX "B"
#  define PRIBPTR	__PRIPTR_PREFIX "B"
# endif


/* Macros for scanning format specifiers.  */

/* Signed decimal notation.  */
# define SCNd8		"hhd"
# define SCNd16		"hd"
# define SCNd32		"d"
# define SCNd64		__PRI64_PREFIX "d"

# define SCNdLEAST8	"hhd"
# define SCNdLEAST16	"hd"
# define SCNdLEAST32	"d"
# define SCNdLEAST64	__PRI64_PREFIX "d"

# define SCNdFAST8	"hhd"
# define SCNdFAST16	__PRIPTR_PREFIX "d"
# define SCNdFAST32	__PRIPTR_PREFIX "d"
# define SCNdFAST64	__PRI64_PREFIX "d"

/* Signed decimal notation.  */
# define SCNi8		"hhi"
# define SCNi16		"hi"
# define SCNi32		"i"
# define SCNi64		__PRI64_PREFIX "i"

# define SCNiLEAST8	"hhi"
# define SCNiLEAST16	"hi"
# define SCNiLEAST32	"i"
# define SCNiLEAST64	__PRI64_PREFIX "i"

# define SCNiFAST8	"hhi"
# define SCNiFAST16	__PRIPTR_PREFIX "i"
# define SCNiFAST32	__PRIPTR_PREFIX "i"
# define SCNiFAST64	__PRI64_PREFIX "i"

/* Unsigned decimal notation.  */
# define SCNu8		"hhu"
# define SCNu16		"hu"
# define SCNu32		"u"
# define SCNu64		__PRI64_PREFIX "u"

# define SCNuLEAST8	"hhu"
# define SCNuLEAST16	"hu"
# define SCNuLEAST32	"u"
# define SCNuLEAST64	__PRI64_PREFIX "u"

# define SCNuFAST8	"hhu"
# define SCNuFAST16	__PRIPTR_PREFIX "u"
# define SCNuFAST32	__PRIPTR_PREFIX "u"
# define SCNuFAST64	__PRI64_PREFIX "u"

/* Octal notation.  */
# define SCNo8		"hho"
# define SCNo16		"ho"
# define SCNo32		"o"
# define SCNo64		__PRI64_PREFIX "o"

# define SCNoLEAST8	"hho"
# define SCNoLEAST16	"ho"
# define SCNoLEAST32	"o"
# define SCNoLEAST64	__PRI64_PREFIX "o"

# define SCNoFAST8	"hho"
# define SCNoFAST16	__PRIPTR_PREFIX "o"
# define SCNoFAST32	__PRIPTR_PREFIX "o"
# define SCNoFAST64	__PRI64_PREFIX "o"

/* Hexadecimal notation.  */
# define SCNx8		"hhx"
# define SCNx16		"hx"
# define SCNx32		"x"
# define SCNx64		__PRI64_PREFIX "x"

# define SCNxLEAST8	"hhx"
# define SCNxLEAST16	"hx"
# define SCNxLEAST32	"x"
# define SCNxLEAST64	__PRI64_PREFIX "x"

# define SCNxFAST8	"hhx"
# define SCNxFAST16	__PRIPTR_PREFIX "x"
# define SCNxFAST32	__PRIPTR_PREFIX "x"
# define SCNxFAST64	__PRI64_PREFIX "x"


/* Macros for scanning `intmax_t' and `uintmax_t'.  */
# define SCNdMAX	__PRI64_PREFIX "d"
# define SCNiMAX	__PRI64_PREFIX "i"
# define SCNoMAX	__PRI64_PREFIX "o"
# define SCNuMAX	__PRI64_PREFIX "u"
# define SCNxMAX	__PRI64_PREFIX "x"

/* Macros for scanning `intptr_t' and `uintptr_t'.  */
# define SCNdPTR	__PRIPTR_PREFIX "d"
# define SCNiPTR	__PRIPTR_PREFIX "i"
# define SCNoPTR	__PRIPTR_PREFIX "o"
# define SCNuPTR	__PRIPTR_PREFIX "u"
# define SCNxPTR	__PRIPTR_PREFIX "x"


/* Binary notation.  */
# if __GLIBC_USE (ISOC23)
#  define SCNb8		"hhb"
#  define SCNb16	"hb"
#  define SCNb32	"b"
#  define SCNb64	__PRI64_PREFIX "b"

#  define SCNbLEAST8	"hhb"
#  define SCNbLEAST16	"hb"
#  define SCNbLEAST32	"b"
#  define SCNbLEAST64	__PRI64_PREFIX "b"

#  define SCNbFAST8	"hhb"
#  define SCNbFAST16	__PRIPTR_PREFIX "b"
#  define SCNbFAST32	__PRIPTR_PREFIX "b"
#  define SCNbFAST64	__PRI64_PREFIX "b"

#  define SCNbMAX	__PRI64_PREFIX "b"
#  define SCNbPTR	__PRIPTR_PREFIX "b"
# endif


__BEGIN_DECLS

#if __WORDSIZE == 64

/* We have to define the `uintmax_t' type using `ldiv_t'.  */
typedef struct
  {
    long int quot;		/* Quotient.  */
    long int rem;		/* Remainder.  */
  } imaxdiv_t;

#else

/* We have to define the `uintmax_t' type using `lldiv_t'.  */
typedef struct
  {
    __extension__ long long int quot;	/* Quotient.  */
    __extension__ long long int rem;	/* Remainder.  */
  } imaxdiv_t;

#endif


/* Compute absolute value of N.  */
extern intmax_t imaxabs (intmax_t __n) __THROW __attribute__ ((__const__));

/* Return the `imaxdiv_t' representation of the value of NUMER over DENOM. */
extern imaxdiv_t imaxdiv (intmax_t __numer, intmax_t __denom)
      __THROW __attribute__ ((__const__));

/* Like `strtol' but convert to `intmax_t'.  */
extern intmax_t strtoimax (const char *__restrict __nptr,
			   char **__restrict __endptr, int __base) __THROW;

/* Like `strtoul' but convert to `uintmax_t'.  */
extern uintmax_t strtoumax (const char *__restrict __nptr,
			    char ** __restrict __endptr, int __base) __THROW;

/* Like `wcstol' but convert to `intmax_t'.  */
extern intmax_t wcstoimax (const __gwchar_t *__restrict __nptr,
			   __gwchar_t **__restrict __endptr, int __base)
     __THROW;

/* Like `wcstoul' but convert to `uintmax_t'.  */
extern uintmax_t wcstoumax (const __gwchar_t *__restrict __nptr,
			    __gwchar_t ** __restrict __endptr, int __base)
     __THROW;

/* Versions of the above functions that handle '0b' and '0B' prefixes
   in base 0 or 2.  */
#if __GLIBC_USE (C23_STRTOL)
# ifdef __REDIRECT
extern intmax_t __REDIRECT_NTH (strtoimax, (const char *__restrict __nptr,
					    char **__restrict __endptr,
					    int __base), __isoc23_strtoimax);
extern uintmax_t __REDIRECT_NTH (strtoumax, (const char *__restrict __nptr,
					     char **__restrict __endptr,
					     int __base), __isoc23_strtoumax);
extern intmax_t __REDIRECT_NTH (wcstoimax,
				(const __gwchar_t *__restrict __nptr,
				 __gwchar_t **__restrict __endptr, int __base),
				__isoc23_wcstoimax);
extern uintmax_t __REDIRECT_NTH (wcstoumax,
				 (const __gwchar_t *__restrict __nptr,
				  __gwchar_t **__restrict __endptr, int __base),
				 __isoc23_wcstoumax);
# else
extern intmax_t __isoc23_strtoimax (const char *__restrict __nptr,
				    char **__restrict __endptr, int __base)
     __THROW;
extern uintmax_t __isoc23_strtoumax (const char *__restrict __nptr,
				     char ** __restrict __endptr, int __base)
     __THROW;
extern intmax_t __isoc23_wcstoimax (const __gwchar_t *__restrict __nptr,
				    __gwchar_t **__restrict __endptr,
				    int __base)
     __THROW;
extern uintmax_t __isoc23_wcstoumax (const __gwchar_t *__restrict __nptr,
				     __gwchar_t ** __restrict __endptr,
				     int __base)
     __THROW;
# define strtoimax __isoc23_strtoimax
# define strtoumax __isoc23_strtoumax
# define wcstoimax __isoc23_wcstoimax
# define wcstoumax __isoc23_wcstoumax
# endif
#endif

__END_DECLS

#endif /* inttypes.h */