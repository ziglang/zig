# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# This test case should place input sections in script order:
# .foo.1 .foo.2 .bar.1 .bar.2
# RUN: echo "SECTIONS { . = 0x1000; .foo : {*(.foo.*) *(.bar.*)  } }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section=.foo -s %t1 | FileCheck --check-prefix=SCRIPT_ORDER %s
# SCRIPT_ORDER: Contents of section .foo:
# SCRIPT_ORDER-NEXT: 1000 00000000 00000000 ffffffff eeeeeeee

# This test case should place input sections in native order:
# .bar.1 .foo.1 .bar.2 .foo.2
# RUN: echo "SECTIONS { . = 0x1000; .foo : {*(.foo.* .bar.*)} }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section=.foo -s %t1 | FileCheck --check-prefix=FILE_ORDER %s
# FILE_ORDER: Contents of section .foo:
# FILE_ORDER-NEXT: 1000 ffffffff 00000000 eeeeeeee 00000000

.global _start
_start:
 nop

.section .bar.1,"a"
bar1:
 .long 0xFFFFFFFF

.section .foo.1,"a"
foo1:
 .long 0

.section .bar.2,"a"
bar2:
 .long 0xEEEEEEEE

.section .foo.2,"a"
foo2:
 .long 0
