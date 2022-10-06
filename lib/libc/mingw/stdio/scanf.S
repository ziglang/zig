/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

/* vsscanf, vswscanf, vfscanf, and vfwscanf all come here for i386 and arm.

   The goal of this routine is to turn a call to v*scanf into a call to
   s*scanf.  This is needed because mingw-w64 uses msvcr100.dll, which doesn't
   support the v*scanf functions instead of msvcr120.dll which does.
*/

/* The function prototype here is (essentially):

   int __ms_v*scanf_internal (void *s,
			     void *format,
			     void *arg,
			     size_t count,
			     void *func);

   I say 'essentially' because passing a function pointer as void in ISO
   is not supported.  But in the end, I take the first parameter (which
   may be a char *, a wchar_t *, or a FILE *) and put it into the newly
   formed stack, and eventually call the address in func.  */

#if defined (__x86_64__)

    .text
    .align 16

    /* scl   2: C_EXT  - External (public) symbol - covers globals and externs
       type 32: DT_FCN - function returning T
	 */
    .def __argtos;    .scl    2;    .type    32;    .endef

    .seh_proc __argtos
__argtos:

    /* When we are done:
      - s must be in rcx.  That's where it is on entry.
      - format must be in rdx.  That's where it is on entry.
      - The first pointer in arg must be in r8. arg is in r8 on entry.
      - The second pointer in arg must be in r9. arg is in r8 on entry.
      - The (count - 2) other pointers in arg must be on the stack,
	starting 32bytes into rsp.  */

    pushq %rbp
    .seh_pushreg %rbp
    movq %rsp, %rbp
    .seh_setframe %rbp, 0

    /* We need to always reserve space to shadow 4 parameters.  */
    subq $32, %rsp
    .seh_stackalloc 32
    .seh_endprologue

    movq 48(%rbp), %r10 /* func. */

    /* We need enough room to shadow all the other args.
       Except the first 2, since they will be loaded in registers.  */
    cmpq $2, %r9 /* count. */
    jbe .SKIP
    subq $2, %r9 /* # of ptrs to copy.  */
    /* Calculate stack size (arg is 8byte) and keep the stack 16byte aligned. */
    leaq 8(, %r9, 8), %rax /* %rax = (%r9 + 1) * 8 */
    andq $-16, %rax
    subq %rax, %rsp

    /* We are going to copy parameters from arg to our local stack.
       The first 32 bytes are in registers, but by spec, space
       must still be reserved for them on the stack.  Put the
       rest of the pointers in the stack after that.  */
    lea 32(%rsp), %r11 /* dst.  */

.LOOP:
    subq $1, %r9

    /* Use 16 to skip over the first 2 pointers.  */
    movq 16(%r8, %r9, 8), %rax
    movq %rax, (%r11, %r9, 8)
    jnz .LOOP

.SKIP:
    /* The stack is now correctly populated, and so are rcx and rdx.
       But we need to load the last 2 regs before making the call.  */
    movq 0x8(%r8), %r9 /* 2nd dest location (may be garbage if only 1 arg).  */
    movq (%r8), %r8 /* 1st dest location (may be garbage if no arg).  */

    /* Make the call.  */
    callq *%r10

    /* Restore stack.  */
    movq %rbp, %rsp

    popq %rbp
    retq
    .seh_endproc

#elif defined (_X86_)

    .text
    .align 16

    /* scl   2: C_EXT  - External (public) symbol - covers globals and externs
       type 32: DT_FCN - function returning T
	 */
    .def __argtos;    .scl    2;    .type    32;    .endef

__argtos:
    pushl %ebp
    movl %esp, %ebp
    pushl %edi
    pushl %ebx

    /* Reserve enough stack space for everything.

       Stack usage will look like:
       4 bytes - s
       4 bytes - format
       4*count bytes - variable # of parameters for sscanf (all ptrs).  */

    movl 20(%ebp), %ebx  /* count.  */
    addl $2, %ebx  /* s + format.  */
    sall $2, %ebx  /* (count + 2) * 4.  */
    subl %ebx, %esp

    /* Write out s and format where they need to be for the sscanf call.  */
    movl 8(%ebp), %eax
    movl %eax, (%esp)  /* s.  */
    movl 12(%ebp), %edx
    movl %edx, 0x4(%esp)  /* format.  */

    /* We are going to copy _count_ pointers from arg to our
       local stack.  */
    movl 20(%ebp), %ecx /* # of ptrs to copy.  */
    testl %ecx, %ecx
    jz .SKIP
    lea 8(%esp), %edi /* dst.  */
    movl 16(%ebp), %edx /* src.  */

.LOOP:
    subl $1, %ecx

    movl (%edx, %ecx, 4), %eax
    movl %eax, (%edi, %ecx, 4)
    jnz .LOOP

.SKIP:
    /* The stack is now correctly populated.  */

    /* Make the call.  */
    call *24(%ebp)

    /* Restore stack.  */
    addl %ebx, %esp

    popl %ebx
    popl %edi
    leave

    ret

#elif defined (__arm__)

    .text
    .align 2
    .thumb_func
    .globl __argtos

__argtos:
    push    {r4-r8, lr}
    ldr     r12, [sp, #24]

    ldr     r5, [r2], #4
    ldr     r6, [r2], #4

    subs    r3, r3, #2
    mov     r8, #0
    ble     2f

    /* Round the number of entries to an even number, to maintain
     * 8 byte stack alignment. */
    mov     r8, r3
    add     r8, r8, #1
    bic     r8, r8, #1
    sub     sp, sp, r8, lsl #2
    mov     r4, sp
1:  ldr     r7, [r2], #4
    subs    r3, r3, #1
    str     r7, [r4], #4
    bne     1b

2:
    mov     r2, r5
    mov     r3, r6
    blx     r12

    add     sp, sp, r8, lsl #2
    pop     {r4-r8, pc}

#elif defined (__aarch64__)

    .text
    .align 2
    .globl __argtos

__argtos:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x10, x2
    mov     x11, x3
    mov     x12, x4

    ldr     x2, [x10], #8
    ldr     x3, [x10], #8
    ldr     x4, [x10], #8
    ldr     x5, [x10], #8
    ldr     x6, [x10], #8
    ldr     x7, [x10], #8

    subs    x11, x11, #6
    b.le    2f

    /* Round the number of entries to an even number, to maintain
     * 16 byte stack alignment. */
    mov     x13, x11
    add     x13, x13, #1
    bic     x13, x13, #1
    sub     sp, sp, x13, lsl #3
    mov     x9, sp
1:  ldr     x13, [x10], #8
    subs    x11, x11, #1
    str     x13, [x9], #8
    b.ne    1b

2:
    blr     x12
    mov     sp, x29
    ldp     x29, x30, [sp], #16
    ret

#endif
