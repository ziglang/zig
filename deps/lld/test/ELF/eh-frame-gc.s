# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
# RUN: ld.lld -shared --gc-sections %t.o -o %t
# RUN: llvm-readobj  -s %t | FileCheck %s

## Check that section containing personality is
## not garbage collected.
# CHECK: Sections [
# CHECK: Name: .test_personality_section

.text
.globl foo
.type foo,@function
foo:
 .cfi_startproc
 .cfi_personality 155, DW.ref.__gxx_personality_v0
 .cfi_endproc

.section .test_personality_section
DW.ref.__gxx_personality_v0:
