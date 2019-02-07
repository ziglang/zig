// REQUIRES: arm
// RUN: llvm-mc -triple armv7-unknown-gnu -arm-add-build-attributes -filetype=obj -o %t %s
// RUN: ld.lld %t %S/Inputs/arm-long-thunk-converge.lds -o %t2
// RUN: llvm-objdump -d -start-address=0x00000000 -stop-address=0x00000010 -triple=armv7a-linux-gnueabihf %t2 | FileCheck --check-prefix=CHECK1 %s
// RUN: llvm-objdump -d -start-address=0x02000000 -stop-address=0x02000010 -triple=armv7a-linux-gnueabihf %t2 | FileCheck --check-prefix=CHECK2 %s
// RUN: rm -f %t2

// CHECK1: __ARMv7ABSLongThunk_bar:
// CHECK1-NEXT:        0:       0c c0 00 e3     movw    r12, #12
// CHECK1-NEXT:        4:       00 c2 40 e3     movt    r12, #512
// CHECK1-NEXT:        8:       1c ff 2f e1     bx      r12
// CHECK1: foo:
// CHECK1-NEXT:        c:       fb ff ff eb     bl      #-20

.section .foo,"ax",%progbits,unique,1
foo:
bl bar

// CHECK2: __ARMv7ABSLongThunk_foo:
// CHECK2-NEXT:  2000000:       0c c0 00 e3     movw    r12, #12
// CHECK2-NEXT:  2000004:       00 c0 40 e3     movt    r12, #0
// CHECK2-NEXT:  2000008:       1c ff 2f e1     bx      r12
// CHECK2: bar:
// CHECK2-NEXT:  200000c:       fb ff ff eb     bl      #-20 <__ARMv7ABSLongThunk_foo>

.section .bar,"ax",%progbits,unique,1
bar:
bl foo
.zero 0x1000000
