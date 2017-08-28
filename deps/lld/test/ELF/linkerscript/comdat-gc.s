# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/comdat-gc.s -o %t1
# RUN: echo "SECTIONS { .text : { *(.text*) } }" > %t.script
# RUN: ld.lld --gc-sections --script %t.script %t %t1 -o %t2
# RUN: llvm-readobj -sections -symbols %t2 | FileCheck -check-prefix=GC1 %s

# GC1:     Name: .debug_line

.file 1 "test/ELF/linkerscript/comdat_gc.s"
.section  .text._Z3fooIiEvv,"axG",@progbits,_Z3fooIiEvv,comdat
.loc 1 14
  ret
