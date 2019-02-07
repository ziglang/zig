// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld %t.o %t2.so -o %t
// RUN: llvm-readobj -s -r %t | FileCheck %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s
// RUN: ld.lld -shared %t.o %t2.so -o %t
// RUN: llvm-readobj -s -r %t | FileCheck --check-prefix=CHECKSHARED %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASMSHARED %s
// RUN: ld.lld -pie %t.o %t2.so -o %t
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASMPIE %s

// CHECK:      Name: .plt
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_EXECINSTR
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x401020
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 48
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 16

// CHECK:      Name: .got.plt
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x402000
// CHECK-NEXT: Offset: 0x2000
// CHECK-NEXT: Size: 20
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 4
// CHECK-NEXT: EntrySize: 0

// 0x12000 + got.plt.reserved(12) = 0x1200C
// 0x12000 + got.plt.reserved(12) + 4 = 0x12010
// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rel.plt {
// CHECK-NEXT:     0x40200C R_386_JUMP_SLOT bar 0x0
// CHECK-NEXT:     0x402010 R_386_JUMP_SLOT zed 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// Unfortunately FileCheck can't do math, so we have to check for explicit
// values:

// 16 is the size of PLT[0]
// (0x401010 + 16) - (0x401000 + 1) - 4 = 27
// (0x401010 + 16) - (0x401005 + 1) - 4 = 22
// (0x401020 + 16) - (0x40100a + 1) - 4 = 33

// DISASM:       local:
// DISASM-NEXT:  401000: {{.*}}
// DISASM-NEXT:  401002: {{.*}}
// DISASM:       _start:
// 0x401013 + 5 - 24 = 0x401000
// DISASM-NEXT: 401004: e9 27 00 00 00 jmp 39
// DISASM-NEXT: 401009: e9 22 00 00 00 jmp 34
// DISASM-NEXT: 40100e: e9 2d 00 00 00 jmp 45
// DISASM-NEXT: 401013: e9 e8 ff ff ff jmp -24

// 0x401010 - 0x40102b - 5 = -32
// 0x401010 - 0x40103b - 5 = -48
// 4202500 = 0x402004 = .got.plt (0x402000) + 4
// 4202504 = 0x402008 = .got.plt (0x402000) + 8
// 4202508 = 0x40200C = .got.plt (0x402000) + got.plt.reserved(12)
// 4202512 = 0x402010 = .got.plt (0x402000) + got.plt.reserved(12) + 4
// DISASM:      Disassembly of section .plt:
// DISASM-NEXT: .plt:
// DISASM-NEXT:    401020: ff 35 04 20 40 00 pushl 4202500
// DISASM-NEXT:    401026: ff 25 08 20 40 00 jmpl *4202504
// DISASM-NEXT:    40102c: 90 nop
// DISASM-NEXT:    40102d: 90 nop
// DISASM-NEXT:    40102e: 90 nop
// DISASM-NEXT:    40102f: 90 nop
// DISASM-EMPTY:
// DISASM-NEXT:   bar@plt:
// DISASM-NEXT:    401030: ff 25 0c 20 40 00 jmpl *4202508
// DISASM-NEXT:    401036: 68 00 00 00 00 pushl $0
// DISASM-NEXT:    40103b: e9 e0 ff ff ff jmp -32 <.plt>
// DISASM-EMPTY:
// DISASM-NEXT:   zed@plt:
// DISASM-NEXT:    401040: ff 25 10 20 40 00 jmpl *4202512
// DISASM-NEXT:    401046: 68 08 00 00 00 pushl $8
// DISASM-NEXT:    40104b: e9 d0 ff ff ff jmp -48 <.plt>

// CHECKSHARED:        Name: .plt
// CHECKSHARED-NEXT:   Type: SHT_PROGBITS
// CHECKSHARED-NEXT:   Flags [
// CHECKSHARED-NEXT:     SHF_ALLOC
// CHECKSHARED-NEXT:     SHF_EXECINSTR
// CHECKSHARED-NEXT:   ]
// CHECKSHARED-NEXT:   Address: 0x1020
// CHECKSHARED-NEXT:   Offset: 0x1020
// CHECKSHARED-NEXT:   Size: 48
// CHECKSHARED-NEXT:   Link: 0
// CHECKSHARED-NEXT:   Info: 0
// CHECKSHARED-NEXT:   AddressAlignment: 16
// CHECKSHARED-NEXT:   EntrySize: 0
// CHECKSHARED-NEXT:   }
// CHECKSHARED:        Name: .got.plt
// CHECKSHARED-NEXT:   Type: SHT_PROGBITS
// CHECKSHARED-NEXT:   Flags [
// CHECKSHARED-NEXT:     SHF_ALLOC
// CHECKSHARED-NEXT:     SHF_WRITE
// CHECKSHARED-NEXT:   ]
// CHECKSHARED-NEXT:   Address: 0x2000
// CHECKSHARED-NEXT:   Offset: 0x2000
// CHECKSHARED-NEXT:   Size: 20
// CHECKSHARED-NEXT:   Link: 0
// CHECKSHARED-NEXT:   Info: 0
// CHECKSHARED-NEXT:   AddressAlignment: 4
// CHECKSHARED-NEXT:   EntrySize: 0
// CHECKSHARED-NEXT:   }

// 0x2000 + got.plt.reserved(12) = 0x200C
// 0x2000 + got.plt.reserved(12) + 4 = 0x2010
// CHECKSHARED:        Relocations [
// CHECKSHARED-NEXT:     Section ({{.*}}) .rel.plt {
// CHECKSHARED-NEXT:       0x200C R_386_JUMP_SLOT bar 0x0
// CHECKSHARED-NEXT:       0x2010 R_386_JUMP_SLOT zed 0x0
// CHECKSHARED-NEXT:     }
// CHECKSHARED-NEXT:   ]

// DISASMSHARED:       local:
// DISASMSHARED-NEXT:  1000: {{.*}}
// DISASMSHARED-NEXT:  1002: {{.*}}
// DISASMSHARED:       _start:
// 0x1013 + 5 - 24 = 0x1000
// DISASMSHARED-NEXT:  1004: e9 27 00 00 00 jmp 39
// DISASMSHARED-NEXT:  1009: e9 22 00 00 00 jmp 34
// DISASMSHARED-NEXT:  100e: e9 2d 00 00 00 jmp 45
// DISASMSHARED-NEXT:  1013: e9 e8 ff ff ff jmp -24
// DISASMSHARED-NEXT:  Disassembly of section .plt:
// DISASMSHARED-NEXT:  .plt:
// DISASMSHARED-NEXT:  1020: ff b3 04 20 00 00 pushl 8196(%ebx)
// DISASMSHARED-NEXT:  1026: ff a3 08 20 00 00 jmpl *8200(%ebx)
// DISASMSHARED-NEXT:  102c: 90 nop
// DISASMSHARED-NEXT:  102d: 90 nop
// DISASMSHARED-NEXT:  102e: 90 nop
// DISASMSHARED-NEXT:  102f: 90 nop
// DISASMSHARED-NEXT:  1030: ff a3 0c 20 00 00 jmpl *8204(%ebx)
// DISASMSHARED-NEXT:  1036: 68 00 00 00 00     pushl $0
// DISASMSHARED-NEXT:  103b: e9 e0 ff ff ff     jmp -32 <.plt>
// DISASMSHARED-NEXT:  1040: ff a3 10 20 00 00 jmpl *8208(%ebx)
// DISASMSHARED-NEXT:  1046: 68 08 00 00 00     pushl $8
// DISASMSHARED-NEXT:  104b: e9 d0 ff ff ff     jmp -48 <.plt>

// DISASMPIE:      Disassembly of section .plt:
// DISASMPIE-NEXT: .plt:
// DISASMPIE-NEXT:   1020:	ff b3 04 20 00 00 pushl 8196(%ebx)
// DISASMPIE-NEXT:   1026:	ff a3 08 20 00 00 jmpl *8200(%ebx)
// DISASMPIE-NEXT:   102c:	90 nop
// DISASMPIE-NEXT:   102d:	90 nop
// DISASMPIE-NEXT:   102e:	90 nop
// DISASMPIE-NEXT:   102f:	90 nop
// DISASMPIE-NEXT:   1030:	ff a3 0c 20 00 00 jmpl *8204(%ebx)
// DISASMPIE-NEXT:   1036:	68 00 00 00 00 pushl $0
// DISASMPIE-NEXT:   103b:	e9 e0 ff ff ff jmp -32 <.plt>
// DISASMPIE-NEXT:   1040:	ff a3 10 20 00 00 jmpl *8208(%ebx)
// DISASMPIE-NEXT:   1046:	68 08 00 00 00 pushl $8
// DISASMPIE-NEXT:   104b:	e9 d0 ff ff ff jmp -48 <.plt>

local:
.long 0

.global _start
_start:
  jmp bar@PLT
  jmp bar@PLT
  jmp zed@PLT
  jmp local@plt
