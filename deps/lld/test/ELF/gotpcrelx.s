// RUN: llvm-mc -filetype=obj -relax-relocations -triple x86_64-pc-linux-gnu \
// RUN: %s -o %t.o
// RUN: llvm-readobj -r %t.o | FileCheck --check-prefix=RELS %s
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -s -r %t.so | FileCheck %s

movq foo@GOTPCREL(%rip), %rax
movq bar@GOTPCREL(%rip), %rax

// RELS: Relocations [
// RELS-NEXT:   Section ({{.*}}) .rela.text {
// RELS-NEXT:     R_X86_64_REX_GOTPCRELX foo 0xFFFFFFFFFFFFFFFC
// RELS-NEXT:     R_X86_64_REX_GOTPCRELX bar 0xFFFFFFFFFFFFFFFC
// RELS-NEXT:   }
// RELS-NEXT: ]

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x2090

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     0x2098 R_X86_64_GLOB_DAT bar 0x0
// CHECK-NEXT:     0x2090 R_X86_64_GLOB_DAT foo 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]
