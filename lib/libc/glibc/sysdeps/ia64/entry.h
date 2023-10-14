#include <link.h>
#include <dl-fptr.h>

extern void _start (void);

/* The function's entry point is stored in the first word of the
   function descriptor (plabel) of _start().  */
#define ENTRY_POINT ELF_PTR_TO_FDESC (_start)->ip
