# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux-gnu %s -o %t
# RUN: echo "SECTIONS { \
# RUN:   .data 0x1000 : { *(.data) } \
# RUN:   .got 0x2000 : { \
# RUN:     LONG(0) \
# RUN:     *(.got) \
# RUN:   } \
# RUN:  };" > %t.script
# RUN: ld.lld -shared -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck %s
.text
.global foo
foo:
	movl bar@GOT, %eax
.data
.local bar
bar:
	.zero 4
# CHECK:      Contents of section .data:
# CHECK-NEXT:  1000 00000000
# CHECK:      Contents of section .got:
# CHECK-NEXT:  2000 00000000 00100000
