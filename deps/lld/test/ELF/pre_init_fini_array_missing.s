// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld %t -o %t2
// RUN: llvm-objdump -d %t2 | FileCheck %s
// RUN: ld.lld -pie %t -o %t3
// RUN: llvm-objdump -d %t3 | FileCheck --check-prefix=PIE %s

.globl _start
_start:
  call __preinit_array_start
  call __preinit_array_end
  call __init_array_start
  call __init_array_end
  call __fini_array_start
  call __fini_array_end

// With no .init_array section the symbols resolve to .text.
// 0x201000 - (0x201000 + 5) = -5
// 0x201000 - (0x201005 + 5) = -10
// ...

// CHECK: Disassembly of section .text:
// CHECK-EMPTY:
// CHECK-NEXT:  _start:
// CHECK-NEXT:   201000:    e8 fb ff ff ff     callq    -5
// CHECK-NEXT:   201005:    e8 f6 ff ff ff     callq    -10
// CHECK-NEXT:   20100a:    e8 f1 ff ff ff     callq    -15
// CHECK-NEXT:   20100f:    e8 ec ff ff ff     callq    -20
// CHECK-NEXT:   201014:    e8 e7 ff ff ff     callq    -25
// CHECK-NEXT:   201019:    e8 e2 ff ff ff     callq    -30

// In position-independent binaries, they resolve to .text too.

// PIE:      Disassembly of section .text:
// PIE-EMPTY:
// PIE-NEXT: _start:
// PIE-NEXT:     1000:  e8 fb ff ff ff  callq   -5
// PIE-NEXT:     1005:  e8 f6 ff ff ff  callq   -10
// PIE-NEXT:     100a:  e8 f1 ff ff ff  callq   -15
// PIE-NEXT:     100f:  e8 ec ff ff ff  callq   -20
// PIE-NEXT:     1014:  e8 e7 ff ff ff  callq   -25
// PIE-NEXT:     1019:  e8 e2 ff ff ff  callq   -30
