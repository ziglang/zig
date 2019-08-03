# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

## In this test we check that output section types such as
## COPY, INFO and OVERLAY marks output section as non-allocatable.

# RUN: echo "SECTIONS { .bar : { *(.foo) } };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj --sections %t | FileCheck %s --check-prefix=DEFAULT
# DEFAULT:      Name: .bar
# DEFAULT:      Type: SHT_PROGBITS
# DEFAULT-NEXT: Flags [
# DEFAULT-NEXT:   SHF_ALLOC
# DEFAULT-NEXT: ]

# RUN: echo "SECTIONS { .bar (COPY) : { *(.foo) } };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj --sections %t | FileCheck %s --check-prefix=NONALLOC
# NONALLOC:      Name: .bar
# NONALLOC:      Type: SHT_PROGBITS
# NONALLOC-NEXT: Flags [
# NONALLOC-NEXT: ]

# RUN: echo "SECTIONS { .bar (INFO) : { *(.foo) } };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj --sections %t | FileCheck %s --check-prefix=NONALLOC

# RUN: echo "SECTIONS { .bar (OVERLAY) : { *(.foo) } };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj --sections %t | FileCheck %s --check-prefix=NONALLOC

# RUN: echo "SECTIONS { .bar (INFO) : { . += 1; } };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj --sections %t | FileCheck %s --check-prefix=NONALLOC

# RUN: echo "SECTIONS { .bar 0x20000 (INFO) : { *(.foo) } };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj --sections %t | FileCheck %s --check-prefix=NONALLOC

# RUN: echo "SECTIONS { .bar 0x20000 (BAR) : { *(.foo) } };" > %t.script
# RUN: not ld.lld -o %t --script %t.script %t.o 2>&1 |\
# RUN:   FileCheck %s --check-prefix=UNKNOWN
# UNKNOWN: unknown section directive: BAR

.section .foo,"a",@progbits
.zero 1
