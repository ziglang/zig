#ifdef PYPY_X86_CHECK_SSE2
#define PYPY_X86_CHECK_SSE2_DEFINED
RPY_EXTERN void pypy_x86_check_sse2(void);
#endif


/* Provides the same access to RDTSC as used by the JIT backend.  This
   is needed (at least if the JIT is enabled) because otherwise the
   JIT-produced assembler would use RDTSC while the non-jitted code
   would use QueryPerformanceCounter(), giving different incompatible
   results.  See issue #900.
*/
#include <intrin.h>
#pragma intrinsic(__rdtsc)
#define READ_TIMESTAMP(val)   do { val = (long long)__rdtsc(); } while (0)
#define READ_TIMESTAMP_UNIT TIMESTAMP_UNIT_TSC
