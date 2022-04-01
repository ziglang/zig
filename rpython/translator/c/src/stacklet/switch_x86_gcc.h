
static void *slp_switch(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra)
{
  void *result, *garbage1, *garbage2;
  __asm__ volatile (
     "pushl %%ebp\n"
     "pushl %%ebx\n"       /* push some registers that may contain */
     "pushl %%esi\n"       /* some value that is meant to be saved */
     "movl %%esp, %%ebp\n"
     "andl $-16, %%esp\n"  /* <= align the stack here, for the calls */
     "pushl %%edi\n"
     "pushl %%ebp\n"

     "movl %%eax, %%esi\n" /* save 'restore_state' for later */
     "movl %%edx, %%edi\n" /* save 'extra' for later         */

     "movl %%esp, %%eax\n"

     "pushl %%edx\n"       /* arg 2: extra                       */
     "pushl %%eax\n"       /* arg 1: current (old) stack pointer */
     "call *%%ecx\n"       /* call save_state()                  */

     "testl %%eax, %%eax\n"/* skip the rest if the return value is null */
     "jz 0f\n"

     "movl %%eax, %%esp\n"     /* change the stack pointer */

     /* From now on, the stack pointer is modified, but the content of the
        stack is not restored yet.  It contains only garbage here. */

     "pushl %%edi\n"       /* arg 2: extra                       */
     "pushl %%eax\n"       /* arg 1: current (new) stack pointer */
     "call *%%esi\n"       /* call restore_state()               */

     /* The stack's content is now restored. */

     "0:\n"
     "addl $8, %%esp\n"
     "popl %%ebp\n"
     "popl %%edi\n"
     "movl %%ebp, %%esp\n"
     "popl %%esi\n"
     "popl %%ebx\n"
     "popl %%ebp\n"

     : "=a"(result),             /* output variables */
       "=c"(garbage1),
       "=d"(garbage2)
     : "a"(restore_state),       /* input variables  */
       "c"(save_state),
       "d"(extra)
     : "memory"
     );
  /* Note: we should also list all fp/xmm registers, but is there a way
     to list only the ones used by the current compilation target?
     For now we will just ignore the issue and hope (reasonably) that
     this function is never inlined all the way into 3rd-party user code. */
  return result;
}
