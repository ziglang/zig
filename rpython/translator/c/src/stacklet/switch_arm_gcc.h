#if defined(__ARM_ARCH_4__) || defined (__ARM_ARCH_4T__)
# define call_reg(x) "mov lr, pc ; bx " #x "\n"
#else
/* ARM >= 5 */
# define call_reg(x) "blx " #x "\n"
#endif

static void *slp_switch(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra) __attribute__((noinline));

static void *slp_switch(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra)
{
  void *result;
  /*
      seven registers to preserve: r2, r3, r7, r8, r9, r10, r11
      registers marked as clobbered: r0, r1, r4, r5, r6, r12, lr
      others: r13 is sp; r14 is lr; r15 is pc
  */

  __asm__ volatile (

    /* align the stack and save 7 more registers explicitly */
    "mov r0, sp\n"
    "and r1, r0, #-16\n"
    "mov sp, r1\n"
    "push {r0, r2, r3, r7, r8, r9, r10, r11}\n"   /* total 8, still aligned */
#ifndef __SOFTFP__
    /* We also push d8-d15 to preserve them explicitly.  This assumes
     * that this code is in a function that doesn't use floating-point
     * at all, and so don't touch the "d" registers (that's why we mark
     * it as non-inlinable).  So here by pushing/poping d8-d15 we are
     * saving precisely the callee-saved registers in all cases.  We
     * could also try to list all "d" registers as clobbered, but it
     * doesn't work: there is no way I could find to know if we have 16
     * or 32 "d" registers (depends on the exact -mcpu=... and we don't
     * know it from the C code).  If we have 32, then gcc would "save"
     * d8-d15 by copying them into d16-d23 for example, and it doesn't
     * work. */
    "vpush {d8, d9, d10, d11, d12, d13, d14, d15}\n"  /* 16 words, still aligned */
#endif

    /* save values in callee saved registers for later */
    "mov r4, %[restore_state]\n"  /* can't be r0 or r1: marked clobbered */
    "mov r5, %[extra]\n"          /* can't be r0 or r1 or r4: marked clob. */
    "mov r3, %[save_state]\n"     /* can't be r0, r1, r4, r5: marked clob. */
    "mov r0, sp\n"        	/* arg 1: current (old) stack pointer */
    "mov r1, r5\n"        	/* arg 2: extra                       */
    call_reg(r3)		/* call save_state()                  */

    /* skip the rest if the return value is null */
    "cmp r0, #0\n"
    "beq zero\n"

    "mov sp, r0\n"			/* change the stack pointer */

	/* From now on, the stack pointer is modified, but the content of the
	stack is not restored yet.  It contains only garbage here. */
    "mov r1, r5\n"       	/* arg 2: extra                       */
                /* arg 1: current (new) stack pointer is already in r0*/
    call_reg(r4)		/* call restore_state()               */

    /* The stack's content is now restored. */
    "zero:\n"

#ifndef __SOFTFP__
    "vpop {d8, d9, d10, d11, d12, d13, d14, d15}\n"
#endif
    "pop {r1, r2, r3, r7, r8, r9, r10, r11}\n"
    "mov sp, r1\n"
    "mov %[result], r0\n"

    : [result]"=r"(result)	/* output variables */
	/* input variables  */
    : [restore_state]"r"(restore_state),
      [save_state]"r"(save_state),
      [extra]"r"(extra)
    : "r0", "r1", "r4", "r5", "r6", "r12", "lr",
      "memory", "cc"
  );
  return result;
}
