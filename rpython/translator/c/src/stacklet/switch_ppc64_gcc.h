#if !(defined(__LITTLE_ENDIAN__) ^ defined(__BIG_ENDIAN__))
# error "cannot determine if it is ppc64 or ppc64le"
#endif

#ifdef __BIG_ENDIAN__
# define TOC_AREA   "40"
#else
# define TOC_AREA   "24"
#endif


/* This depends on these attributes so that gcc generates a function
   with no code before the asm, and only "blr" after. */
static __attribute__((noinline, optimize("O2")))
void *slp_switch(void *(*save_state)(void*, void*),
                 void *(*restore_state)(void*, void*),
                 void *extra)
{
  void *result;
  __asm__ volatile (
     /* By Vaibhav Sood & Armin Rigo, with some copying from
        the Stackless version by Kristjan Valur Jonsson */

     /* Save all 18 volatile GP registers, 18 volatile FP regs, and 12
        volatile vector regs.  We need a stack frame of 144 bytes for FPR,
        144 bytes for GPR, 192 bytes for VR plus 48 bytes for the standard
        stackframe = 528 bytes (a multiple of 16). */

     "mflr  0\n"               /* Save LR into 16(r1) */
     "std  0, 16(1)\n"

     "std  14,-288(1)\n"      /* the GPR save area is between -288(r1) */
     "std  15,-280(1)\n"      /*        included and -144(r1) excluded */
     "std  16,-272(1)\n"
     "std  17,-264(1)\n"
     "std  18,-256(1)\n"
     "std  19,-248(1)\n"
     "std  20,-240(1)\n"
     "std  21,-232(1)\n"
     "std  22,-224(1)\n"
     "std  23,-216(1)\n"
     "std  24,-208(1)\n"
     "std  25,-200(1)\n"
     "std  26,-192(1)\n"
     "std  27,-184(1)\n"
     "std  28,-176(1)\n"
     "std  29,-168(1)\n"
     "std  30,-160(1)\n"
     "std  31,-152(1)\n"

     "stfd 14,-144(1)\n"      /* the FPR save area is between -144(r1) */
     "stfd 15,-136(1)\n"      /*           included and 0(r1) excluded */
     "stfd 16,-128(1)\n"
     "stfd 17,-120(1)\n"
     "stfd 18,-112(1)\n"
     "stfd 19,-104(1)\n"
     "stfd 20,-96(1)\n"
     "stfd 21,-88(1)\n"
     "stfd 22,-80(1)\n"
     "stfd 23,-72(1)\n"
     "stfd 24,-64(1)\n"
     "stfd 25,-56(1)\n"
     "stfd 26,-48(1)\n"
     "stfd 27,-40(1)\n"
     "stfd 28,-32(1)\n"
     "stfd 29,-24(1)\n"
     "stfd 30,-16(1)\n"
     "stfd 31,-8(1)\n"

     "li 12,-480\n"           /* the VR save area is between -480(r1) */
     "stvx 20,12,1\n"         /*       included and -288(r1) excluded */
     "li 12,-464\n"
     "stvx 21,12,1\n"
     "li 12,-448\n"
     "stvx 22,12,1\n"
     "li 12,-432\n"
     "stvx 23,12,1\n"
     "li 12,-416\n"
     "stvx 24,12,1\n"
     "li 12,-400\n"
     "stvx 25,12,1\n"
     "li 12,-384\n"
     "stvx 26,12,1\n"
     "li 12,-368\n"
     "stvx 27,12,1\n"
     "li 12,-352\n"
     "stvx 28,12,1\n"
     "li 12,-336\n"
     "stvx 29,12,1\n"
     "li 12,-320\n"
     "stvx 30,12,1\n"
     "li 12,-304\n"
     "stvx 31,12,1\n"

     "stdu  1,-528(1)\n"         /* Create stack frame             */

     "std   2, "TOC_AREA"(1)\n"  /* Save TOC in the "TOC save area"*/
     "mfcr  12\n"                /* Save CR in the "CR save area"  */
     "std   12, 8(1)\n"

     "mr 14, %[restore_state]\n" /* save 'restore_state' for later */
     "mr 15, %[extra]\n"         /* save 'extra' for later */
     "mr 12, %[save_state]\n"    /* move 'save_state' into r12 for branching */
     "mr 3, 1\n"                 /* arg 1: current (old) stack pointer */
     "mr 4, 15\n"                /* arg 2: extra                       */

     "stdu 1, -48(1)\n"       /* create temp stack space (see below) */
#ifdef __BIG_ENDIAN__
     "ld 0, 0(12)\n"
     "ld 11, 16(12)\n"
     "mtctr 0\n"
     "ld 2, 8(12)\n"
#else
     "mtctr 12\n"             /* r12 is fixed by this ABI           */
#endif
     "bctrl\n"                /* call save_state()                  */
     "addi 1, 1, 48\n"        /* destroy temp stack space           */

     "cmpdi 3, 0\n"     /* skip the rest if the return value is null */
     "bt eq, zero\n"

     "mr 1, 3\n"              /* change the stack pointer */
       /* From now on, the stack pointer is modified, but the content of the
        stack is not restored yet.  It contains only garbage here. */

     "mr 4, 15\n"             /* arg 2: extra                       */
                              /* arg 1: current (new) stack pointer
                                 is already in r3                   */

     "stdu 1, -48(1)\n"       /* create temp stack space for callee to use  */
     /* ^^^ we have to be careful. The function call will store the link
        register in the current frame (as the ABI) dictates. But it will
        then trample it with the restore! We fix this by creating a fake
        stack frame */

#ifdef __BIG_ENDIAN__
     "ld 0, 0(14)\n"          /* 'restore_state' is in r14          */
     "ld 11, 16(14)\n"
     "mtctr 0\n"
     "ld 2, 8(14)\n"
#endif
#ifdef __LITTLE_ENDIAN__
     "mr 12, 14\n"            /* copy 'restore_state'               */
     "mtctr 12\n"             /* r12 is fixed by this ABI           */
#endif

     "bctrl\n"                /* call restore_state()               */
     "addi 1, 1, 48\n"        /* destroy temp stack space           */

     /* The stack's content is now restored. */

     "zero:\n"

     /* Epilogue */

     "ld 2, "TOC_AREA"(1)\n"  /* restore the TOC */
     "ld 12,8(1)\n"           /* restore the condition register */
     "mtcrf 0xff, 12\n"

     "addi 1,1,528\n"         /* restore stack pointer */

     "li 12,-480\n"           /* restore vector registers */
     "lvx 20,12,1\n"
     "li 12,-464\n"
     "lvx 21,12,1\n"
     "li 12,-448\n"
     "lvx 22,12,1\n"
     "li 12,-432\n"
     "lvx 23,12,1\n"
     "li 12,-416\n"
     "lvx 24,12,1\n"
     "li 12,-400\n"
     "lvx 25,12,1\n"
     "li 12,-384\n"
     "lvx 26,12,1\n"
     "li 12,-368\n"
     "lvx 27,12,1\n"
     "li 12,-352\n"
     "lvx 28,12,1\n"
     "li 12,-336\n"
     "lvx 29,12,1\n"
     "li 12,-320\n"
     "lvx 30,12,1\n"
     "li 12,-304\n"
     "lvx 31,12,1\n"

     "ld  14,-288(1)\n"     /* restore general purporse registers */
     "ld  15,-280(1)\n"
     "ld  16,-272(1)\n"
     "ld  17,-264(1)\n"
     "ld  18,-256(1)\n"
     "ld  19,-248(1)\n"
     "ld  20,-240(1)\n"
     "ld  21,-232(1)\n"
     "ld  22,-224(1)\n"
     "ld  23,-216(1)\n"
     "ld  24,-208(1)\n"
     "ld  25,-200(1)\n"
     "ld  26,-192(1)\n"
     "ld  27,-184(1)\n"
     "ld  28,-176(1)\n"
     "ld  29,-168(1)\n"
     "ld  30,-160(1)\n"
     "ld  31,-152(1)\n"

     "lfd 14,-144(1)\n"     /* restore floating point registers */
     "lfd 15,-136(1)\n"
     "lfd 16,-128(1)\n"
     "lfd 17,-120(1)\n"
     "lfd 18,-112(1)\n"
     "lfd 19,-104(1)\n"
     "lfd 20,-96(1)\n"
     "lfd 21,-88(1)\n"
     "lfd 22,-80(1)\n"
     "lfd 23,-72(1)\n"
     "lfd 24,-64(1)\n"
     "lfd 25,-56(1)\n"
     "lfd 26,-48(1)\n"
     "lfd 27,-40(1)\n"
     "lfd 28,-32(1)\n"
     "ld 0, 16(1)\n"
     "lfd 29,-24(1)\n"
     "mtlr 0\n"
     "lfd 30,-16(1)\n"
     "lfd 31,-8(1)\n"

     : "=r"(result)         /* output variable: expected to be r3 */
     : [restore_state]"r"(restore_state),       /* input variables */
       [save_state]"r"(save_state),
       [extra]"r"(extra)
  );
  return result;
}
