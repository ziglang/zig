
/**************************************************************/
/***  this is included before any code produced by genc.py  ***/


#include "src/commondefs.h"

#ifdef _WIN32
#  include <io.h>   /* needed, otherwise _lseeki64 truncates to 32-bits (??) */
#endif

#include <stddef.h>


#ifdef __GNUC__       /* other platforms too, probably */
typedef _Bool bool_t;
# define RPY_VARLENGTH   /* nothing: [RPY_VARLENGTH] => [] */
# define RPY_LENGTH0     0       /* array decl [0] are ok  */
# define RPY_DUMMY_VARLENGTH     char _dummy[0];
#else
typedef unsigned char bool_t;
# define RPY_VARLENGTH   1       /* [RPY_VARLENGTH] => [1] */
# define RPY_LENGTH0     1       /* array decl [0] are bad */
# define RPY_DUMMY_VARLENGTH     /* nothing */
#endif

#ifdef RPY_REVERSE_DEBUGGER
#include "src-revdb/revdb_preinclude.h"
#endif
