/* Architecture-specific adjustments to siginfo_t.  MIPS version.  */
#ifndef _BITS_SIGINFO_ARCH_H
#define _BITS_SIGINFO_ARCH_H 1

/* MIPS has the si_code and si_errno fields in the opposite order from
   all other architectures.  */
#define __SI_ERRNO_THEN_CODE 0

/* MIPS also has different values for SI_ASYNCIO, SI_MESGQ, and SI_TIMER
   than all other architectures.  */
#define __SI_ASYNCIO_AFTER_SIGIO 0

#endif