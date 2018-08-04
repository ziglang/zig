// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld --hash-style=sysv %t.o %t2.so -o %t
// RUN: llvm-readobj -s -r -section-data %t | FileCheck %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s

        .globl _start
_start:
	call bar@gotpcrel
	call foo@gotpcrel

        .global foo
foo:
        nop

// 0x2020B0 - 0x201000 - 5 =  4251
// 0x2020B8 - 0x201005 - 5 =  4254
// DISASM:      _start:
// DISASM-NEXT:   201000: {{.*}} callq 4267
// DISASM-NEXT:   201005: {{.*}} callq 4270

// DISASM:      foo:
// DISASM-NEXT:   20100a: {{.*}} nop

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
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// 0x20200a in little endian
// CHECK-NEXT:   0000:  00000000 00000000 0A102000 00000000
// CHECK-NEXT: )

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     0x2020B0 R_X86_64_GLOB_DAT bar 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]
