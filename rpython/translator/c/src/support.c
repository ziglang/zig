#include "common_header.h"
#include <src/support.h>
#include <src/exception.h>

/************************************************************/
/***  C header subsection: support functions              ***/

#include <stdio.h>
#include <stdlib.h>

/*** misc ***/
#define Sign_bit 0x80000000
#define NAN_WORD0 0x7ff80000
#define NAN_WORD1 0
#ifndef PY_UINT32_T
#define PY_UINT32_T unsigned int
#endif

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#define IEEE_8087
#endif

#ifdef IEEE_8087
#define word0(x) (x)->L[1]
#define word1(x) (x)->L[0]
#else
#define word0(x) (x)->L[0]
#define word1(x) (x)->L[1]
#endif
#define dval(x) (x)->d

typedef PY_UINT32_T ULong;
typedef union { double d; ULong L[2]; } U;

RPY_EXTERN
void RPyAssertFailed(const char* filename, long lineno,
                     const char* function, const char *msg) {
  fprintf(stderr,
          "PyPy assertion failed at %s:%ld:\n"
          "in %s: %s\n",
          filename, lineno, function, msg);
  abort();
}

RPY_EXTERN
void RPyAbort(void) {
  fprintf(stderr, "Invalid RPython operation (NULL ptr or bad array index)\n");
  abort();
}

/* Return a 'standard' NaN value.
   There are exactly two quiet NaNs that don't arise by 'quieting' signaling
   NaNs (see IEEE 754-2008, section 6.2.1).  If sign == 0, return the one whose
   sign bit is cleared.  Otherwise, return the one whose sign bit is set.
*/

double
_PyPy_dg_stdnan(int sign)
{
    U rv;
    word0(&rv) = NAN_WORD0;
    word1(&rv) = NAN_WORD1;
    if (sign)
        word0(&rv) |= Sign_bit;
    return dval(&rv);
}
