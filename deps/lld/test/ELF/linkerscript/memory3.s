# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "MEMORY { ram2 (ax) : ORIGIN = 0x1000, LENGTH = 1K   \
# RUN:                ram1 (ax) : ORIGIN = 0x4000, LENGTH = 1K } \
# RUN: SECTIONS {}" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

# RUN: echo "MEMORY { ram1 (ax) : ORIGIN = 0x1000, LENGTH = 1K   \
# RUN:                ram2 (ax) : ORIGIN = 0x4000, LENGTH = 1K } \
# RUN: SECTIONS {}" > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %t
# RUN: llvm-objdump -section-headers %t2 | FileCheck %s

## Check we place .text into first defined memory region with appropriate flags.
# CHECK: Sections:
# CHECK: Idx Name  Size      Address
# CHECK:   0       00000000 0000000000000000
# CHECK:   1 .text 00000001 0000000000001000

.section .text.foo,"ax",%progbits
foo:
  nop
