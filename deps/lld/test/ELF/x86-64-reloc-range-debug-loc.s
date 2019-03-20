# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/x86-64-reloc-error.s -o %tabs
# RUN: llvm-mc %s -o %t.o -triple x86_64-pc-linux -filetype=obj
# RUN: not ld.lld %tabs %t.o -o /dev/null -shared 2>&1 | FileCheck %s

## Check we are able to report file and location from debug information
## when reporting such kind of errors.
# CHECK: error: test.s:3:(.text+0x1): relocation R_X86_64_32 out of range: 68719476736 is not in [0, 4294967295]

.section .text,"ax",@progbits
foo:
.file 1 "test.s"
.loc 1 3
 movl $big, %edx

.section .debug_abbrev,"",@progbits
.byte 1                       # Abbreviation Code
.byte 17                      # DW_TAG_compile_unit
.byte 0                       # DW_CHILDREN_no
.byte 16                      # DW_AT_stmt_list
.byte 23                      # DW_FORM_sec_offset
.byte 0                       # EOM(1)
.byte 0                       # EOM(2)
.byte 0                       # EOM(3)

.section .debug_info,"",@progbits
.long .Lend0 - .Lbegin0       # Length of Unit
.Lbegin0:
.short 4                       # DWARF version number
.long .debug_abbrev           # Offset Into Abbrev. Section
.byte 8                       # Address Size (in bytes)
.byte 1                       # Abbrev [1] 0xb:0x1f DW_TAG_compile_unit
.long .debug_line             # DW_AT_stmt_list
.Lend0:

.section .debug_line,"",@progbits
