extern void _start (void);

/* Lives in libgcc.so and canonicalizes function pointers for comparison.  */
extern unsigned int __canonicalize_funcptr_for_compare (unsigned int fptr);

/* The function's entry point is stored in the first word of the
   function descriptor (plabel) of _start().  */
#define ENTRY_POINT __canonicalize_funcptr_for_compare((unsigned int)_start)
