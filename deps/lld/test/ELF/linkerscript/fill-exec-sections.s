# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

## Check that padding of executable sections are filled with trap bytes if not
## otherwise specified in the script.
# RUN: echo "SECTIONS { .exec : { *(.exec*) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck %s --check-prefix=EXEC
# EXEC:      0000 66cccccc cccccccc cccccccc cccccccc
# EXEC-NEXT: 0010 66

## Check that a fill expression or command overrides the default filler...
# RUN: echo "SECTIONS { .exec : { *(.exec*) }=0x11223344 }" > %t2.script
# RUN: ld.lld -o %t2.out --script %t2.script %t
# RUN: llvm-objdump -s %t2.out | FileCheck %s --check-prefix=OVERRIDE
# RUN: echo "SECTIONS { .exec : { FILL(0x11223344); *(.exec*) } }" > %t3.script
# RUN: ld.lld -o %t3.out --script %t3.script %t
# RUN: llvm-objdump -s %t3.out | FileCheck %s --check-prefix=OVERRIDE
# OVERRIDE:      Contents of section .exec:
# OVERRIDE-NEXT:  0000 66112233 44112233 44112233 44112233
# OVERRIDE-NEXT:  0010 66

## ...even for a value of zero.
# RUN: echo "SECTIONS { .exec : { *(.exec*) }=0x00000000 }" > %t4.script
# RUN: ld.lld -o %t4.out --script %t4.script %t
# RUN: llvm-objdump -s %t4.out | FileCheck %s --check-prefix=ZERO
# RUN: echo "SECTIONS { .exec : { FILL(0x00000000); *(.exec*) } }" > %t5.script
# RUN: ld.lld -o %t5.out --script %t5.script %t
# RUN: llvm-objdump -s %t5.out | FileCheck %s --check-prefix=ZERO
# ZERO:      Contents of section .exec:
# ZERO-NEXT:  0000 66000000 00000000 00000000 00000000
# ZERO-NEXT:  0010 66

.section        .exec.1,"ax"
.align  16
.byte   0x66

.section        .exec.2,"ax"
.align  16
.byte   0x66
