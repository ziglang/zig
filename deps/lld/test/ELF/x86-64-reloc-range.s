// RUN: llvm-mc %s -o %t.o -triple x86_64-pc-linux -filetype=obj
// RUN: not ld.lld %t.o -o %t.so -shared 2>&1 | FileCheck %s

// CHECK: {{.*}}:(.text+0x3): relocation R_X86_64_PC32 out of range
// CHECK-NOT: relocation

        lea     foo(%rip), %rax
        lea     foo(%rip), %rax

        .hidden foo
        .bss
        .zero 0x7fffe007
foo:
