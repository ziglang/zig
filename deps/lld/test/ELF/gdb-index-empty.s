# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux -o %t %s
# RUN: ld.lld --gdb-index --gc-sections -o %t2 %t
# RUN: llvm-dwarfdump -gdb-index %t2 | FileCheck %s

# CHECK: Address area offset = 0x28, has 0 entries:

# Generated with: (clang r302976)
# echo "void _start() { __builtin_unreachable(); }" | \
# clang -Os -g -S -o gdb-index-empty.s -x c - -Xclang -fdebug-compilation-dir -Xclang .

.text
.globl _start
.type _start,@function
_start:
.Lfunc_begin0:
.Lfunc_end0:

.section .debug_abbrev,"",@progbits
 .byte 1                       # Abbreviation Code
 .byte 17                      # DW_TAG_compile_unit
 .byte 1                       # DW_CHILDREN_yes
 .byte 37                      # DW_AT_producer
 .byte 14                      # DW_FORM_strp
 .byte 19                      # DW_AT_language
 .byte 5                       # DW_FORM_data2
 .byte 3                       # DW_AT_name
 .byte 14                      # DW_FORM_strp
 .byte 16                      # DW_AT_stmt_list
 .byte 23                      # DW_FORM_sec_offset
 .byte 27                      # DW_AT_comp_dir
 .byte 14                      # DW_FORM_strp
 .byte 17                      # DW_AT_low_pc
 .byte 1                       # DW_FORM_addr
 .byte 18                      # DW_AT_high_pc
 .byte 6                       # DW_FORM_data4
 .byte 0                       # EOM(1)
 .byte 0                       # EOM(2)
 .byte 2                       # Abbreviation Code
 .byte 46                      # DW_TAG_subprogram
 .byte 0                       # DW_CHILDREN_no
 .byte 17                      # DW_AT_low_pc
 .byte 1                       # DW_FORM_addr
 .byte 18                      # DW_AT_high_pc
 .byte 6                       # DW_FORM_data4
 .byte 64                      # DW_AT_frame_base
 .byte 24                      # DW_FORM_exprloc
 .byte 3                       # DW_AT_name
 .byte 14                      # DW_FORM_strp
 .byte 58                      # DW_AT_decl_file
 .byte 11                      # DW_FORM_data1
 .byte 59                      # DW_AT_decl_line
 .byte 11                      # DW_FORM_data1
 .byte 63                      # DW_AT_external
 .byte 25                      # DW_FORM_flag_present
 .byte 0                       # EOM(1)
 .byte 0                       # EOM(2)
 .byte 0                       # EOM(3)

.section .debug_info,"",@progbits
 .long 60                        # Length of Unit
 .short 4                        # DWARF version number
 .long .debug_abbrev             # Offset Into Abbrev. Section
 .byte 8                         # Address Size (in bytes)
 .byte 1                         # Abbrev [1] 0xb:0x35 DW_TAG_compile_unit
 .long 0                         # DW_AT_producer
 .short 12                       # DW_AT_language
 .long 0                         # DW_AT_name
 .long 0                         # DW_AT_stmt_list
 .long 0                         # DW_AT_comp_dir
 .quad .Lfunc_begin0             # DW_AT_low_pc
 .long .Lfunc_end0-.Lfunc_begin0 # DW_AT_high_pc
 .byte 2                         # Abbrev [2] 0x2a:0x15 DW_TAG_subprogram
 .quad .Lfunc_begin0             # DW_AT_low_pc
 .long .Lfunc_end0-.Lfunc_begin0 # DW_AT_high_pc
 .byte 1                         # DW_AT_frame_base
 .byte 87
 .long 0                         # DW_AT_name
 .byte 1                         # DW_AT_decl_file
 .byte 1                         # DW_AT_decl_line
 .byte 0                         # End Of Children Mark
