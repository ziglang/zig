
static void *slp_switch(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra) __attribute__((noinline));

static void *slp_switch(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra)
{
  void *result;
  /*
      registers to preserve: x18-x28, x29(fp), and v8-v15
      registers marked as clobbered: x0-x18, x30

      Note that x18 appears in both lists; see below.  We also save
      x30 although it's also marked as clobbered, which might not
      be necessary but doesn't hurt.

      Don't assume gcc saves any register for us when generating
      code for slp_switch().

      The values 'save_state', 'restore_state' and 'extra' are first moved
      by gcc to some registers that are not marked as clobbered, so between
      x19 and x29.  Similarly, gcc expects 'result' to be in a register
      between x19 and x29.  We don't want x18 to be used here, because of
      some special meaning it might have.  We don't want x30 to be used
      here, because it is clobbered by the first "blr".

      This means that three of the values we happen to save and restore
      will, in fact, contain the three arguments, and one of these values
      will, in fact, not be restored at all but receive 'result'.
  */

  __asm__ volatile (

    /* The stack is supposed to be aligned as necessary already.
       Save 12 registers from x18 to x29, plus 8 from v8 to v15 */

    "stp x18, x19, [sp, -160]!\n"
    "stp x20, x11, [sp, 16]\n"
    "stp x22, x23, [sp, 32]\n"
    "stp x24, x25, [sp, 48]\n"
    "stp x26, x27, [sp, 64]\n"
    "stp x28, x29, [sp, 80]\n"
    "str d8,  [sp, 96]\n"
    "str d9,  [sp, 104]\n"
    "str d10, [sp, 112]\n"
    "str d11, [sp, 120]\n"
    "str d12, [sp, 128]\n"
    "str d13, [sp, 136]\n"
    "str d14, [sp, 144]\n"
    "str d15, [sp, 152]\n"

    "mov x0, sp\n"        	/* arg 1: current (old) stack pointer */
    "mov x1, %[extra]\n"   	/* arg 2: extra, from x19-x28         */
    "blr %[save_state]\n"	/* call save_state(), from x19-x28    */

    /* skip the rest if the return value is null */
    "cbz x0, zero\n"

    "mov sp, x0\n"			/* change the stack pointer */

	/* From now on, the stack pointer is modified, but the content of the
	stack is not restored yet.  It contains only garbage here. */
    "mov x1, %[extra]\n"	/* arg 2: extra, still from x19-x28   */
                /* arg 1: current (new) stack pointer is already in x0*/
    "blr %[restore_state]\n"/* call restore_state()               */

    /* The stack's content is now restored. */
    "zero:\n"

    /* Restore all saved registers */
    "ldp x20, x11, [sp, 16]\n"
    "ldp x22, x23, [sp, 32]\n"
    "ldp x24, x25, [sp, 48]\n"
    "ldp x26, x27, [sp, 64]\n"
    "ldp x28, x29, [sp, 80]\n"
    "ldr d8,  [sp, 96]\n"
    "ldr d9,  [sp, 104]\n"
    "ldr d10, [sp, 112]\n"
    "ldr d11, [sp, 120]\n"
    "ldr d12, [sp, 128]\n"
    "ldr d13, [sp, 136]\n"
    "ldr d14, [sp, 144]\n"
    "ldr d15, [sp, 152]\n"
    "ldp x18, x19, [sp], 160\n"

    /* Move x0 into the final location of 'result' */
    "mov %[result], x0\n"

    : [result]"=r"(result)	/* output variables */
	/* input variables  */
    : [restore_state]"r"(restore_state),
      [save_state]"r"(save_state),
      [extra]"r"(extra)
    : "x0", "x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x9",
      "x10", "x11", "x12", "x13", "x14", "x15", "x16", "x17", "x18",
      "memory", "cc", "x30"  // x30==lr
  );
  return result;
}
