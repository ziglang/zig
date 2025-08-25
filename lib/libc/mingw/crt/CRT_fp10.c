/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

void _fpreset (void);

void _fpreset (void)
{
#ifdef __GNUC__
  __asm__ ("fninit");
#else /* msvc: */
  __asm fninit;
#endif
}

#ifdef __GNUC__
void __attribute__ ((alias ("_fpreset"))) fpreset(void);
#else
void fpreset(void) {
    _fpreset();
}
#endif
