#if !defined(__OpenBSD__)
#  define HAVE_SYS_UCONTEXT_H
#else
#  define HAVE_SIGNAL_H
#endif

#if defined(__FreeBSD__) || defined(__FreeBSD_kernel__) || defined(__DragonFly__)
  #ifdef __i386__
    #define PC_FROM_UCONTEXT uc_mcontext.mc_eip
  #else
    #define PC_FROM_UCONTEXT uc_mcontext.mc_rip
  #endif
#elif defined(__OpenBSD__)
#define PC_FROM_UCONTEXT sc_rip
#elif defined( __APPLE__)
  #if ((ULONG_MAX) == (UINT_MAX))
    #define PC_FROM_UCONTEXT uc_mcontext->__ss.__eip
  #else
    #define PC_FROM_UCONTEXT uc_mcontext->__ss.__rip
  #endif
#elif defined(__arm__)
  #define PC_FROM_UCONTEXT uc_mcontext.arm_ip
#elif defined(__linux) && defined(__i386) && defined(__GNUC__)
  #define PC_FROM_UCONTEXT uc_mcontext.gregs[REG_EIP]
#elif defined(__s390x__)
  #define PC_FROM_UCONTEXT uc_mcontext.psw.addr
#elif defined(__aarch64__)
  #define PC_FROM_UCONTEXT uc_mcontext.pc
#elif defined(__powerpc64__)
  #define PC_FROM_UCONTEXT uc_mcontext.gp_regs[PT_NIP]
#else
  /* linux, gnuc */
  #define PC_FROM_UCONTEXT uc_mcontext.gregs[REG_RIP]
#endif
