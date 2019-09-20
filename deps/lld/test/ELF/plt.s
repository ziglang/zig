// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld -shared %t.o %t2.so -o %t
// RUN: ld.lld %t.o %t2.so -o %t3
// RUN: llvm-readobj -S -r %t | FileCheck %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s
// RUN: llvm-readobj -S -r %t3 | FileCheck --check-prefix=CHECK2 %s
// RUN: llvm-objdump -d %t3 | FileCheck --check-prefix=DISASM2 %s

// CHECK:      Name: .plt
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_EXECINSTR
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x1020
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 64
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 16

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.plt {
// CHECK-NEXT:     0x3018 R_X86_64_JUMP_SLOT bar 0x0
// CHECK-NEXT:     0x3020 R_X86_64_JUMP_SLOT zed 0x0
// CHECK-NEXT:     0x3028 R_X86_64_JUMP_SLOT _start 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// CHECK2:      Name: .plt
// CHECK2-NEXT: Type: SHT_PROGBITS
// CHECK2-NEXT: Flags [
// CHECK2-NEXT:   SHF_ALLOC
// CHECK2-NEXT:   SHF_EXECINSTR
// CHECK2-NEXT: ]
// CHECK2-NEXT: Address: 0x201020
// CHECK2-NEXT: Offset:
// CHECK2-NEXT: Size: 48
// CHECK2-NEXT: Link: 0
// CHECK2-NEXT: Info: 0
// CHECK2-NEXT: AddressAlignment: 16

// CHECK2:      Relocations [
// CHECK2-NEXT:   Section ({{.*}}) .rela.plt {
// CHECK2-NEXT:     0x203018 R_X86_64_JUMP_SLOT bar 0x0
// CHECK2-NEXT:     0x203020 R_X86_64_JUMP_SLOT zed 0x0
// CHECK2-NEXT:   }
// CHECK2-NEXT: ]

// Unfortunately FileCheck can't do math, so we have to check for explicit
// values:

// 0x1030 - (0x1000 + 5) = 43
// 0x1030 - (0x1005 + 5) = 38
// 0x1040 - (0x100a + 5) = 49
// 0x1048 - (0x100a + 5) = 60

// DISASM:      _start:
// DISASM-NEXT:   1000:  e9 {{.*}}       jmp  43
// DISASM-NEXT:   1005:  e9 {{.*}}       jmp  38
// DISASM-NEXT:   100a:  e9 {{.*}}       jmp  49
// DISASM-NEXT:   100f:  e9 {{.*}}       jmp  60

// 0x3018 - 0x1036  = 8162
// 0x3020 - 0x1046  = 8154
// 0x3028 - 0x1056  = 8146

// DISASM:      Disassembly of section .plt:
// DISASM-EMPTY:
// DISASM-NEXT: .plt:
// DISASM-NEXT:   1020:  ff 35 e2 1f 00 00  pushq 8162(%rip)
// DISASM-NEXT:   1026:  ff 25 e4 1f 00 00  jmpq *8164(%rip)
// DISASM-NEXT:   102c:  0f 1f 40 00        nopl (%rax)
// DISASM-EMPTY:
// DISASM-NEXT:   bar@plt:
// DISASM-NEXT:   1030:  ff 25 e2 1f 00 00  jmpq *8162(%rip)
// DISASM-NEXT:   1036:  68 00 00 00 00     pushq $0
// DISASM-NEXT:   103b:  e9 e0 ff ff ff     jmp -32 <.plt>
// DISASM-EMPTY:
// DISASM-NEXT:   zed@plt:
// DISASM-NEXT:   1040:  ff 25 da 1f 00 00  jmpq *8154(%rip)
// DISASM-NEXT:   1046:  68 01 00 00 00     pushq $1
// DISASM-NEXT:   104b:  e9 d0 ff ff ff     jmp -48 <.plt>
// DISASM-EMPTY:
// DISASM-NEXT:   _start@plt:
// DISASM-NEXT:   1050:  ff 25 d2 1f 00 00  jmpq *8146(%rip)
// DISASM-NEXT:   1056:  68 02 00 00 00     pushq $2
// DISASM-NEXT:   105b:  e9 c0 ff ff ff     jmp -64 <.plt>

// 0x201030 - (0x201000 + 1) - 4 = 43
// 0x201030 - (0x201005 + 1) - 4 = 38
// 0x201040 - (0x20100a + 1) - 4 = 49
// 0x201000 - (0x20100f + 1) - 4 = -20

// DISASM2:      _start:
// DISASM2-NEXT:   201000:  e9 {{.*}}     jmp  43
// DISASM2-NEXT:   201005:  e9 {{.*}}     jmp  38
// DISASM2-NEXT:   20100a:  e9 {{.*}}     jmp  49
// DISASM2-NEXT:   20100f:  e9 {{.*}}     jmp  -20

// 0x202018 - 0x201036  = 4066
// 0x202020 - 0x201046  = 4058

// DISASM2:      Disassembly of section .plt:
// DISASM2-EMPTY:
// DISASM2-NEXT: .plt:
// DISASM2-NEXT:  201020:  ff 35 e2 1f 00 00   pushq 8162(%rip)
// DISASM2-NEXT:  201026:  ff 25 e4 1f 00 00   jmpq *8164(%rip)
// DISASM2-NEXT:  20102c:  0f 1f 40 00         nopl  (%rax)
// DISASM2-EMPTY:
// DISASM2-NEXT:   bar@plt:
// DISASM2-NEXT:  201030:  ff 25 e2 1f 00 00   jmpq *8162(%rip)
// DISASM2-NEXT:  201036:  68 00 00 00 00      pushq $0
// DISASM2-NEXT:  20103b:  e9 e0 ff ff ff      jmp -32 <.plt>
// DISASM2-EMPTY:
// DISASM2-NEXT:   zed@plt:
// DISASM2-NEXT:  201040:  ff 25 da 1f 00 00   jmpq *8154(%rip)
// DISASM2-NEXT:  201046:  68 01 00 00 00      pushq $1
// DISASM2-NEXT:  20104b:  e9 d0 ff ff ff      jmp -48 <.plt>
// DISASM2-NOT:   2010C0

.global _start
_start:
  jmp bar@PLT
  jmp bar@PLT
  jmp zed@PLT
  jmp _start@plt
