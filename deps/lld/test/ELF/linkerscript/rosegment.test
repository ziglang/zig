# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux /dev/null -o %t

# Test that with linker scripts we don't create a RO PT_LOAD.

# RUN: ld.lld -o %t1 --script %s %t -shared
# RUN: llvm-readobj -l %t1 | FileCheck %s

SECTIONS {
}

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
