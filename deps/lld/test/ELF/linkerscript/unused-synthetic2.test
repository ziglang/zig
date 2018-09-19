# REQUIRES: arm
# RUN: llvm-mc -filetype=obj -triple=armv7-unknown-linux-gnueabi /dev/null -o %t.o

## We incorrectly removed unused synthetic sections and crashed before.
## Check we do not crash and do not produce .trap output section.
# RUN: ld.lld -shared -o %t.so --script %s %t.o
# RUN: llvm-objdump -section-headers %t.so | FileCheck %s
# CHECK-NOT: .trap

SECTIONS {
  .trap : { *(.ARM.exidx) *(.dummy) }
}
