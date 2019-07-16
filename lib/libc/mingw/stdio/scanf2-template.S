/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#if defined(_ARM_) || defined(__arm__)
        .thumb
#endif
        .text
        .p2align 4,,15
        .globl  FCT
        .def    FCT;    .scl    2;      .type   32;     .endef
#ifdef __x86_64__
        .seh_proc       FCT
#endif
FCT:
#ifdef __x86_64__
        .seh_endprologue
#endif
#if defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)
        jmp     FWD
#elif defined(_ARM_) || defined(__arm__)
        .thumb_func
        b       FWD
#elif defined(_ARM64_) || defined(__aarch64__)
        b       FWD
#endif
#ifdef __x86_64__
        .seh_endproc
#endif
        .def    FWD;  .scl    2;      .type   32;     .endef
