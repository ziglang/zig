# REQUIRES: x86

## Check we do not crash.

# RUN: echo "MEMORY { FLASH (rx) : ORIGIN = 0x1000< LENGTH" > %t.script
# RUN: not ld.lld -o %t --script %t.script 2>&1 | FileCheck %s
# CHECK: unexpected EOF

# RUN: echo "MEMORY { FLASH (rx) : ORIGIN = 0x1000< ORIGIN" > %t.script
# RUN: not ld.lld -o %t --script %t.script 2>&1 | FileCheck %s

# RUN: echo "MEMORY { FLASH (rx) : ORIGIN = 0x1000, LENGTH = CONSTANT" > %t.script
# RUN: not ld.lld -o %t --script %t.script 2>&1 | FileCheck %s
