
static void *slp_switch(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra)
{
  void *result, *garbage1, *garbage2;
  __asm__ volatile (
     "pushq %%rbp\n"
     "pushq %%rbx\n"       /* push the registers specified as caller-save */
     "pushq %%r12\n"
     "pushq %%r13\n"
     "pushq %%r14\n"
     "movq %%rsp, %%rbp\n"
     "andq $-16, %%rsp\n"   /* <= align the stack here... */
     "pushq %%r15\n"
     "pushq %%rbp\n"       /* ...so that rsp is now a multiple of 16 */

     "movq %%rax, %%r12\n" /* save 'restore_state' for later */
     "movq %%rsi, %%r13\n" /* save 'extra' for later         */

                           /* arg 2: extra (already in rsi)      */
     "movq %%rsp, %%rdi\n" /* arg 1: current (old) stack pointer */
     "call *%%rcx\n"       /* call save_state()                  */

     "testq %%rax, %%rax\n"    /* skip the rest if the return value is null */
     "jz 0f\n"

     "movq %%rax, %%rsp\n"     /* change the stack pointer */

     /* From now on, the stack pointer is modified, but the content of the
        stack is not restored yet.  It contains only garbage here. */

     "movq %%r13, %%rsi\n" /* arg 2: extra                       */
     "movq %%rax, %%rdi\n" /* arg 1: current (new) stack pointer */
     "call *%%r12\n"       /* call restore_state()               */

     /* The stack's content is now restored. */

     "0:\n"
     "popq %%rbp\n"
     "popq %%r15\n"
     "movq %%rbp, %%rsp\n"
     "popq %%r14\n"
     "popq %%r13\n"
     "popq %%r12\n"
     "popq %%rbx\n"
     "popq %%rbp\n"

     : "=a"(result),             /* output variables */
       "=c"(garbage1),
       "=S"(garbage2)
     : "a"(restore_state),       /* input variables  */
       "c"(save_state),
       "S"(extra)
     : "memory", "rdx", "rdi", "r8", "r9", "r10", "r11",
       "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7",
       "xmm8", "xmm9", "xmm10","xmm11","xmm12","xmm13","xmm14","xmm15"
     );
  return result;
}
