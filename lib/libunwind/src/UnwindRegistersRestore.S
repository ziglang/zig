//===-------------------- UnwindRegistersRestore.S ------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "assembly.h"

  .text

#if !defined(__USING_SJLJ_EXCEPTIONS__)

#if defined(__i386__)
DEFINE_LIBUNWIND_FUNCTION(__libunwind_Registers_x86_jumpto)
#
# extern "C" void __libunwind_Registers_x86_jumpto(Registers_x86 *);
#
# On entry:
#  +                       +
#  +-----------------------+
#  + thread_state pointer  +
#  +-----------------------+
#  + return address        +
#  +-----------------------+   <-- SP
#  +                       +
  movl   4(%esp), %eax
  # set up eax and ret on new stack location
  movl  28(%eax), %edx # edx holds new stack pointer
  subl  $8,%edx
  movl  %edx, 28(%eax)
  movl  0(%eax), %ebx
  movl  %ebx, 0(%edx)
  movl  40(%eax), %ebx
  movl  %ebx, 4(%edx)
  # we now have ret and eax pushed onto where new stack will be
  # restore all registers
  movl   4(%eax), %ebx
  movl   8(%eax), %ecx
  movl  12(%eax), %edx
  movl  16(%eax), %edi
  movl  20(%eax), %esi
  movl  24(%eax), %ebp
  movl  28(%eax), %esp
  # skip ss
  # skip eflags
  pop    %eax  # eax was already pushed on new stack
  ret        # eip was already pushed on new stack
  # skip cs
  # skip ds
  # skip es
  # skip fs
  # skip gs

#elif defined(__x86_64__)

DEFINE_LIBUNWIND_FUNCTION(__libunwind_Registers_x86_64_jumpto)
#
# extern "C" void __libunwind_Registers_x86_64_jumpto(Registers_x86_64 *);
#
#if defined(_WIN64)
# On entry, thread_state pointer is in rcx; move it into rdi
# to share restore code below. Since this routine restores and
# overwrites all registers, we can use the same registers for
# pointers and temporaries as on unix even though win64 normally
# mustn't clobber some of them.
  movq  %rcx, %rdi
#else
# On entry, thread_state pointer is in rdi
#endif

  movq  56(%rdi), %rax # rax holds new stack pointer
  subq  $16, %rax
  movq  %rax, 56(%rdi)
  movq  32(%rdi), %rbx  # store new rdi on new stack
  movq  %rbx, 0(%rax)
  movq  128(%rdi), %rbx # store new rip on new stack
  movq  %rbx, 8(%rax)
  # restore all registers
  movq    0(%rdi), %rax
  movq    8(%rdi), %rbx
  movq   16(%rdi), %rcx
  movq   24(%rdi), %rdx
  # restore rdi later
  movq   40(%rdi), %rsi
  movq   48(%rdi), %rbp
  # restore rsp later
  movq   64(%rdi), %r8
  movq   72(%rdi), %r9
  movq   80(%rdi), %r10
  movq   88(%rdi), %r11
  movq   96(%rdi), %r12
  movq  104(%rdi), %r13
  movq  112(%rdi), %r14
  movq  120(%rdi), %r15
  # skip rflags
  # skip cs
  # skip fs
  # skip gs

#if defined(_WIN64)
  movdqu 176(%rdi),%xmm0
  movdqu 192(%rdi),%xmm1
  movdqu 208(%rdi),%xmm2
  movdqu 224(%rdi),%xmm3
  movdqu 240(%rdi),%xmm4
  movdqu 256(%rdi),%xmm5
  movdqu 272(%rdi),%xmm6
  movdqu 288(%rdi),%xmm7
  movdqu 304(%rdi),%xmm8
  movdqu 320(%rdi),%xmm9
  movdqu 336(%rdi),%xmm10
  movdqu 352(%rdi),%xmm11
  movdqu 368(%rdi),%xmm12
  movdqu 384(%rdi),%xmm13
  movdqu 400(%rdi),%xmm14
  movdqu 416(%rdi),%xmm15
#endif
  movq  56(%rdi), %rsp  # cut back rsp to new location
  pop    %rdi      # rdi was saved here earlier
  ret            # rip was saved here


#elif defined(__powerpc64__)

DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind15Registers_ppc646jumptoEv)
//
// void libunwind::Registers_ppc64::jumpto()
//
// On entry:
//  thread_state pointer is in r3
//

// load register (GPR)
#define PPC64_LR(n) \
  ld    n, (8 * (n + 2))(3)

  // restore integral registers
  // skip r0 for now
  // skip r1 for now
  PPC64_LR(2)
  // skip r3 for now
  // skip r4 for now
  // skip r5 for now
  PPC64_LR(6)
  PPC64_LR(7)
  PPC64_LR(8)
  PPC64_LR(9)
  PPC64_LR(10)
  PPC64_LR(11)
  PPC64_LR(12)
  PPC64_LR(13)
  PPC64_LR(14)
  PPC64_LR(15)
  PPC64_LR(16)
  PPC64_LR(17)
  PPC64_LR(18)
  PPC64_LR(19)
  PPC64_LR(20)
  PPC64_LR(21)
  PPC64_LR(22)
  PPC64_LR(23)
  PPC64_LR(24)
  PPC64_LR(25)
  PPC64_LR(26)
  PPC64_LR(27)
  PPC64_LR(28)
  PPC64_LR(29)
  PPC64_LR(30)
  PPC64_LR(31)

#if defined(__VSX__)

  // restore VS registers
  // (note that this also restores floating point registers and V registers,
  // because part of VS is mapped to these registers)

  addi  4, 3, PPC64_OFFS_FP

// load VS register
#define PPC64_LVS(n)         \
  lxvd2x  n, 0, 4           ;\
  addi    4, 4, 16

  // restore the first 32 VS regs (and also all floating point regs)
  PPC64_LVS(0)
  PPC64_LVS(1)
  PPC64_LVS(2)
  PPC64_LVS(3)
  PPC64_LVS(4)
  PPC64_LVS(5)
  PPC64_LVS(6)
  PPC64_LVS(7)
  PPC64_LVS(8)
  PPC64_LVS(9)
  PPC64_LVS(10)
  PPC64_LVS(11)
  PPC64_LVS(12)
  PPC64_LVS(13)
  PPC64_LVS(14)
  PPC64_LVS(15)
  PPC64_LVS(16)
  PPC64_LVS(17)
  PPC64_LVS(18)
  PPC64_LVS(19)
  PPC64_LVS(20)
  PPC64_LVS(21)
  PPC64_LVS(22)
  PPC64_LVS(23)
  PPC64_LVS(24)
  PPC64_LVS(25)
  PPC64_LVS(26)
  PPC64_LVS(27)
  PPC64_LVS(28)
  PPC64_LVS(29)
  PPC64_LVS(30)
  PPC64_LVS(31)

  // use VRSAVE to conditionally restore the remaining VS regs,
  // that are where the V regs are mapped

  ld    5, PPC64_OFFS_VRSAVE(3)   // test VRsave
  cmpwi 5, 0
  beq   Lnovec

// conditionally load VS
#define PPC64_CLVS_BOTTOM(n)               \
  beq    Ldone##n                         ;\
  addi   4, 3, PPC64_OFFS_FP + n * 16     ;\
  lxvd2x n, 0, 4                          ;\
Ldone##n:

#define PPC64_CLVSl(n)                    \
  andis. 0, 5, (1 PPC_LEFT_SHIFT(47-n))  ;\
PPC64_CLVS_BOTTOM(n)

#define PPC64_CLVSh(n)                    \
  andi.  0, 5, (1 PPC_LEFT_SHIFT(63-n))  ;\
PPC64_CLVS_BOTTOM(n)

  PPC64_CLVSl(32)
  PPC64_CLVSl(33)
  PPC64_CLVSl(34)
  PPC64_CLVSl(35)
  PPC64_CLVSl(36)
  PPC64_CLVSl(37)
  PPC64_CLVSl(38)
  PPC64_CLVSl(39)
  PPC64_CLVSl(40)
  PPC64_CLVSl(41)
  PPC64_CLVSl(42)
  PPC64_CLVSl(43)
  PPC64_CLVSl(44)
  PPC64_CLVSl(45)
  PPC64_CLVSl(46)
  PPC64_CLVSl(47)
  PPC64_CLVSh(48)
  PPC64_CLVSh(49)
  PPC64_CLVSh(50)
  PPC64_CLVSh(51)
  PPC64_CLVSh(52)
  PPC64_CLVSh(53)
  PPC64_CLVSh(54)
  PPC64_CLVSh(55)
  PPC64_CLVSh(56)
  PPC64_CLVSh(57)
  PPC64_CLVSh(58)
  PPC64_CLVSh(59)
  PPC64_CLVSh(60)
  PPC64_CLVSh(61)
  PPC64_CLVSh(62)
  PPC64_CLVSh(63)

#else

// load FP register
#define PPC64_LF(n) \
  lfd   n, (PPC64_OFFS_FP + n * 16)(3)

  // restore float registers
  PPC64_LF(0)
  PPC64_LF(1)
  PPC64_LF(2)
  PPC64_LF(3)
  PPC64_LF(4)
  PPC64_LF(5)
  PPC64_LF(6)
  PPC64_LF(7)
  PPC64_LF(8)
  PPC64_LF(9)
  PPC64_LF(10)
  PPC64_LF(11)
  PPC64_LF(12)
  PPC64_LF(13)
  PPC64_LF(14)
  PPC64_LF(15)
  PPC64_LF(16)
  PPC64_LF(17)
  PPC64_LF(18)
  PPC64_LF(19)
  PPC64_LF(20)
  PPC64_LF(21)
  PPC64_LF(22)
  PPC64_LF(23)
  PPC64_LF(24)
  PPC64_LF(25)
  PPC64_LF(26)
  PPC64_LF(27)
  PPC64_LF(28)
  PPC64_LF(29)
  PPC64_LF(30)
  PPC64_LF(31)

#if defined(__ALTIVEC__)
  // restore vector registers if any are in use
  ld    5, PPC64_OFFS_VRSAVE(3)   // test VRsave
  cmpwi 5, 0
  beq   Lnovec

  subi  4, 1, 16
  // r4 is now a 16-byte aligned pointer into the red zone
  // the _vectorScalarRegisters may not be 16-byte aligned
  // so copy via red zone temp buffer

#define PPC64_CLV_UNALIGNED_BOTTOM(n)            \
  beq    Ldone##n                               ;\
  ld     0, (PPC64_OFFS_V + n * 16)(3)          ;\
  std    0, 0(4)                                ;\
  ld     0, (PPC64_OFFS_V + n * 16 + 8)(3)      ;\
  std    0, 8(4)                                ;\
  lvx    n, 0, 4                                ;\
Ldone  ## n:

#define PPC64_CLV_UNALIGNEDl(n)                 \
  andis. 0, 5, (1 PPC_LEFT_SHIFT(15-n))        ;\
PPC64_CLV_UNALIGNED_BOTTOM(n)

#define PPC64_CLV_UNALIGNEDh(n)                \
  andi.  0, 5, (1 PPC_LEFT_SHIFT(31-n))       ;\
PPC64_CLV_UNALIGNED_BOTTOM(n)

  PPC64_CLV_UNALIGNEDl(0)
  PPC64_CLV_UNALIGNEDl(1)
  PPC64_CLV_UNALIGNEDl(2)
  PPC64_CLV_UNALIGNEDl(3)
  PPC64_CLV_UNALIGNEDl(4)
  PPC64_CLV_UNALIGNEDl(5)
  PPC64_CLV_UNALIGNEDl(6)
  PPC64_CLV_UNALIGNEDl(7)
  PPC64_CLV_UNALIGNEDl(8)
  PPC64_CLV_UNALIGNEDl(9)
  PPC64_CLV_UNALIGNEDl(10)
  PPC64_CLV_UNALIGNEDl(11)
  PPC64_CLV_UNALIGNEDl(12)
  PPC64_CLV_UNALIGNEDl(13)
  PPC64_CLV_UNALIGNEDl(14)
  PPC64_CLV_UNALIGNEDl(15)
  PPC64_CLV_UNALIGNEDh(16)
  PPC64_CLV_UNALIGNEDh(17)
  PPC64_CLV_UNALIGNEDh(18)
  PPC64_CLV_UNALIGNEDh(19)
  PPC64_CLV_UNALIGNEDh(20)
  PPC64_CLV_UNALIGNEDh(21)
  PPC64_CLV_UNALIGNEDh(22)
  PPC64_CLV_UNALIGNEDh(23)
  PPC64_CLV_UNALIGNEDh(24)
  PPC64_CLV_UNALIGNEDh(25)
  PPC64_CLV_UNALIGNEDh(26)
  PPC64_CLV_UNALIGNEDh(27)
  PPC64_CLV_UNALIGNEDh(28)
  PPC64_CLV_UNALIGNEDh(29)
  PPC64_CLV_UNALIGNEDh(30)
  PPC64_CLV_UNALIGNEDh(31)

#endif
#endif

Lnovec:
  ld    0, PPC64_OFFS_CR(3)
  mtcr  0
  ld    0, PPC64_OFFS_SRR0(3)
  mtctr 0

  PPC64_LR(0)
  PPC64_LR(5)
  PPC64_LR(4)
  PPC64_LR(1)
  PPC64_LR(3)
  bctr

#elif defined(__ppc__)

DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind13Registers_ppc6jumptoEv)
//
// void libunwind::Registers_ppc::jumpto()
//
// On entry:
//  thread_state pointer is in r3
//

  // restore integral registerrs
  // skip r0 for now
  // skip r1 for now
  lwz     2,  16(3)
  // skip r3 for now
  // skip r4 for now
  // skip r5 for now
  lwz     6,  32(3)
  lwz     7,  36(3)
  lwz     8,  40(3)
  lwz     9,  44(3)
  lwz     10, 48(3)
  lwz     11, 52(3)
  lwz     12, 56(3)
  lwz     13, 60(3)
  lwz     14, 64(3)
  lwz     15, 68(3)
  lwz     16, 72(3)
  lwz     17, 76(3)
  lwz     18, 80(3)
  lwz     19, 84(3)
  lwz     20, 88(3)
  lwz     21, 92(3)
  lwz     22, 96(3)
  lwz     23,100(3)
  lwz     24,104(3)
  lwz     25,108(3)
  lwz     26,112(3)
  lwz     27,116(3)
  lwz     28,120(3)
  lwz     29,124(3)
  lwz     30,128(3)
  lwz     31,132(3)

#ifndef __NO_FPRS__
  // restore float registers
  lfd     0, 160(3)
  lfd     1, 168(3)
  lfd     2, 176(3)
  lfd     3, 184(3)
  lfd     4, 192(3)
  lfd     5, 200(3)
  lfd     6, 208(3)
  lfd     7, 216(3)
  lfd     8, 224(3)
  lfd     9, 232(3)
  lfd     10,240(3)
  lfd     11,248(3)
  lfd     12,256(3)
  lfd     13,264(3)
  lfd     14,272(3)
  lfd     15,280(3)
  lfd     16,288(3)
  lfd     17,296(3)
  lfd     18,304(3)
  lfd     19,312(3)
  lfd     20,320(3)
  lfd     21,328(3)
  lfd     22,336(3)
  lfd     23,344(3)
  lfd     24,352(3)
  lfd     25,360(3)
  lfd     26,368(3)
  lfd     27,376(3)
  lfd     28,384(3)
  lfd     29,392(3)
  lfd     30,400(3)
  lfd     31,408(3)
#endif

#if defined(__ALTIVEC__)
  // restore vector registers if any are in use
  lwz     5, 156(3)       // test VRsave
  cmpwi   5, 0
  beq     Lnovec

  subi    4, 1, 16
  rlwinm  4, 4, 0, 0, 27  // mask low 4-bits
  // r4 is now a 16-byte aligned pointer into the red zone
  // the _vectorRegisters may not be 16-byte aligned so copy via red zone temp buffer


#define LOAD_VECTOR_UNALIGNEDl(_index)          \
  andis.  0, 5, (1 PPC_LEFT_SHIFT(15-_index)) SEPARATOR \
  beq     Ldone ## _index             SEPARATOR \
  lwz     0, 424+_index*16(3)         SEPARATOR \
  stw     0, 0(%r4)                   SEPARATOR \
  lwz     0, 424+_index*16+4(%r3)     SEPARATOR \
  stw     0, 4(%r4)                   SEPARATOR \
  lwz     0, 424+_index*16+8(%r3)     SEPARATOR \
  stw     0, 8(%r4)                   SEPARATOR \
  lwz     0, 424+_index*16+12(%r3)    SEPARATOR \
  stw     0, 12(%r4)                  SEPARATOR \
  lvx     _index, 0, 4                SEPARATOR \
  Ldone ## _index:

#define LOAD_VECTOR_UNALIGNEDh(_index)          \
  andi.   0, 5, (1 PPC_LEFT_SHIFT(31-_index)) SEPARATOR \
  beq     Ldone ## _index             SEPARATOR \
  lwz     0, 424+_index*16(3)         SEPARATOR \
  stw     0, 0(4)                     SEPARATOR \
  lwz     0, 424+_index*16+4(3)       SEPARATOR \
  stw     0, 4(4)                     SEPARATOR \
  lwz     0, 424+_index*16+8(3)       SEPARATOR \
  stw     0, 8(%r4)                   SEPARATOR \
  lwz     0, 424+_index*16+12(3)      SEPARATOR \
  stw     0, 12(4)                    SEPARATOR \
  lvx     _index, 0, 4                SEPARATOR \
  Ldone ## _index:


  LOAD_VECTOR_UNALIGNEDl(0)
  LOAD_VECTOR_UNALIGNEDl(1)
  LOAD_VECTOR_UNALIGNEDl(2)
  LOAD_VECTOR_UNALIGNEDl(3)
  LOAD_VECTOR_UNALIGNEDl(4)
  LOAD_VECTOR_UNALIGNEDl(5)
  LOAD_VECTOR_UNALIGNEDl(6)
  LOAD_VECTOR_UNALIGNEDl(7)
  LOAD_VECTOR_UNALIGNEDl(8)
  LOAD_VECTOR_UNALIGNEDl(9)
  LOAD_VECTOR_UNALIGNEDl(10)
  LOAD_VECTOR_UNALIGNEDl(11)
  LOAD_VECTOR_UNALIGNEDl(12)
  LOAD_VECTOR_UNALIGNEDl(13)
  LOAD_VECTOR_UNALIGNEDl(14)
  LOAD_VECTOR_UNALIGNEDl(15)
  LOAD_VECTOR_UNALIGNEDh(16)
  LOAD_VECTOR_UNALIGNEDh(17)
  LOAD_VECTOR_UNALIGNEDh(18)
  LOAD_VECTOR_UNALIGNEDh(19)
  LOAD_VECTOR_UNALIGNEDh(20)
  LOAD_VECTOR_UNALIGNEDh(21)
  LOAD_VECTOR_UNALIGNEDh(22)
  LOAD_VECTOR_UNALIGNEDh(23)
  LOAD_VECTOR_UNALIGNEDh(24)
  LOAD_VECTOR_UNALIGNEDh(25)
  LOAD_VECTOR_UNALIGNEDh(26)
  LOAD_VECTOR_UNALIGNEDh(27)
  LOAD_VECTOR_UNALIGNEDh(28)
  LOAD_VECTOR_UNALIGNEDh(29)
  LOAD_VECTOR_UNALIGNEDh(30)
  LOAD_VECTOR_UNALIGNEDh(31)
#endif

Lnovec:
  lwz     0, 136(3)   // __cr
  mtcr    0
  lwz     0, 148(3)   // __ctr
  mtctr   0
  lwz     0,   0(3)   // __ssr0
  mtctr   0
  lwz     0,   8(3)   // do r0 now
  lwz     5,  28(3)   // do r5 now
  lwz     4,  24(3)   // do r4 now
  lwz     1,  12(3)   // do sp now
  lwz     3,  20(3)   // do r3 last
  bctr

#elif defined(__aarch64__)

//
// extern "C" void __libunwind_Registers_arm64_jumpto(Registers_arm64 *);
//
// On entry:
//  thread_state pointer is in x0
//
  .p2align 2
DEFINE_LIBUNWIND_FUNCTION(__libunwind_Registers_arm64_jumpto)
  // skip restore of x0,x1 for now
  ldp    x2, x3,  [x0, #0x010]
  ldp    x4, x5,  [x0, #0x020]
  ldp    x6, x7,  [x0, #0x030]
  ldp    x8, x9,  [x0, #0x040]
  ldp    x10,x11, [x0, #0x050]
  ldp    x12,x13, [x0, #0x060]
  ldp    x14,x15, [x0, #0x070]
  // x16 and x17 were clobbered by the call into the unwinder, so no point in
  // restoring them.
  ldp    x18,x19, [x0, #0x090]
  ldp    x20,x21, [x0, #0x0A0]
  ldp    x22,x23, [x0, #0x0B0]
  ldp    x24,x25, [x0, #0x0C0]
  ldp    x26,x27, [x0, #0x0D0]
  ldp    x28,x29, [x0, #0x0E0]
  ldr    x30,     [x0, #0x100]  // restore pc into lr

  ldp    d0, d1,  [x0, #0x110]
  ldp    d2, d3,  [x0, #0x120]
  ldp    d4, d5,  [x0, #0x130]
  ldp    d6, d7,  [x0, #0x140]
  ldp    d8, d9,  [x0, #0x150]
  ldp    d10,d11, [x0, #0x160]
  ldp    d12,d13, [x0, #0x170]
  ldp    d14,d15, [x0, #0x180]
  ldp    d16,d17, [x0, #0x190]
  ldp    d18,d19, [x0, #0x1A0]
  ldp    d20,d21, [x0, #0x1B0]
  ldp    d22,d23, [x0, #0x1C0]
  ldp    d24,d25, [x0, #0x1D0]
  ldp    d26,d27, [x0, #0x1E0]
  ldp    d28,d29, [x0, #0x1F0]
  ldr    d30,     [x0, #0x200]
  ldr    d31,     [x0, #0x208]

  // Finally, restore sp. This must be done after the the last read from the
  // context struct, because it is allocated on the stack, and an exception
  // could clobber the de-allocated portion of the stack after sp has been
  // restored.
  ldr    x16,     [x0, #0x0F8]
  ldp    x0, x1,  [x0, #0x000]  // restore x0,x1
  mov    sp,x16                 // restore sp
  ret    x30                    // jump to pc

#elif defined(__arm__) && !defined(__APPLE__)

#if !defined(__ARM_ARCH_ISA_ARM)
#if (__ARM_ARCH_ISA_THUMB == 2)
  .syntax unified
#endif
  .thumb
#endif

@
@ void libunwind::Registers_arm::restoreCoreAndJumpTo()
@
@ On entry:
@  thread_state pointer is in r0
@
  .p2align 2
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind13Registers_arm20restoreCoreAndJumpToEv)
#if !defined(__ARM_ARCH_ISA_ARM) && __ARM_ARCH_ISA_THUMB == 1
  @ r8-r11: ldm into r1-r4, then mov to r8-r11
  adds r0, #0x20
  ldm r0!, {r1-r4}
  subs r0, #0x30
  mov r8, r1
  mov r9, r2
  mov r10, r3
  mov r11, r4
  @ r12 does not need loading, it it the intra-procedure-call scratch register
  ldr r2, [r0, #0x34]
  ldr r3, [r0, #0x3c]
  mov sp, r2
  mov lr, r3         @ restore pc into lr
  ldm r0, {r0-r7}
#else
  @ Use lr as base so that r0 can be restored.
  mov lr, r0
  @ 32bit thumb-2 restrictions for ldm:
  @ . the sp (r13) cannot be in the list
  @ . the pc (r15) and lr (r14) cannot both be in the list in an LDM instruction
  ldm lr, {r0-r12}
  ldr sp, [lr, #52]
  ldr lr, [lr, #60]  @ restore pc into lr
#endif
  JMP(lr)

@
@ static void libunwind::Registers_arm::restoreVFPWithFLDMD(unw_fpreg_t* values)
@
@ On entry:
@  values pointer is in r0
@
  .p2align 2
#if defined(__ELF__)
  .fpu vfpv3-d16
#endif
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind13Registers_arm19restoreVFPWithFLDMDEPv)
  @ VFP and iwMMX instructions are only available when compiling with the flags
  @ that enable them. We do not want to do that in the library (because we do not
  @ want the compiler to generate instructions that access those) but this is
  @ only accessed if the personality routine needs these registers. Use of
  @ these registers implies they are, actually, available on the target, so
  @ it's ok to execute.
  @ So, generate the instruction using the corresponding coprocessor mnemonic.
  vldmia r0, {d0-d15}
  JMP(lr)

@
@ static void libunwind::Registers_arm::restoreVFPWithFLDMX(unw_fpreg_t* values)
@
@ On entry:
@  values pointer is in r0
@
  .p2align 2
#if defined(__ELF__)
  .fpu vfpv3-d16
#endif
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind13Registers_arm19restoreVFPWithFLDMXEPv)
  vldmia r0, {d0-d15} @ fldmiax is deprecated in ARMv7+ and now behaves like vldmia
  JMP(lr)

@
@ static void libunwind::Registers_arm::restoreVFPv3(unw_fpreg_t* values)
@
@ On entry:
@  values pointer is in r0
@
  .p2align 2
#if defined(__ELF__)
  .fpu vfpv3
#endif
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind13Registers_arm12restoreVFPv3EPv)
  vldmia r0, {d16-d31}
  JMP(lr)

#if defined(__ARM_WMMX)

@
@ static void libunwind::Registers_arm::restoreiWMMX(unw_fpreg_t* values)
@
@ On entry:
@  values pointer is in r0
@
  .p2align 2
#if defined(__ELF__)
  .arch armv5te
#endif
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind13Registers_arm12restoreiWMMXEPv)
  ldcl p1, cr0, [r0], #8  @ wldrd wR0, [r0], #8
  ldcl p1, cr1, [r0], #8  @ wldrd wR1, [r0], #8
  ldcl p1, cr2, [r0], #8  @ wldrd wR2, [r0], #8
  ldcl p1, cr3, [r0], #8  @ wldrd wR3, [r0], #8
  ldcl p1, cr4, [r0], #8  @ wldrd wR4, [r0], #8
  ldcl p1, cr5, [r0], #8  @ wldrd wR5, [r0], #8
  ldcl p1, cr6, [r0], #8  @ wldrd wR6, [r0], #8
  ldcl p1, cr7, [r0], #8  @ wldrd wR7, [r0], #8
  ldcl p1, cr8, [r0], #8  @ wldrd wR8, [r0], #8
  ldcl p1, cr9, [r0], #8  @ wldrd wR9, [r0], #8
  ldcl p1, cr10, [r0], #8  @ wldrd wR10, [r0], #8
  ldcl p1, cr11, [r0], #8  @ wldrd wR11, [r0], #8
  ldcl p1, cr12, [r0], #8  @ wldrd wR12, [r0], #8
  ldcl p1, cr13, [r0], #8  @ wldrd wR13, [r0], #8
  ldcl p1, cr14, [r0], #8  @ wldrd wR14, [r0], #8
  ldcl p1, cr15, [r0], #8  @ wldrd wR15, [r0], #8
  JMP(lr)

@
@ static void libunwind::Registers_arm::restoreiWMMXControl(unw_uint32_t* values)
@
@ On entry:
@  values pointer is in r0
@
  .p2align 2
#if defined(__ELF__)
  .arch armv5te
#endif
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind13Registers_arm19restoreiWMMXControlEPj)
  ldc2 p1, cr8, [r0], #4  @ wldrw wCGR0, [r0], #4
  ldc2 p1, cr9, [r0], #4  @ wldrw wCGR1, [r0], #4
  ldc2 p1, cr10, [r0], #4  @ wldrw wCGR2, [r0], #4
  ldc2 p1, cr11, [r0], #4  @ wldrw wCGR3, [r0], #4
  JMP(lr)

#endif

#elif defined(__or1k__)

DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind14Registers_or1k6jumptoEv)
#
# void libunwind::Registers_or1k::jumpto()
#
# On entry:
#  thread_state pointer is in r3
#

  # restore integral registers
  l.lwz     r0,  0(r3)
  l.lwz     r1,  4(r3)
  l.lwz     r2,  8(r3)
  # skip r3 for now
  l.lwz     r4, 16(r3)
  l.lwz     r5, 20(r3)
  l.lwz     r6, 24(r3)
  l.lwz     r7, 28(r3)
  l.lwz     r8, 32(r3)
  # skip r9
  l.lwz    r10, 40(r3)
  l.lwz    r11, 44(r3)
  l.lwz    r12, 48(r3)
  l.lwz    r13, 52(r3)
  l.lwz    r14, 56(r3)
  l.lwz    r15, 60(r3)
  l.lwz    r16, 64(r3)
  l.lwz    r17, 68(r3)
  l.lwz    r18, 72(r3)
  l.lwz    r19, 76(r3)
  l.lwz    r20, 80(r3)
  l.lwz    r21, 84(r3)
  l.lwz    r22, 88(r3)
  l.lwz    r23, 92(r3)
  l.lwz    r24, 96(r3)
  l.lwz    r25,100(r3)
  l.lwz    r26,104(r3)
  l.lwz    r27,108(r3)
  l.lwz    r28,112(r3)
  l.lwz    r29,116(r3)
  l.lwz    r30,120(r3)
  l.lwz    r31,124(r3)

  # at last, restore r3
  l.lwz    r3,  12(r3)

  # load new pc into ra
  l.lwz    r9, 128(r3)
  # jump to pc
  l.jr     r9
   l.nop

#elif defined(__hexagon__)
# On entry:
#  thread_state pointer is in r2
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind17Registers_hexagon6jumptoEv)
#
# void libunwind::Registers_hexagon::jumpto()
#
  r8 = memw(r0+#32)
  r9 = memw(r0+#36)
  r10 = memw(r0+#40)
  r11 = memw(r0+#44)

  r12 = memw(r0+#48)
  r13 = memw(r0+#52)
  r14 = memw(r0+#56)
  r15 = memw(r0+#60)

  r16 = memw(r0+#64)
  r17 = memw(r0+#68)
  r18 = memw(r0+#72)
  r19 = memw(r0+#76)

  r20 = memw(r0+#80)
  r21 = memw(r0+#84)
  r22 = memw(r0+#88)
  r23 = memw(r0+#92)

  r24 = memw(r0+#96)
  r25 = memw(r0+#100)
  r26 = memw(r0+#104)
  r27 = memw(r0+#108)

  r28 = memw(r0+#112)
  r29 = memw(r0+#116)
  r30 = memw(r0+#120)
  r31 = memw(r0+#132)

  r1 = memw(r0+#128)
  c4 = r1   // Predicate register
  r1 = memw(r0+#4)
  r0 = memw(r0)
  jumpr r31
#elif defined(__mips__) && defined(_ABIO32) && _MIPS_SIM == _ABIO32

//
// void libunwind::Registers_mips_o32::jumpto()
//
// On entry:
//  thread state pointer is in a0 ($4)
//
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind18Registers_mips_o326jumptoEv)
  .set push
  .set noat
  .set noreorder
  .set nomacro
#ifdef __mips_hard_float
#if __mips_fpr != 64
  ldc1  $f0, (4 * 36 + 8 * 0)($4)
  ldc1  $f2, (4 * 36 + 8 * 2)($4)
  ldc1  $f4, (4 * 36 + 8 * 4)($4)
  ldc1  $f6, (4 * 36 + 8 * 6)($4)
  ldc1  $f8, (4 * 36 + 8 * 8)($4)
  ldc1  $f10, (4 * 36 + 8 * 10)($4)
  ldc1  $f12, (4 * 36 + 8 * 12)($4)
  ldc1  $f14, (4 * 36 + 8 * 14)($4)
  ldc1  $f16, (4 * 36 + 8 * 16)($4)
  ldc1  $f18, (4 * 36 + 8 * 18)($4)
  ldc1  $f20, (4 * 36 + 8 * 20)($4)
  ldc1  $f22, (4 * 36 + 8 * 22)($4)
  ldc1  $f24, (4 * 36 + 8 * 24)($4)
  ldc1  $f26, (4 * 36 + 8 * 26)($4)
  ldc1  $f28, (4 * 36 + 8 * 28)($4)
  ldc1  $f30, (4 * 36 + 8 * 30)($4)
#else
  ldc1  $f0, (4 * 36 + 8 * 0)($4)
  ldc1  $f1, (4 * 36 + 8 * 1)($4)
  ldc1  $f2, (4 * 36 + 8 * 2)($4)
  ldc1  $f3, (4 * 36 + 8 * 3)($4)
  ldc1  $f4, (4 * 36 + 8 * 4)($4)
  ldc1  $f5, (4 * 36 + 8 * 5)($4)
  ldc1  $f6, (4 * 36 + 8 * 6)($4)
  ldc1  $f7, (4 * 36 + 8 * 7)($4)
  ldc1  $f8, (4 * 36 + 8 * 8)($4)
  ldc1  $f9, (4 * 36 + 8 * 9)($4)
  ldc1  $f10, (4 * 36 + 8 * 10)($4)
  ldc1  $f11, (4 * 36 + 8 * 11)($4)
  ldc1  $f12, (4 * 36 + 8 * 12)($4)
  ldc1  $f13, (4 * 36 + 8 * 13)($4)
  ldc1  $f14, (4 * 36 + 8 * 14)($4)
  ldc1  $f15, (4 * 36 + 8 * 15)($4)
  ldc1  $f16, (4 * 36 + 8 * 16)($4)
  ldc1  $f17, (4 * 36 + 8 * 17)($4)
  ldc1  $f18, (4 * 36 + 8 * 18)($4)
  ldc1  $f19, (4 * 36 + 8 * 19)($4)
  ldc1  $f20, (4 * 36 + 8 * 20)($4)
  ldc1  $f21, (4 * 36 + 8 * 21)($4)
  ldc1  $f22, (4 * 36 + 8 * 22)($4)
  ldc1  $f23, (4 * 36 + 8 * 23)($4)
  ldc1  $f24, (4 * 36 + 8 * 24)($4)
  ldc1  $f25, (4 * 36 + 8 * 25)($4)
  ldc1  $f26, (4 * 36 + 8 * 26)($4)
  ldc1  $f27, (4 * 36 + 8 * 27)($4)
  ldc1  $f28, (4 * 36 + 8 * 28)($4)
  ldc1  $f29, (4 * 36 + 8 * 29)($4)
  ldc1  $f30, (4 * 36 + 8 * 30)($4)
  ldc1  $f31, (4 * 36 + 8 * 31)($4)
#endif
#endif
  // restore hi and lo
  lw    $8, (4 * 33)($4)
  mthi  $8
  lw    $8, (4 * 34)($4)
  mtlo  $8
  // r0 is zero
  lw    $1, (4 * 1)($4)
  lw    $2, (4 * 2)($4)
  lw    $3, (4 * 3)($4)
  // skip a0 for now
  lw    $5, (4 * 5)($4)
  lw    $6, (4 * 6)($4)
  lw    $7, (4 * 7)($4)
  lw    $8, (4 * 8)($4)
  lw    $9, (4 * 9)($4)
  lw    $10, (4 * 10)($4)
  lw    $11, (4 * 11)($4)
  lw    $12, (4 * 12)($4)
  lw    $13, (4 * 13)($4)
  lw    $14, (4 * 14)($4)
  lw    $15, (4 * 15)($4)
  lw    $16, (4 * 16)($4)
  lw    $17, (4 * 17)($4)
  lw    $18, (4 * 18)($4)
  lw    $19, (4 * 19)($4)
  lw    $20, (4 * 20)($4)
  lw    $21, (4 * 21)($4)
  lw    $22, (4 * 22)($4)
  lw    $23, (4 * 23)($4)
  lw    $24, (4 * 24)($4)
  lw    $25, (4 * 25)($4)
  lw    $26, (4 * 26)($4)
  lw    $27, (4 * 27)($4)
  lw    $28, (4 * 28)($4)
  lw    $29, (4 * 29)($4)
  lw    $30, (4 * 30)($4)
  // load new pc into ra
  lw    $31, (4 * 32)($4)
  // jump to ra, load a0 in the delay slot
  jr    $31
  lw    $4, (4 * 4)($4)
  .set pop

#elif defined(__mips64)

//
// void libunwind::Registers_mips_newabi::jumpto()
//
// On entry:
//  thread state pointer is in a0 ($4)
//
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind21Registers_mips_newabi6jumptoEv)
  .set push
  .set noat
  .set noreorder
  .set nomacro
#ifdef __mips_hard_float
  ldc1  $f0, (8 * 35)($4)
  ldc1  $f1, (8 * 36)($4)
  ldc1  $f2, (8 * 37)($4)
  ldc1  $f3, (8 * 38)($4)
  ldc1  $f4, (8 * 39)($4)
  ldc1  $f5, (8 * 40)($4)
  ldc1  $f6, (8 * 41)($4)
  ldc1  $f7, (8 * 42)($4)
  ldc1  $f8, (8 * 43)($4)
  ldc1  $f9, (8 * 44)($4)
  ldc1  $f10, (8 * 45)($4)
  ldc1  $f11, (8 * 46)($4)
  ldc1  $f12, (8 * 47)($4)
  ldc1  $f13, (8 * 48)($4)
  ldc1  $f14, (8 * 49)($4)
  ldc1  $f15, (8 * 50)($4)
  ldc1  $f16, (8 * 51)($4)
  ldc1  $f17, (8 * 52)($4)
  ldc1  $f18, (8 * 53)($4)
  ldc1  $f19, (8 * 54)($4)
  ldc1  $f20, (8 * 55)($4)
  ldc1  $f21, (8 * 56)($4)
  ldc1  $f22, (8 * 57)($4)
  ldc1  $f23, (8 * 58)($4)
  ldc1  $f24, (8 * 59)($4)
  ldc1  $f25, (8 * 60)($4)
  ldc1  $f26, (8 * 61)($4)
  ldc1  $f27, (8 * 62)($4)
  ldc1  $f28, (8 * 63)($4)
  ldc1  $f29, (8 * 64)($4)
  ldc1  $f30, (8 * 65)($4)
  ldc1  $f31, (8 * 66)($4)
#endif
  // restore hi and lo
  ld    $8, (8 * 33)($4)
  mthi  $8
  ld    $8, (8 * 34)($4)
  mtlo  $8
  // r0 is zero
  ld    $1, (8 * 1)($4)
  ld    $2, (8 * 2)($4)
  ld    $3, (8 * 3)($4)
  // skip a0 for now
  ld    $5, (8 * 5)($4)
  ld    $6, (8 * 6)($4)
  ld    $7, (8 * 7)($4)
  ld    $8, (8 * 8)($4)
  ld    $9, (8 * 9)($4)
  ld    $10, (8 * 10)($4)
  ld    $11, (8 * 11)($4)
  ld    $12, (8 * 12)($4)
  ld    $13, (8 * 13)($4)
  ld    $14, (8 * 14)($4)
  ld    $15, (8 * 15)($4)
  ld    $16, (8 * 16)($4)
  ld    $17, (8 * 17)($4)
  ld    $18, (8 * 18)($4)
  ld    $19, (8 * 19)($4)
  ld    $20, (8 * 20)($4)
  ld    $21, (8 * 21)($4)
  ld    $22, (8 * 22)($4)
  ld    $23, (8 * 23)($4)
  ld    $24, (8 * 24)($4)
  ld    $25, (8 * 25)($4)
  ld    $26, (8 * 26)($4)
  ld    $27, (8 * 27)($4)
  ld    $28, (8 * 28)($4)
  ld    $29, (8 * 29)($4)
  ld    $30, (8 * 30)($4)
  // load new pc into ra
  ld    $31, (8 * 32)($4)
  // jump to ra, load a0 in the delay slot
  jr    $31
  ld    $4, (8 * 4)($4)
  .set pop

#elif defined(__sparc__)

//
// void libunwind::Registers_sparc_o32::jumpto()
//
// On entry:
//  thread_state pointer is in o0
//
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind15Registers_sparc6jumptoEv)
  ta 3
  ldd [%o0 + 64],  %l0
  ldd [%o0 + 72],  %l2
  ldd [%o0 + 80],  %l4
  ldd [%o0 + 88],  %l6
  ldd [%o0 + 96],  %i0
  ldd [%o0 + 104], %i2
  ldd [%o0 + 112], %i4
  ldd [%o0 + 120], %i6
  ld  [%o0 + 60],  %o7
  jmp %o7
   nop

#elif defined(__riscv)

//
// void libunwind::Registers_riscv::jumpto()
//
// On entry:
//  thread_state pointer is in a0
//
  .p2align 2
DEFINE_LIBUNWIND_FUNCTION(_ZN9libunwind15Registers_riscv6jumptoEv)
# if defined(__riscv_flen)
  FLOAD    f0, (RISCV_FOFFSET + RISCV_FSIZE * 0)(a0)
  FLOAD    f1, (RISCV_FOFFSET + RISCV_FSIZE * 1)(a0)
  FLOAD    f2, (RISCV_FOFFSET + RISCV_FSIZE * 2)(a0)
  FLOAD    f3, (RISCV_FOFFSET + RISCV_FSIZE * 3)(a0)
  FLOAD    f4, (RISCV_FOFFSET + RISCV_FSIZE * 4)(a0)
  FLOAD    f5, (RISCV_FOFFSET + RISCV_FSIZE * 5)(a0)
  FLOAD    f6, (RISCV_FOFFSET + RISCV_FSIZE * 6)(a0)
  FLOAD    f7, (RISCV_FOFFSET + RISCV_FSIZE * 7)(a0)
  FLOAD    f8, (RISCV_FOFFSET + RISCV_FSIZE * 8)(a0)
  FLOAD    f9, (RISCV_FOFFSET + RISCV_FSIZE * 9)(a0)
  FLOAD    f10, (RISCV_FOFFSET + RISCV_FSIZE * 10)(a0)
  FLOAD    f11, (RISCV_FOFFSET + RISCV_FSIZE * 11)(a0)
  FLOAD    f12, (RISCV_FOFFSET + RISCV_FSIZE * 12)(a0)
  FLOAD    f13, (RISCV_FOFFSET + RISCV_FSIZE * 13)(a0)
  FLOAD    f14, (RISCV_FOFFSET + RISCV_FSIZE * 14)(a0)
  FLOAD    f15, (RISCV_FOFFSET + RISCV_FSIZE * 15)(a0)
  FLOAD    f16, (RISCV_FOFFSET + RISCV_FSIZE * 16)(a0)
  FLOAD    f17, (RISCV_FOFFSET + RISCV_FSIZE * 17)(a0)
  FLOAD    f18, (RISCV_FOFFSET + RISCV_FSIZE * 18)(a0)
  FLOAD    f19, (RISCV_FOFFSET + RISCV_FSIZE * 19)(a0)
  FLOAD    f20, (RISCV_FOFFSET + RISCV_FSIZE * 20)(a0)
  FLOAD    f21, (RISCV_FOFFSET + RISCV_FSIZE * 21)(a0)
  FLOAD    f22, (RISCV_FOFFSET + RISCV_FSIZE * 22)(a0)
  FLOAD    f23, (RISCV_FOFFSET + RISCV_FSIZE * 23)(a0)
  FLOAD    f24, (RISCV_FOFFSET + RISCV_FSIZE * 24)(a0)
  FLOAD    f25, (RISCV_FOFFSET + RISCV_FSIZE * 25)(a0)
  FLOAD    f26, (RISCV_FOFFSET + RISCV_FSIZE * 26)(a0)
  FLOAD    f27, (RISCV_FOFFSET + RISCV_FSIZE * 27)(a0)
  FLOAD    f28, (RISCV_FOFFSET + RISCV_FSIZE * 28)(a0)
  FLOAD    f29, (RISCV_FOFFSET + RISCV_FSIZE * 29)(a0)
  FLOAD    f30, (RISCV_FOFFSET + RISCV_FSIZE * 30)(a0)
  FLOAD    f31, (RISCV_FOFFSET + RISCV_FSIZE * 31)(a0)
# endif

  // x0 is zero
  ILOAD    x1, (RISCV_ISIZE * 0)(a0) // restore pc into ra
  ILOAD    x2, (RISCV_ISIZE * 2)(a0)
  ILOAD    x3, (RISCV_ISIZE * 3)(a0)
  ILOAD    x4, (RISCV_ISIZE * 4)(a0)
  ILOAD    x5, (RISCV_ISIZE * 5)(a0)
  ILOAD    x6, (RISCV_ISIZE * 6)(a0)
  ILOAD    x7, (RISCV_ISIZE * 7)(a0)
  ILOAD    x8, (RISCV_ISIZE * 8)(a0)
  ILOAD    x9, (RISCV_ISIZE * 9)(a0)
  // skip a0 for now
  ILOAD    x11, (RISCV_ISIZE * 11)(a0)
  ILOAD    x12, (RISCV_ISIZE * 12)(a0)
  ILOAD    x13, (RISCV_ISIZE * 13)(a0)
  ILOAD    x14, (RISCV_ISIZE * 14)(a0)
  ILOAD    x15, (RISCV_ISIZE * 15)(a0)
  ILOAD    x16, (RISCV_ISIZE * 16)(a0)
  ILOAD    x17, (RISCV_ISIZE * 17)(a0)
  ILOAD    x18, (RISCV_ISIZE * 18)(a0)
  ILOAD    x19, (RISCV_ISIZE * 19)(a0)
  ILOAD    x20, (RISCV_ISIZE * 20)(a0)
  ILOAD    x21, (RISCV_ISIZE * 21)(a0)
  ILOAD    x22, (RISCV_ISIZE * 22)(a0)
  ILOAD    x23, (RISCV_ISIZE * 23)(a0)
  ILOAD    x24, (RISCV_ISIZE * 24)(a0)
  ILOAD    x25, (RISCV_ISIZE * 25)(a0)
  ILOAD    x26, (RISCV_ISIZE * 26)(a0)
  ILOAD    x27, (RISCV_ISIZE * 27)(a0)
  ILOAD    x28, (RISCV_ISIZE * 28)(a0)
  ILOAD    x29, (RISCV_ISIZE * 29)(a0)
  ILOAD    x30, (RISCV_ISIZE * 30)(a0)
  ILOAD    x31, (RISCV_ISIZE * 31)(a0)
  ILOAD    x10, (RISCV_ISIZE * 10)(a0)   // restore a0

  ret                       // jump to ra

#endif

#endif /* !defined(__USING_SJLJ_EXCEPTIONS__) */

NO_EXEC_STACK_DIRECTIVE

