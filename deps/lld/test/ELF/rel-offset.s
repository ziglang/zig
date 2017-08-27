// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t -shared
// RUN: llvm-readobj -r  %t | FileCheck %s

        .section        .data.foo,"aw",@progbits
        .quad   foo

        .section        .data.zed,"aw",@progbits
        .quad   foo

// CHECK:      Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:   0x1000 R_X86_64_64 foo 0x0
// CHECK-NEXT:   0x1008 R_X86_64_64 foo 0x0
// CHECK-NEXT: }
