// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -shared -o %t.so
// RUN: llvm-readelf -s %t.so | FileCheck %s -check-prefix=SECTION
// RUN: llvm-objdump -d %t.so | FileCheck %s

// SECTION: .got PROGBITS 0000000000003070 003070 000000

// 0x3070 (.got end) - 0x1000 = 8304
// CHECK: gotpc64:
// CHECK-NEXT: 1000: {{.*}} movabsq $8304, %r11
.global gotpc64
gotpc64:
  movabsq $_GLOBAL_OFFSET_TABLE_-., %r11
