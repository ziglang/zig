/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

void _fpreset (void);

void _fpreset (void)
{
#if defined(_ARM_) || defined(__arm__)
  __asm__ __volatile__ (
    "vmsr	fpscr, %0\n\t" : : "r"(0 /* INITIAL_FPSCR */));
#elif defined(_ARM64_) || defined(__aarch64__)
  __asm__ __volatile__ (
    "msr	fpcr, %0\n\t" : : "r"(0LL /* INITIAL_FPSCR */));
#else
#ifdef __GNUC__
  __asm__ ("fninit");
#else /* msvc: */
  __asm fninit;
#endif
#endif
}

#ifdef __GNUC__
void __attribute__ ((alias ("_fpreset"))) fpreset(void);
#else
void fpreset(void) {
    _fpreset();
}
#endif
