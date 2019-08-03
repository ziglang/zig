# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .data 0x2000 : { foo = .; *(.data) } }" > %t.script
# RUN: ld.lld -pie -o %t --script %t.script %t.o
# RUN: llvm-readobj -r %t | FileCheck %s

## Position independent executables require dynamic
## relocations for references to non-absolute script
## symbols.

# CHECK:      Relocations [
# CHECK-NEXT:  Section ({{.*}}) .rela.dyn {
# CHECK-NEXT:    0x2000 R_X86_64_RELATIVE - 0x2000
# CHECK-NEXT:  }
# CHECK-NEXT: ]

.data
.quad foo
