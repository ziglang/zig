// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/shared.s -o %t2
// RUN: ld.lld %t2 -soname fixed-length-string.so -o %t2.so -shared
// RUN: ld.lld --hash-style=sysv %t %t2.so -o %t3
// RUN: llvm-readobj -S  %t3 | FileCheck --check-prefix=SEC %s
// RUN: llvm-objdump -s -d %t3 | FileCheck %s

// SEC:      Name: .plt
// SEC-NEXT: Type: SHT_PROGBITS
// SEC-NEXT: Flags [
// SEC-NEXT:   SHF_ALLOC
// SEC-NEXT:   SHF_EXECINSTR
// SEC-NEXT: ]
// SEC-NEXT: Address: 0x201030
// SEC-NEXT: Offset: 0x1030
// SEC-NEXT: Size: 48

// SEC:         Name: .got
// SEC-NEXT:   Type: SHT_PROGBITS
// SEC-NEXT:   Flags [
// SEC-NEXT:     SHF_ALLOC
// SEC-NEXT:     SHF_WRITE
// SEC-NEXT:   ]
// SEC-NEXT:   Address: 0x2020F0
// SEC-NEXT:   Offset:
// SEC-NEXT:   Size: 8
// SEC-NEXT:   Link: 0
// SEC-NEXT:   Info: 0
// SEC-NEXT:   AddressAlignment: 8
// SEC-NEXT:   EntrySize: 0
// SEC-NEXT: }

// SEC:        Name: .got.plt
// SEC-NEXT:   Type: SHT_PROGBITS
// SEC-NEXT:   Flags [
// SEC-NEXT:     SHF_ALLOC
// SEC-NEXT:     SHF_WRITE
// SEC-NEXT:   ]
// SEC-NEXT:   Address: 0x203000
// SEC-NEXT:   Offset: 0x3000
// SEC-NEXT:   Size: 40
// SEC-NEXT:   Link: 0
// SEC-NEXT:   Info: 0
// SEC-NEXT:   AddressAlignment: 8
// SEC-NEXT:   EntrySize: 0
// SEC-NEXT:   }

.section       .text,"ax",@progbits,unique,1
.global _start
_start:
  call lulz

.section       .text,"ax",@progbits,unique,2
.zero 4
.global lulz
lulz:
  nop

// CHECK: Disassembly of section .text:
// CHECK-EMPTY:
// CHECK-NEXT: _start:
// CHECK-NEXT:   201000:  e8 04 00 00 00   callq 4
// CHECK-NEXT:   201005:

// CHECK:      lulz:
// CHECK-NEXT:   201009:  90  nop


.section       .text2,"ax",@progbits
.global R_X86_64_32
R_X86_64_32:
  movl $R_X86_64_32, %edx

// FIXME: this would be far more self evident if llvm-objdump printed
// constants in hex.
// CHECK: Disassembly of section .text2:
// CHECK-EMPTY:
// CHECK-NEXT: R_X86_64_32:
// CHECK-NEXT:  20100a: {{.*}} movl $2101258, %edx

.section .R_X86_64_32S,"ax",@progbits
.global R_X86_64_32S
R_X86_64_32S:
  movq lulz - 0x100000, %rdx

// CHECK: Disassembly of section .R_X86_64_32S:
// CHECK-EMPTY:
// CHECK-NEXT: R_X86_64_32S:
// CHECK-NEXT:  {{.*}}: {{.*}} movq 1052681, %rdx

.section .R_X86_64_PC32,"ax",@progbits
.global R_X86_64_PC32
R_X86_64_PC32:
 call bar
 movl $bar, %eax
//16 is a size of PLT[0]
// 0x201030 + 16 - (0x201017 + 5) = 20
// CHECK:      Disassembly of section .R_X86_64_PC32:
// CHECK-EMPTY:
// CHECK-NEXT: R_X86_64_PC32:
// CHECK-NEXT:  201017:   {{.*}}  callq  36
// CHECK-NEXT:  20101c:   {{.*}}  movl $2101312, %eax

.section .R_X86_64_32S_2,"ax",@progbits
.global R_X86_64_32S_2
R_X86_64_32S_2:
  mov bar2, %eax
// plt is  at 0x201030. The second plt entry is at 0x201050 == 69712
// CHECK:      Disassembly of section .R_X86_64_32S_2:
// CHECK-EMPTY:
// CHECK-NEXT: R_X86_64_32S_2:
// CHECK-NEXT: 201021: {{.*}}  movl    2101328, %eax

.section .R_X86_64_64,"a",@progbits
.global R_X86_64_64
R_X86_64_64:
 .quad R_X86_64_64

// CHECK:      Contents of section .R_X86_64_64:
// CHECK-NEXT:   2002f8 f8022000 00000000

.section .R_X86_64_GOTPCREL,"a",@progbits
.global R_X86_64_GOTPCREL
R_X86_64_GOTPCREL:
 .long zed@gotpcrel

// 0x2020F0(.got) - 0x2002c8(.R_X86_64_GOTPCREL) = 0x1e28
// CHECK:      Contents of section .R_X86_64_GOTPCREL
// CHECK-NEXT:   200300 f01d0000

.section .R_X86_64_GOT32,"a",@progbits
.global R_X86_64_GOT32
R_X86_64_GOT32:
        .long zed@got

// CHECK: Contents of section .R_X86_64_GOT32:
// CHECK-NEXT: f0f0ffff


// CHECK: Contents of section .R_X86_64_GOT64:
// CHECK-NEXT: f0f0ffff ffffffff
.section .R_X86_64_GOT64,"a",@progbits
.global R_X86_64_GOT64
R_X86_64_GOT64:
        .quad zed@got
