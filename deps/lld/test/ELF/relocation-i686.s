// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld --hash-style=sysv %t %t2.so -o %t2
// RUN: llvm-readobj -s %t2 | FileCheck --check-prefix=ADDR %s
// RUN: llvm-objdump -d %t2 | FileCheck %s

.global _start
_start:

.section       .R_386_32,"ax",@progbits
.global R_386_32
R_386_32:
  movl $R_386_32 + 1, %edx


.section       .R_386_PC32,"ax",@progbits,unique,1
.global R_386_PC32
R_386_PC32:
  call R_386_PC32_2

.section       .R_386_PC32,"ax",@progbits,unique,2
.zero 4
R_386_PC32_2:
  nop

// CHECK: Disassembly of section .R_386_32:
// CHECK-NEXT: R_386_32:
// CHECK-NEXT:  401000: {{.*}} movl $4198401, %edx

// CHECK: Disassembly of section .R_386_PC32:
// CHECK-NEXT: R_386_PC32:
// CHECK-NEXT:   401005:  e8 04 00 00 00  calll 4

// CHECK:      R_386_PC32_2:
// CHECK-NEXT:   40100e:  90  nop

// Create a .got
movl bar@GOT, %eax

// ADDR:      Name: .plt
// ADDR-NEXT: Type: SHT_PROGBITS
// ADDR-NEXT: Flags [
// ADDR-NEXT:   SHF_ALLOC
// ADDR-NEXT:   SHF_EXECINSTR
// ADDR-NEXT: ]
// ADDR-NEXT: Address: 0x401040
// ADDR-NEXT: Offset: 0x1040
// ADDR-NEXT: Size: 32

// ADDR:      Name: .got (
// ADDR-NEXT: Type: SHT_PROGBITS
// ADDR-NEXT: Flags [
// ADDR-NEXT:   SHF_ALLOC
// ADDR-NEXT:   SHF_WRITE
// ADDR-NEXT: ]
// ADDR-NEXT: Address: 0x403078
// ADDR-NEXT: Offset:
// ADDR-NEXT: Size: 8

.section .R_386_GOTPC,"ax",@progbits
R_386_GOTPC:
 movl $_GLOBAL_OFFSET_TABLE_, %eax

// 0x402078 + 8 - 0x401014 = 4204

// CHECK:      Disassembly of section .R_386_GOTPC:
// CHECK-NEXT: R_386_GOTPC:
// CHECK-NEXT:   401014:  {{.*}} movl  $8300, %eax

.section .dynamic_reloc, "ax",@progbits
 call bar
// addr(.plt) + 16 - (0x401019 + 5) = 50
// CHECK:      Disassembly of section .dynamic_reloc:
// CHECK-NEXT: .dynamic_reloc:
// CHECK-NEXT:   401019:  e8 32 00 00 00 calll 50

.section .R_386_GOT32,"ax",@progbits
.global R_386_GOT32
R_386_GOT32:
 movl bar@GOT, %eax
 movl zed@GOT, %eax
 movl bar+8@GOT, %eax
 movl zed+4@GOT, %eax

// 4294967288 = 0xFFFFFFF8 = got[0](0x402070) - .got(0x402070) - sizeof(.got)(8)
// 4294967292 = 0xFFFFFFFC = got[1](0x402074) - .got(0x402070) - sizeof(.got)(8)
// 0xFFFFFFF8 + 8 = 0
// 0xFFFFFFFC + 4 = 0
// CHECK:      Disassembly of section .R_386_GOT32:
// CHECK-NEXT: R_386_GOT32:
// CHECK-NEXT: 40101e: a1 f8 ff ff ff movl 4294967288, %eax
// CHECK-NEXT: 401023: a1 fc ff ff ff movl 4294967292, %eax
// CHECK-NEXT: 401028: a1 00 00 00 00 movl 0, %eax
// CHECK-NEXT: 40102d: a1 00 00 00 00 movl 0, %eax
