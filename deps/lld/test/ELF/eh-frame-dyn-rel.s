// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: not ld.lld %t.o %t.o -o %t -shared 2>&1 | FileCheck %s

// CHECK: can't create dynamic relocation R_X86_64_64 against symbol: foo
// CHECK: >>> defined in {{.*}}.o
// CHECK: >>> referenced by {{.*}}.o:(.eh_frame+0x12)

.section bar,"axG",@progbits,foo,comdat
.cfi_startproc
.cfi_personality 0x8c, foo
.cfi_endproc
