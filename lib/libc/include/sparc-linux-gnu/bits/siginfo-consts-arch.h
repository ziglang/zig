/* Architecture-specific additional siginfo constants.  SPARC version.  */
#ifndef _BITS_SIGINFO_CONSTS_ARCH_H
#define _BITS_SIGINFO_CONSTS_ARCH_H 1

/* `si_code' values for SIGEMT signal.  */
enum
{
  EMT_TAGOVF = 1	/* Tag overflow.  */
#define EMT_TAGOVF	EMT_TAGOVF
};

#endif