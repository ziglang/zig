/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

/* vsscanf, vswscanf, vfscanf, and vfwscanf all come here for i386 and arm.

   The goal of this routine is to turn a call to v*scanf into a call to
   s*scanf.  This is needed because mingw-w64 uses msvcr100.dll, which doesn't
   support the v*scanf functions instead of msvcr120.dll which does.
   Unfortunately, there is no defined way to know exactly how big a va_list
   is, so we use a hard-coded buffer.

   I suppose a sufficiently-motivated person could try to parse the format
   to figure out how many tokens there are... */

/* The function prototype here is (essentially):

   int __ms_vsscanf_internal (void *s,
			     void *format,
			     void *arg,
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

    /* The max number of pointers we support.  Must be an even number
       to keep the 64bit stack 16byte aligned.  Must not be less than 4.  */
    .equ entries, 30

    /* 64bit pointers are 8 bytes.  */
    .equ sizeof, 8

    /* Size of our buffer.  */
    .equ iBytes, entries * sizeof

    /* Stack space for first 2 args to s*scanf.  */
    .equ iOffset, (2 * sizeof)

    .seh_proc __argtos
__argtos:

    /* When we are done:
      - s must be in rcx.  That's where it is on entry.
      - format must be in rdx.  That's where it is on entry.
      - The first pointer in arg must be in r8. arg is in r8 on entry.
      - The second pointer in arg must be in r9. arg is in r8 on entry.
      - The ($entries - 2) other pointers in arg must be on the stack,
	starting 32bytes into rsp.  */

    /* We need enough room to shadow (s + format)
       + (enough room for all the other args).  */
    subq $(iOffset + iBytes), %rsp
    .seh_stackalloc iOffset + iBytes

    .seh_endprologue

    /* We are going to copy $entries pointers from arg to our
       local stack.  Except the first 2, since they will be
       loaded in registers.  */
    movq $entries - 2, %r10 /* # of ptrs to copy.  */

    /* The first 32 bytes are in registers, but by spec, space
	   must still be reserved for them on the stack.  Put the
       rest of the pointers in the stack after that.  */
    lea 32(%rsp), %r11 /* dst.  */

.LOOP:
    subq $1, %r10

    /* Use 16 to skip over the first 2 pointers.  */
    movq 16(%r8, %r10, 8), %rax
    movq %rax, (%r11, %r10, 8)
    jnz .LOOP

    /* r9 contains the routine we are going to call.  Since we are about to
       overwrite it, move it somewhere safe.  */
    movq %r9, %r10

    /* The stack is now correctly populated, and so are rcx and rdx.
       But we need to load the last 2 regs before making the call.  */
    movq 0x8(%r8), %r9 /* 2nd dest location (may be garbage if only 1 arg).  */
    movq (%r8), %r8 /* 1st dest location.  */

    /* Make the call.  */
    callq *%r10

    addq $(iOffset + iBytes), %rsp

    retq
    .seh_endproc

#elif defined (_X86_)

    .text
    .align 16

    /* scl   2: C_EXT  - External (public) symbol - covers globals and externs
       type 32: DT_FCN - function returning T
	 */
    .def __argtos;    .scl    2;    .type    32;    .endef

    /* The max number of pointers we support.  Must not be less than 1.  */
    .equ entries, 30

    /* 64bit pointers are 8 bytes.  */
    .equ sizeof, 4

    /* Size of our buffer.  */
    .set iBytes, entries * sizeof

    /* Stack space for first 2 args to s*scanf.  */
    .equ iOffset, (2 * sizeof)

__argtos:
    pushl %ebp
    movl %esp, %ebp
    pushl %edi

    /* Reserve enough stack space for everything.

       Stack usage will look like:
       4 bytes - s
       4 bytes - format
       (iBytes) bytes - variable # of parameters for sscanf (all ptrs).  */

    subl $(iOffset + iBytes), %esp

    /* Write out s and format where they need to be for the sscanf call.  */
    movl 8(%ebp), %eax
    movl %eax, (%esp)  /* s.  */
    movl 12(%ebp), %edx
    movl %edx, 0x4(%esp)  /* format.  */

    /* We are going to copy $entries pointers from arg to our
       local stack.  */
    movl $entries, %ecx /* # of ptrs to copy.  */
    lea iOffset(%esp), %edi /* dst.  */
    movl 16(%ebp), %edx /* src.  */

.LOOP:
    subl $1, %ecx

    movl (%edx, %ecx, 4), %eax
    movl %eax, (%edi, %ecx, 4)
    jnz .LOOP

    /* The stack is now correctly populated.  */

    /* Make the call.  */
    call *20(%ebp)

    /* Restore stack.  */
    addl $(iOffset + iBytes), %esp
    popl %edi
    leave

    ret

#elif defined (__arm__)

    .text
    .align 2
    .thumb_func
    .globl __argtos

__argtos:
    push    {r4-r7, lr}
    sub     sp, sp, #128
    mov     r12, r3
    mov     r4, sp

    ldr     r5, [r2], #4
    ldr     r6, [r2], #4

    mov     r3, #116
1:  ldr     r7, [r2], #4
    str     r7, [r4], #4
    subs    r3, r3, #4
    bne     1b

    mov     r2, r5
    mov     r3, r6
    blx     r12
    add     sp, sp, #128
    pop     {r4-r7, pc}

#elif defined (__aarch64__)

    .text
    .align 2
    .globl __argtos

__argtos:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    sub     sp, sp, #256
    mov     x9, sp
    mov     x10, x2
    mov     x11, x3

    ldr     x2, [x10], #8
    ldr     x3, [x10], #8
    ldr     x4, [x10], #8
    ldr     x5, [x10], #8
    ldr     x6, [x10], #8
    ldr     x7, [x10], #8

    mov     x12, #240
1:  ldr     x13, [x10], #8
    str     x13, [x9], #8
    subs    x12, x12, #8
    b.ne    1b

    blr     x11
    mov     sp, x29
    ldp     x29, x30, [sp], #16
    ret

#endif
