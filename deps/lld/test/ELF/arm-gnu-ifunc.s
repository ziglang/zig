// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld -static %t.o -o %tout
// RUN: llvm-objdump -triple armv7a-none-linux-gnueabi -d %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-readobj -r -symbols -sections %tout | FileCheck %s
// REQUIRES: arm
 .syntax unified
 .text
 .type foo STT_GNU_IFUNC
 .globl foo
foo:
 bx lr

 .type bar STT_GNU_IFUNC
 .globl bar
bar:
 bx lr

 .globl _start
_start:
 bl foo
 bl bar
 movw r0,:lower16:__rel_iplt_start
 movt r0,:upper16:__rel_iplt_start
 movw r0,:lower16:__rel_iplt_end
 movt r0,:upper16:__rel_iplt_end

// CHECK: Sections [
// CHECK:   Section {
// CHECK:        Section {
// CHECK:          Name: .rel.dyn
// CHECK-NEXT:     Type: SHT_REL
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x100F4
// CHECK-NEXT:     Offset: 0xF4
// CHECK-NEXT:     Size: 16
// CHECK:          Name: .plt
// CHECK-NEXT:     Type: SHT_PROGBITS
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:       SHF_EXECINSTR
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x11020
// CHECK-NEXT:     Offset: 0x1020
// CHECK-NEXT:     Size: 32
// CHECK:          Name: .got
// CHECK-NEXT:     Type: SHT_PROGBITS
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:       SHF_WRITE
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x12000
// CHECK-NEXT:     Offset: 0x2000
// CHECK-NEXT:     Size: 8
// CHECK:      Relocations [
// CHECK-NEXT:   Section (1) .rel.dyn {
// CHECK-NEXT:     0x12000 R_ARM_IRELATIVE
// CHECK-NEXT:     0x12004 R_ARM_IRELATIVE
// CHECK-NEXT:   }
// CHECK-NEXT: ]
// CHECK:        Symbol {
// CHECK:          Name: __rel_iplt_end
// CHECK-NEXT:     Value: 0x10104
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other [
// CHECK-NEXT:       STV_HIDDEN
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .rel.dyn
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: __rel_iplt_start
// CHECK-NEXT:     Value: 0x100F4
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other [
// CHECK-NEXT:       STV_HIDDEN
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .rel.dyn
// CHECK-NEXT:   }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: _start
// CHECK-NEXT:    Value: 0x11008
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Global
// CHECK-NEXT:    Type: None
// CHECK-NEXT:    Other:
// CHECK-NEXT:    Section: .text
// CHECK-NEXT:  }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: bar
// CHECK-NEXT:    Value: 0x11004
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Global
// CHECK-NEXT:    Type: GNU_IFunc
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .text
// CHECK-NEXT:  }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: foo
// CHECK-NEXT:    Value: 0x11000
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Global
// CHECK-NEXT:    Type: GNU_IFunc
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .text
// CHECK-NEXT:  }

// DISASM: Disassembly of section .text:
// DISASM-NEXT: foo:
// DISASM-NEXT:    11000:	1e ff 2f e1 	bx	lr
// DISASM:      bar:
// DISASM-NEXT:    11004:	1e ff 2f e1 	bx	lr
// DISASM:       _start:
// DISASM-NEXT:    11008:	04 00 00 eb 	bl	#16
// DISASM-NEXT:    1100c:	07 00 00 eb 	bl	#28
// 1 * 65536 + 244 = 0x100f4 __rel_iplt_start
// DISASM-NEXT:    11010:	f4 00 00 e3 	movw	r0, #244
// DISASM-NEXT:    11014:	01 00 40 e3 	movt	r0, #1
// 1 * 65536 + 260 = 0x10104 __rel_iplt_end
// DISASM-NEXT:    11018:	04 01 00 e3 	movw	r0, #260
// DISASM-NEXT:    1101c:	01 00 40 e3 	movt	r0, #1
// DISASM-NEXT: Disassembly of section .plt:
// DISASM: $a:
// DISASM-NEXT:    11020:       04 c0 9f e5     ldr     r12, [pc, #4]
// DISASM-NEXT:    11024:       0f c0 8c e0     add     r12, r12, pc
// 11024 + 8 + fd4 = 0x12000
// DISASM-NEXT:    11028:       00 f0 9c e5     ldr     pc, [r12]
// DISASM: $d:
// DISASM-NEXT:    1102c:       d4 0f 00 00     .word   0x00000fd4
// DISASM: $a:
// DISASM-NEXT:    11030:       04 c0 9f e5     ldr     r12, [pc, #4]
// DISASM-NEXT:    11034:       0f c0 8c e0     add     r12, r12, pc
// 11034 + 8 + fc8 = 0x12004        
// DISASM-NEXT:    11038:       00 f0 9c e5     ldr     pc, [r12]
// DISASM: $d:
// DISASM-NEXT:    1103c:       c8 0f 00 00     .word   0x00000fc8
