#include <link.h>
#include <dl-fptr.h>

#ifndef __ASSEMBLY__
extern void _start (void);
#endif

/* The function's entry point is stored in the first word of the
   function descriptor (plabel) of _start().  */
#define ENTRY_POINT ELF_PTR_TO_FDESC (_start)->ip

/* We have to provide a special declaration.  */
#define ENTRY_POINT_DECL(class) class void _start (void);
