/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw_mac.h>

        .globl  __MINGW_USYMBOL(__intrinsic_setjmp)
        .def    __MINGW_USYMBOL(__intrinsic_setjmp); .scl 2; .type 32; .endef

#if defined(_WIN64)
        .globl  __MINGW_USYMBOL(__intrinsic_setjmpex)
        .def    __MINGW_USYMBOL(__intrinsic_setjmpex); .scl 2; .type 32; .endef
#endif

#if defined(__i386__)
        .globl  __MINGW_USYMBOL(_setjmp3)
        .def    __MINGW_USYMBOL(_setjmp3); .scl 2; .type 32; .endef
__MINGW_USYMBOL(_setjmp3):
__MINGW_USYMBOL(__intrinsic_setjmp):
        movl    4(%esp),%ecx         /* jmp_buf */
        movl    %ebp,0(%ecx)         /* jmp_buf.Ebp */
        movl    %ebx,4(%ecx)         /* jmp_buf.Ebx */
        movl    %edi,8(%ecx)         /* jmp_buf.Edi */
        movl    %esi,12(%ecx)        /* jmp_buf.Esi */
        movl    %esp,16(%ecx)        /* jmp_buf.Esp */
        movl    0(%esp),%eax
        movl    %eax,20(%ecx)        /* jmp_buf.Eip */
        xorl    %eax, %eax
        retl

#elif defined(__x86_64__)
        .globl  __MINGW_USYMBOL(setjmp)
        .def    __MINGW_USYMBOL(setjmp); .scl 2; .type 32; .endef
__MINGW_USYMBOL(setjmp):
__MINGW_USYMBOL(__intrinsic_setjmp):
        xorq    %rdx,%rdx
__MINGW_USYMBOL(__intrinsic_setjmpex):
        movq    %rdx,(%rcx)          /* jmp_buf->Frame */
        movq    %rbx,0x8(%rcx)       /* jmp_buf->Rbx */
        leaq    0x8(%rsp),%rax
        movq    %rax,0x10(%rcx)      /* jmp_buf->Rsp */
        movq    %rbp,0x18(%rcx)      /* jmp_buf->Rbp */
        movq    %rsi,0x20(%rcx)      /* jmp_buf->Rsi */
        movq    %rdi,0x28(%rcx)      /* jmp_buf->Rdi */
        movq    %r12,0x30(%rcx)      /* jmp_buf->R12 */
        movq    %r13,0x38(%rcx)      /* jmp_buf->R13 */
        movq    %r14,0x40(%rcx)      /* jmp_buf->R14 */
        movq    %r15,0x48(%rcx)      /* jmp_buf->R15 */
        movq    (%rsp),%rax
        movq    %rax,0x50(%rcx)      /* jmp_buf->Rip */
        movdqa  %xmm6,0x60(%rcx)     /* jmp_buf->Xmm6 */
        movdqa  %xmm7,0x70(%rcx)     /* jmp_buf->Xmm7 */
        movdqa  %xmm8,0x80(%rcx)     /* jmp_buf->Xmm8 */
        movdqa  %xmm9,0x90(%rcx)     /* jmp_buf->Xmm9 */
        movdqa  %xmm10,0xa0(%rcx)    /* jmp_buf->Xmm10 */
        movdqa  %xmm11,0xb0(%rcx)    /* jmp_buf->Xmm11 */
        movdqa  %xmm12,0xc0(%rcx)    /* jmp_buf->Xmm12 */
        movdqa  %xmm13,0xd0(%rcx)    /* jmp_buf->Xmm13 */
        movdqa  %xmm14,0xe0(%rcx)    /* jmp_buf->Xmm14 */
        movdqa  %xmm15,0xf0(%rcx)    /* jmp_buf->Xmm15 */
        xorq    %rax,%rax
        retq

#elif defined(__arm__)
__MINGW_USYMBOL(__intrinsic_setjmp):
        mov     r1,  #0
        str     r1,  [r0]            /* jmp_buf->Frame */
        str     r4,  [r0, #0x4]      /* jmp_buf->R4 */
        str     r5,  [r0, #0x8]      /* jmp_buf->R5 */
        str     r6,  [r0, #0xc]      /* jmp_buf->R6 */
        str     r7,  [r0, #0x10]     /* jmp_buf->R7 */
        str     r8,  [r0, #0x14]     /* jmp_buf->R8 */
        str     r9,  [r0, #0x18]     /* jmp_buf->R9 */
        str     r10, [r0, #0x1c]     /* jmp_buf->R10 */
        str     r11, [r0, #0x20]     /* jmp_buf->R11 */
        str     sp,  [r0, #0x24]     /* jmp_buf->Sp */
        str     lr,  [r0, #0x28]     /* jmp_buf->Pc */
        vmrs    r2,  fpscr
        str     r2,  [r0, #0x2c]     /* jmp_buf->Fpscr */
        vstr    d8,  [r0, #0x30]     /* jmp_buf->D[0] */
        vstr    d9,  [r0, #0x38]     /* jmp_buf->D[1] */
        vstr    d10, [r0, #0x40]     /* jmp_buf->D[2] */
        vstr    d11, [r0, #0x48]     /* jmp_buf->D[3] */
        vstr    d12, [r0, #0x50]     /* jmp_buf->D[4] */
        vstr    d13, [r0, #0x58]     /* jmp_buf->D[5] */
        vstr    d14, [r0, #0x60]     /* jmp_buf->D[6] */
        vstr    d15, [r0, #0x68]     /* jmp_buf->D[7] */
        mov     r0,  #0
        bx      lr
#elif defined(__aarch64__)
__MINGW_USYMBOL(__intrinsic_setjmp):
        mov     x1,  #0
__MINGW_USYMBOL(__intrinsic_setjmpex):
        str     x1,  [x0]             /* jmp_buf->Frame */
        stp     x19, x20, [x0, #0x10] /* jmp_buf->X19, X20 */
        stp     x21, x22, [x0, #0x20] /* jmp_buf->X21, X22 */
        stp     x23, x24, [x0, #0x30] /* jmp_buf->X23, X24 */
        stp     x25, x26, [x0, #0x40] /* jmp_buf->X25, X26 */
        stp     x27, x28, [x0, #0x50] /* jmp_buf->X27, X28 */
        stp     x29, x30, [x0, #0x60] /* jmp_buf->Fp,  Lr  */
        mov     x2,  sp
        str     x2,       [x0, #0x70] /* jmp_buf->Sp */
        mrs     x2,  fpcr
        str     w2,       [x0, #0x78] /* jmp_buf->Fpcr */
        mrs     x2,  fpsr
        str     w2,       [x0, #0x7c] /* jmp_buf->Fpsr */
        stp     d8,  d9,  [x0, #0x80] /* jmp_buf->D[0-1] */
        stp     d10, d11, [x0, #0x90] /* jmp_buf->D[2-3] */
        stp     d12, d13, [x0, #0xa0] /* jmp_buf->D[4-5] */
        stp     d14, d15, [x0, #0xb0] /* jmp_buf->D[6-7] */
        mov     x0,  #0
        ret
#endif
