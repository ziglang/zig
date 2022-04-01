/* This optional file only works for GCC on an i386.
 * It replaces some complex macros with native assembler instructions.
 */

#if 0     /* --- disabled: does not give any speed-up --- */

#undef OP_INT_ADD_OVF
#define OP_INT_ADD_OVF(x,y,r)                   \
    asm volatile(                               \
        "/* ignore_in_trackgcroot */\n\t"       \
        "addl %2,%0\n\t"                        \
        "jno 0f\n\t"                            \
        "pusha\n\t"                             \
        "call _op_int_overflowed\n\t"           \
        "popa\n\t"                              \
        "0:\n\t"                                \
        "/* end_ignore_in_trackgcroot */"       \
        : "=r"(r)            /* outputs */      \
        : "0"(x), "g"(y)     /* inputs  */      \
        : "cc", "memory")    /* clobber */

#undef OP_INT_ADD_NONNEG_OVF
#define OP_INT_ADD_NONNEG_OVF(x,y,r) OP_INT_ADD_OVF(x,y,r)

#undef OP_INT_SUB_OVF
#define OP_INT_SUB_OVF(x,y,r)                   \
    asm volatile(                               \
        "/* ignore_in_trackgcroot */\n\t"       \
        "subl %2,%0\n\t"                        \
        "jno 0f\n\t"                            \
        "pusha\n\t"                             \
        "call _op_int_overflowed\n\t"           \
        "popa\n\t"                              \
        "0:\n\t"                                \
        "/* end_ignore_in_trackgcroot */"       \
        : "=r"(r)            /* outputs */      \
        : "0"(x), "g"(y)     /* inputs  */      \
        : "cc", "memory")    /* clobber */

#undef OP_INT_MUL_OVF
#define OP_INT_MUL_OVF(x,y,r)                   \
    asm volatile(                               \
        "/* ignore_in_trackgcroot */\n\t"       \
        "imull %2,%0\n\t"                       \
        "jno 0f\n\t"                            \
        "pusha\n\t"                             \
        "call _op_int_overflowed\n\t"           \
        "popa\n\t"                              \
        "0:\n\t"                                \
        "/* end_ignore_in_trackgcroot */"       \
        : "=r"(r)            /* outputs */      \
        : "0"(x), "g"(y)     /* inputs  */      \
        : "cc", "memory")    /* clobber */

RPY_EXTERN void op_int_overflowed(void)
     asm ("_op_int_overflowed")
     __attribute__((used));

#endif  /* 0 */


/* Pentium only! */
#define READ_TIMESTAMP(val) \
     asm volatile("rdtsc" : "=A" (val))
// Kernel has a barrier around rtdsc 
// mfence
// lfence
// rtdsc
// mfence
// lfence
// I don't know how important it is, comment talks about time warps

#define READ_TIMESTAMP_UNIT TIMESTAMP_UNIT_TSC

#ifndef PYPY_CPU_HAS_STANDARD_PRECISION
/* On x86-32, we have to use the following hacks to set and restore
 * the CPU's precision to 53 bits around calls to dtoa.c.  The macro
 * PYPY_CPU_HAS_STANDARD_PRECISION is defined if we are compiling
 * with -mss2 -mfpmath=sse anyway, in which case the precision is
 * already ok.
 */
#define _PyPy_SET_53BIT_PRECISION_HEADER                          \
    unsigned short old_387controlword, new_387controlword
#define _PyPy_SET_53BIT_PRECISION_START                                 \
    do {                                                                \
        old_387controlword = _PyPy_get_387controlword();                \
        new_387controlword = (old_387controlword & ~0x0f00) | 0x0200;   \
        if (new_387controlword != old_387controlword)                   \
            _PyPy_set_387controlword(new_387controlword);               \
    } while (0)
#define _PyPy_SET_53BIT_PRECISION_END                           \
    if (new_387controlword != old_387controlword)               \
        _PyPy_set_387controlword(old_387controlword)

static unsigned short _PyPy_get_387controlword(void) {
    unsigned short cw;
    __asm__ __volatile__ ("fnstcw %0" : "=m" (cw));
    return cw;
}
static void _PyPy_set_387controlword(unsigned short cw) {
    __asm__ __volatile__ ("fldcw %0" : : "m" (cw));
}
#endif  /* !PYPY_CPU_HAS_STANDARD_PRECISION */


#ifdef PYPY_X86_CHECK_SSE2
#define PYPY_X86_CHECK_SSE2_DEFINED
RPY_EXTERN void pypy_x86_check_sse2(void);
#endif


#define RPy_YieldProcessor()  asm("pause")
