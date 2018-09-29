// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/x86-64-reloc-error.s -o %tabs
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t

// We have some code in error reporting to check that
// section belongs to the output section. Without that
// check, the linker would crash, so it is useful to test it.
// And the easy way to do that is to trigger GC. That way .text.dumb
// be collected and mentioned check will execute.

// RUN: not ld.lld -gc-sections -shared %tabs %t -o /dev/null

.section .text.dumb,"ax"
 nop

.section .text,"ax"
.globl _start
_start:
  movl $big, %edx
