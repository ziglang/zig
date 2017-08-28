# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld -shared --gc-sections -o %t1 %t
# RUN: llvm-readobj --elf-output-style=GNU --file-headers --symbols %t1
#   | FileCheck %s
# CHECK: Entry point address:               0x1000
# CHECK: 0000000000001000     0 FUNC    LOCAL  HIDDEN     4 _start
# CHECK: 0000000000001006     0 FUNC    LOCAL  HIDDEN     4 internal
# CHECK: 0000000000001005     0 FUNC    GLOBAL DEFAULT    4 foobar

.section .text.start,"ax"
.globl _start
.type _start,%function
.hidden _start
_start:
  jmp internal

.section .text.foobar,"ax"
.globl foobar
.type foobar,%function
foobar:
  ret

.section .text.internal,"ax"
.globl internal
.hidden internal
.type internal,%function
internal:
	ret
