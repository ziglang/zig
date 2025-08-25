/* Architecture-specific adjustments to siginfo_t.  SPARC version.  */
#ifndef _BITS_SIGINFO_ARCH_H
#define _BITS_SIGINFO_ARCH_H 1

/* The kernel uses int instead of long int (as in POSIX).  In 32-bit
   mode, we can still use long int, but in 64-bit mode, we need to
   deviate from POSIX.  */
#if __WORDSIZE == 64
# define __SI_BAND_TYPE int
#endif

#define __SI_SIGFAULT_ADDL \
  int _si_trapno;

#define si_trapno	_sifields._sigfault._si_trapno

#endif