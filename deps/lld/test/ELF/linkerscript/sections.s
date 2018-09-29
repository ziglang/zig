# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# Empty SECTIONS command.
# RUN: echo "SECTIONS {}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | \
# RUN:   FileCheck -check-prefix=SEC-DEFAULT %s

# SECTIONS command with the same order as default.
# RUN: echo "SECTIONS { \
# RUN:          .text : { *(.text) } \
# RUN:          .data : { *(.data) } }" > %t.script
# RUN: ld.lld -o %t2 --script %t.script %t
# RUN: llvm-objdump -section-headers %t2 | \
# RUN:   FileCheck -check-prefix=SEC-DEFAULT %s

#             Idx Name          Size
# SEC-DEFAULT: 1 .text         0000000e {{[0-9a-f]*}} TEXT
# SEC-DEFAULT: 2 .data         00000020 {{[0-9a-f]*}} DATA
# SEC-DEFAULT: 3 other         00000003 {{[0-9a-f]*}} DATA
# SEC-DEFAULT: 4 .bss          00000002 {{[0-9a-f]*}} BSS
# SEC-DEFAULT: 5 .comment      00000008 {{[0-9a-f]*}}
# SEC-DEFAULT: 6 .symtab       00000030 {{[0-9a-f]*}}
# SEC-DEFAULT: 7 .shstrtab     0000003b {{[0-9a-f]*}}
# SEC-DEFAULT: 8 .strtab       00000008 {{[0-9a-f]*}}

# Sections are put in order specified in linker script, other than alloc
# sections going first.
# RUN: echo "SECTIONS { \
# RUN:          .bss : { *(.bss) } \
# RUN:          other : { *(other) } \
# RUN:          .shstrtab : { *(.shstrtab) } \
# RUN:          .symtab : { *(.symtab) } \
# RUN:          .strtab : { *(.strtab) } \
# RUN:          .data : { *(.data) } \
# RUN:          .text : { *(.text) } }" > %t.script
# RUN: ld.lld -o %t3 --script %t.script %t
# RUN: llvm-objdump -section-headers %t3 | \
# RUN:   FileCheck -check-prefix=SEC-ORDER %s

#           Idx Name          Size
# SEC-ORDER: 1 .bss          00000002 {{[0-9a-f]*}} BSS
# SEC-ORDER: 2 other         00000003 {{[0-9a-f]*}} DATA
# SEC-ORDER: 3 .shstrtab     0000003b {{[0-9a-f]*}}
# SEC-ORDER: 4 .symtab       00000030 {{[0-9a-f]*}}
# SEC-ORDER: 5 .strtab       00000008 {{[0-9a-f]*}}
# SEC-ORDER: 6 .comment      00000008 {{[0-9a-f]*}}
# SEC-ORDER: 7 .data         00000020 {{[0-9a-f]*}} DATA
# SEC-ORDER: 8 .text         0000000e {{[0-9a-f]*}} TEXT

# .text and .data have swapped names but proper sizes and types.
# RUN: echo "SECTIONS { \
# RUN:          .data : { *(.text) } \
# RUN:          .text : { *(.data) } }" > %t.script
# RUN: ld.lld -o %t4 --script %t.script %t
# RUN: llvm-objdump -section-headers %t4 | \
# RUN:   FileCheck -check-prefix=SEC-SWAP-NAMES %s

#                Idx Name          Size
# SEC-SWAP-NAMES: 1 .data         0000000e {{[0-9a-f]*}} TEXT
# SEC-SWAP-NAMES: 2 .text         00000020 {{[0-9a-f]*}} DATA
# SEC-SWAP-NAMES: 3 other         00000003 {{[0-9a-f]*}} DATA
# SEC-SWAP-NAMES: 4 .bss          00000002 {{[0-9a-f]*}} BSS
# SEC-SWAP-NAMES: 5 .comment      00000008 {{[0-9a-f]*}}
# SEC-SWAP-NAMES: 6 .symtab       00000030 {{[0-9a-f]*}}
# SEC-SWAP-NAMES: 7 .shstrtab     0000003b {{[0-9a-f]*}}
# SEC-SWAP-NAMES: 8 .strtab       00000008 {{[0-9a-f]*}}

# Multiple SECTIONS command specifying additional input section descriptions
# for the same output section description - input sections are merged into
# one output section.
# RUN: echo "SECTIONS { \
# RUN:          .text : { *(.text) } \
# RUN:          .data : { *(.data) } } \
# RUN:       SECTIONS { \
# RUN:          .data : { *(other) } }" > %t.script
# RUN: ld.lld -o %t6 --script %t.script %t
# RUN: llvm-objdump -section-headers %t6 | \
# RUN:   FileCheck -check-prefix=SEC-MULTI %s

#           Idx Name          Size
# SEC-MULTI:      1 .text         0000000e {{[0-9a-f]*}} TEXT
# SEC-MULTI-NEXT:   .data         00000020 {{[0-9a-f]*}} DATA
# SEC-MULTI-NEXT:   .data         00000003 {{[0-9a-f]*}} DATA
# SEC-MULTI-NEXT:   .bss          00000002 {{[0-9a-f]*}} BSS
# SEC-MULTI-NEXT:   .comment      00000008 {{[0-9a-f]*}}
# SEC-MULTI-NEXT:   .symtab       00000030 {{[0-9a-f]*}}
# SEC-MULTI-NEXT:   .shstrtab     00000035 {{[0-9a-f]*}}
# SEC-MULTI-NEXT:   .strtab       00000008 {{[0-9a-f]*}}

# Input section pattern contains additional semicolon.
# Case found in linux kernel script. Check we are able to parse it.
# RUN: echo "SECTIONS { .text : { ;;*(.text);;S = 0;; } }" > %t.script
# RUN: ld.lld -o /dev/null --script %t.script %t

.globl _start
_start:
    mov $60, %rax
    mov $42, %rdi

.section .data,"aw"
.quad 10, 10, 20, 20
.section other,"aw"
.short 10
.byte 20
.section .bss,"",@nobits
.short 0
