# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS { .writable : { *(.writable) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -section-headers %t.out | \
# RUN:   FileCheck -check-prefix=TEXTORPHAN %s

# RUN: echo "SECTIONS { .text : { *(.text) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -section-headers %t.out | \
# RUN:   FileCheck -check-prefix=WRITABLEORPHAN %s

# TEXTORPHAN:      Sections:
# TEXTORPHAN-NEXT: Idx Name
# TEXTORPHAN-NEXT:   0
# TEXTORPHAN-NEXT:   1 .text
# TEXTORPHAN-NEXT:   2 .writable

# WRITABLEORPHAN:      Sections:
# WRITABLEORPHAN-NEXT: Idx Name
# WRITABLEORPHAN-NEXT:   0
# WRITABLEORPHAN-NEXT:   1 .text
# WRITABLEORPHAN-NEXT:   2 .writable

.global _start
_start:
 nop

.section .writable,"aw"
 .zero 4
