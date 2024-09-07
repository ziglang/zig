/* Architecture-specific __sigset_t definition.  ARC version.  */
#ifndef ____sigset_t_defined
#define ____sigset_t_defined

/* Linux asm-generic syscall ABI expects sigset_t to hold 64 signals.  */
#define _SIGSET_NWORDS (64 / (8 * sizeof (unsigned long int)))
typedef struct
{
  unsigned long int __val[_SIGSET_NWORDS];
} __sigset_t;

#endif