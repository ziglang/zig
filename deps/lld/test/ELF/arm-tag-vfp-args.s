// REQUIRES:arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-vfp-arg-base.s -o %tbase.o
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-vfp-arg-vfp.s -o %tvfp.o
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-vfp-arg-toolchain.s -o %ttoolchain.o
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-vfp-arg-compat.s -o %tcompat.o
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o

// The default for this file is 0 (Base AAPCS)
// RUN: ld.lld %t.o -o %tdefault
// RUN: llvm-readobj -file-headers %tdefault | FileCheck -check-prefix=CHECK-BASE %s

// Expect explicit Base AAPCS.
// RUN: ld.lld %t.o %tbase.o -o %tbase
// RUN: llvm-readobj -file-headers %tbase | FileCheck -check-prefix=CHECK-BASE %s

// Expect explicit Base AAPCS when linking Base and Compatible.
// RUN: ld.lld %t.o %tbase.o %tcompat.o -o %tbasecompat
// RUN: llvm-readobj -file-headers %tbasecompat | FileCheck -check-prefix=CHECK-BASE %s

// CHECK-BASE:   Flags [ (0x5000200)
// CHECK-BASE-NEXT:     0x200
// CHECK-BASE-NEXT:     0x1000000
// CHECK-BASE-NEXT:     0x4000000
// CHECK-BASE-NEXT:   ]

// Expect Hard float VFP AAPCS
// RUN: ld.lld %t.o %tvfp.o -o %tvfp
// RUN: llvm-readobj -file-headers %tvfp | FileCheck -check-prefix=CHECK-VFP %s

// Expect Hard float VFP AAPCS when linking VFP and Compatible
// RUN: ld.lld %t.o %tvfp.o %tcompat.o -o %tvfpcompat
// RUN: llvm-readobj -file-headers %tvfpcompat | FileCheck -check-prefix=CHECK-VFP %s

// CHECK-VFP:   Flags [ (0x5000400)
// CHECK-VFP-NEXT:     0x400
// CHECK-VFP-NEXT:     0x1000000
// CHECK-VFP-NEXT:     0x4000000
// CHECK-VFP-NEXT:   ]

// Expect Toolchain specifc to not use either Base or VFP AAPCS
// RUN: ld.lld %t.o %ttoolchain.o -o %ttoolchain
// RUN: llvm-readobj -file-headers %ttoolchain | FileCheck -check-prefix=CHECK-TOOLCHAIN %s

// Expect Toolchain and Compatible to have same affect as Toolchain.
// RUN: ld.lld %t.o %ttoolchain.o %tcompat.o -o %ttoolchaincompat
// RUN: llvm-readobj -file-headers %ttoolchaincompat | FileCheck -check-prefix=CHECK-TOOLCHAIN %s

// CHECK-TOOLCHAIN:   Flags [ (0x5000000)
// CHECK-TOOLCHAIN-NEXT:     0x1000000
// CHECK-TOOLCHAIN-NEXT:     0x4000000
// CHECK-TOOLCHAIN-NEXT:   ]

        .arch armv7-a
        .eabi_attribute 20, 1
        .eabi_attribute 21, 1
        .eabi_attribute 23, 3
        .eabi_attribute 24, 1
        .eabi_attribute 25, 1
        .eabi_attribute 26, 2
        .eabi_attribute 30, 6
        .eabi_attribute 34, 1
        .eabi_attribute 18, 4
        // We do not specify Tag_ABI_VFP_args (.eabi_attribute 28) in this file.
        // When omitted the value of the tag defaults to 0, however if there
        // are other files with explicit Tag_ABI_VFP_args we use that in
        // preference.


        .syntax unified
        .globl _start
        .type _start, %function
_start:  bx lr
