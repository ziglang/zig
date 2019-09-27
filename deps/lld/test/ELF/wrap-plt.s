// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t

// RUN: ld.lld -o %t2 %t -wrap foo -shared
// RUN: llvm-readobj -S -r %t2 | FileCheck %s
// RUN: llvm-objdump -d %t2 | FileCheck --check-prefix=DISASM %s

// CHECK:      Name: .plt
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_EXECINSTR
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x1020
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 48
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 16

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.plt {
// CHECK-NEXT:     0x3018 R_X86_64_JUMP_SLOT __wrap_foo 0x0
// CHECK-NEXT:     0x3020 R_X86_64_JUMP_SLOT _start 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// DISASM:      _start:
// DISASM-NEXT: jmp    41
// DISASM-NEXT: jmp    36
// DISASM-NEXT: jmp    47

.global foo
foo:
  nop

.global __wrap_foo
__wrap_foo:
  nop

.global _start
_start:
  jmp foo@plt
  jmp __wrap_foo@plt
  jmp _start@plt
