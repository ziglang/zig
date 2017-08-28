# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# Test that with linker scripts we don't create a RO PT_LOAD.

# RUN: echo "SECTIONS {}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t -shared
# RUN: llvm-readobj -l %t1 | FileCheck %s

# CHECK-NOT:  Type: PT_LOAD

# CHECK:      Type: PT_LOAD
# CHECK:      Flags [
# CHECK-NEXT:   PF_R
# CHECK-NEXT:   PF_X
# CHECK-NEXT: ]

# CHECK:      Type: PT_LOAD
# CHECK:      Flags [
# CHECK-NEXT:   PF_R
# CHECK-NEXT:   PF_W
# CHECK-NEXT: ]

# CHECK-NOT:  Type: PT_LOAD
