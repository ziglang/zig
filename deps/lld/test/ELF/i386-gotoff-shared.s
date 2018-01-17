// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv %t.o -o %t.so -shared
// RUN: llvm-readobj -s %t.so | FileCheck %s
// RUN: llvm-objdump -d %t.so | FileCheck --check-prefix=DISASM %s

bar:
        movl    bar@GOTOFF(%ebx), %eax
        mov     bar@GOT, %eax

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x2050
// CHECK-NEXT: Offset: 0x2050
// CHECK-NEXT: Size: 4

// 0x1000 - (0x2050 + 4) = -4180

// DISASM:  1000: {{.*}} movl    -4180(%ebx), %eax
