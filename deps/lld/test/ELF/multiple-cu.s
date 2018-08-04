# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/multiple-cu.s -o %t2.o
# RUN: ld.lld -r -o %t.o %t1.o %t2.o
# RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s

# CHECK:      error: undefined symbol: foo
# CHECK-NEXT: referenced by test1.c:2

# CHECK:      error: undefined symbol: bar
# CHECK-NEXT: referenced by test2.c:2

        .globl  _start
_start:
        .file   1 "test1.c"
        .loc    1 2 0
        jmp     foo

        .section        .debug_abbrev,"",@progbits
        .byte   1                       # Abbreviation Code
        .byte   17                      # DW_TAG_compile_unit
        .byte   0                       # DW_CHILDREN_no
        .byte   16                      # DW_AT_stmt_list
        .byte   23                      # DW_FORM_sec_offset
        .byte   0                       # EOM(1)
        .byte   0                       # EOM(2)
        .byte   0                       # EOM(3)

        .section        .debug_info,"",@progbits
        .long   .Lend0 - .Lbegin0       # Length of Unit
.Lbegin0:
        .short  4                       # DWARF version number
        .long   .debug_abbrev           # Offset Into Abbrev. Section
        .byte   8                       # Address Size (in bytes)
        .byte   1                       # Abbrev [1] 0xb:0x1f DW_TAG_compile_unit
        .long   .debug_line             # DW_AT_stmt_list
.Lend0:
        .section        .debug_line,"",@progbits
