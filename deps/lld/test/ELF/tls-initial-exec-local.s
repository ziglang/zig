// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv -shared %t.o -o %t
// RUN: llvm-readobj -r -S %t | FileCheck %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC (0x2)
// CHECK-NEXT:   SHF_WRITE (0x1)
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x20A0

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     0x20A0 R_X86_64_TPOFF64 - 0x0
// CHECK-NEXT:     0x20A8 R_X86_64_TPOFF64 - 0x4
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// 0x1007 + 4249 = 0x20A0
// 0x100e + 4250 = 0x20A8
// DISASM:      Disassembly of section .text:
// DISASM-EMPTY:
// DISASM-NEXT: .text:
// DISASM-NEXT:  1000: {{.*}} addq 4249(%rip), %rax
// DISASM-NEXT:  1007: {{.*}} addq 4250(%rip), %rax

        addq    foo@GOTTPOFF(%rip), %rax
        addq    bar@GOTTPOFF(%rip), %rax

        .section        .tbss,"awT",@nobits
foo:
        .long 0
bar:
        .long 0
