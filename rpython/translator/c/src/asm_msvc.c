#ifdef PYPY_X86_CHECK_SSE2
#include <intrin.h>
#include <stdio.h>
void pypy_x86_check_sse2(void)
{
    int features;
    int CPUInfo[4];
    CPUInfo[3] = 0;
    __cpuid(CPUInfo, 1);
    features = CPUInfo[3];

    //Check bits 25 and 26, this indicates SSE2 support
    if (((features & (1 << 25)) == 0) || ((features & (1 << 26)) == 0))
    {
        fprintf(stderr, "Old CPU with no SSE2 support, cannot continue.\n"
                        "You need to re-translate with "
                        "'--jit-backend=x86-without-sse2'\n");
        abort();
    }
}
#endif
