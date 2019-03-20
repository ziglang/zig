# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "SECTIONS { /DISCARD/ : { *(.shstrtab) } }" > %t.script
# RUN: not ld.lld -o %t --script %t.script %t.o 2>&1 | \
# RUN:   FileCheck -check-prefix=SHSTRTAB %s
# SHSTRTAB: discarding .shstrtab section is not allowed

## We allow discarding .dynamic, check we don't crash.
# RUN: echo "SECTIONS { /DISCARD/ : { *(.dynamic) } }" > %t.script
# RUN: ld.lld -pie -o %t --script %t.script %t.o

## We allow discarding .dynsym, check we don't crash.
# RUN: echo "SECTIONS { /DISCARD/ : { *(.dynsym) } }" > %t.script
# RUN: ld.lld -pie -o %t --script %t.script %t.o

## We allow discarding .dynstr, check we don't crash.
# RUN: echo "SECTIONS { /DISCARD/ : { *(.dynstr) } }" > %t.script
# RUN: ld.lld -pie -o %t --script %t.script %t.o

# RUN: echo "SECTIONS { /DISCARD/ : { *(.rela.dyn) } }" > %t.script
# RUN: not ld.lld -pie -o %t --script %t.script %t.o 2>&1 | \
# RUN:   FileCheck -check-prefix=RELADYN %s
# RELADYN: discarding .rela.dyn section is not allowed

.comm foo,4,4
