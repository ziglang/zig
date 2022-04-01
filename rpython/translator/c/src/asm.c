/* optional assembler bits */
#if defined(__GNUC__) && defined(__i386__)
#  include "src/asm_gcc_x86.c"
#endif

#if defined(__GNUC__) && defined(__amd64__)
/* No implementation for the moment. */
/* #  include "src/asm_gcc_x86_64.c" */
#endif

#if defined(_MSC_VER)
#  include "src/asm_msvc.c"
#endif
