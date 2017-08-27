// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld %t -o %t2
// RUN: llvm-objdump -d %t2 | FileCheck %s
// RUN: ld.lld -pie %t -o %t3
// RUN: llvm-objdump -d %t3 | FileCheck --check-prefix=PIE %s
// REQUIRES: x86

.globl _start
_start:
  call __preinit_array_start
  call __preinit_array_end
  call __init_array_start
  call __init_array_end
  call __fini_array_start
  call __fini_array_end

// With no .init_array section the symbols resolve to 0
// 0 - (0x201000 + 5) = -2101253
// 0 - (0x201005 + 5) = -2101258
// 0 - (0x20100a + 5) = -2101263
// 0 - (0x20100f + 5) = -2101268
// 0 - (0x201014 + 5) = -2101273
// 0 - (0x201019 + 5) = -2101278

// CHECK: Disassembly of section .text:
// CHECK-NEXT:  _start:
// CHECK-NEXT:   201000:    e8 fb ef df ff     callq    -2101253
// CHECK-NEXT:   201005:    e8 f6 ef df ff     callq    -2101258
// CHECK-NEXT:   20100a:    e8 f1 ef df ff     callq    -2101263
// CHECK-NEXT:   20100f:    e8 ec ef df ff     callq    -2101268
// CHECK-NEXT:   201014:    e8 e7 ef df ff     callq    -2101273
// CHECK-NEXT:   201019:    e8 e2 ef df ff     callq    -2101278

// In position-independent binaries, they resolve to the image base.

// PIE:      Disassembly of section .text:
// PIE-NEXT: _start:
// PIE-NEXT:     1000:	e8 fb ef ff ff 	callq	-4101
// PIE-NEXT:     1005:	e8 f6 ef ff ff 	callq	-4106
// PIE-NEXT:     100a:	e8 f1 ef ff ff 	callq	-4111
// PIE-NEXT:     100f:	e8 ec ef ff ff 	callq	-4116
// PIE-NEXT:     1014:	e8 e7 ef ff ff 	callq	-4121
// PIE-NEXT:     1019:	e8 e2 ef ff ff 	callq	-4126
