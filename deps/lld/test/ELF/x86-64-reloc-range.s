// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -triple x86_64-pc-linux -filetype=obj
// RUN: not ld.lld %t.o -o /dev/null -shared 2>&1 | FileCheck %s

// CHECK: {{.*}}:(.text+0x3): relocation R_X86_64_PC32 out of range: 2147483648 is not in [-2147483648, 2147483647]
// CHECK-NOT: relocation

        lea     foo(%rip), %rax
        lea     foo(%rip), %rax

        .hidden foo
        .bss
        .zero 0x7fffe007
foo:
