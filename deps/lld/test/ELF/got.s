// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld --hash-style=sysv %t.o %t2.so -o %t
// RUN: llvm-readobj -s -r %t | FileCheck %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x2020B0
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 16
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 8

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     0x2020B0 R_X86_64_GLOB_DAT bar 0x0
// CHECK-NEXT:     0x2020B8 R_X86_64_GLOB_DAT zed 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]


// Unfortunately FileCheck can't do math, so we have to check for explicit
// values:
//  0x2020B0 - (0x201000 + 2) - 4 = 4266
//  0x2020B0 - (0x201006 + 2) - 4 = 4260
//  0x2020A8 - (0x20100c + 2) - 4 = 4262

// DISASM:      _start:
// DISASM-NEXT:  201000:  {{.*}}  jmpq  *4266(%rip)
// DISASM-NEXT:  201006:  {{.*}}  jmpq  *4260(%rip)
// DISASM-NEXT:  20100c:  {{.*}}  jmpq  *4262(%rip)

.global _start
_start:
  jmp *bar@GOTPCREL(%rip)
  jmp *bar@GOTPCREL(%rip)
  jmp *zed@GOTPCREL(%rip)
