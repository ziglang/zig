# REQUIRES: x86
# RUN: echo "SECTIONS { .foo : { *(.eh_frame) } }" > %t.script
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --emit-relocs %t.o -T %t.script -o %t
# RUN: llvm-objdump -section-headers %t | FileCheck %s

# CHECK-NOT: eh_frame
# CHECK:     .rela.foo
# CHECK-NOT: eh_frame

.text
 .cfi_startproc
 .cfi_endproc
