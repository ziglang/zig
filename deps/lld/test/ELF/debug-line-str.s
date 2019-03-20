# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux -dwarf-version=5 %s -o %t.o
# RUN: not ld.lld %t.o -o %t1 2>&1 | FileCheck %s

# Check we do not crash and able to report the source location.

# CHECK:      error: undefined symbol: foo()
# CHECK-NEXT: >>> referenced by test.cpp:3
# CHECK-NEXT: >>>               {{.*}}.o:(.text+0x1)

# The code below is the reduced version of the output
# from the following invocation and source:
#
# // test.cpp:
# int foo();
# int main() {
#   return foo();
# }
#
# clang -gdwarf-5 test.cpp -o test.s -S
# clang version 8.0.0 (trunk 343487)

.text
.file "test.cpp"
.globl main
.type main,@function
main:
.Lfunc_begin0:
 .file 0 "/home/path" "test.cpp" md5 0x8ed32099ab837bd13543fd3e8102739f
 .file 1 "test.cpp" md5 0x8ed32099ab837bd13543fd3e8102739f
 .loc 1 3 10 prologue_end
 jmp _Z3foov
.Lfunc_end0:

.Lstr_offsets_base0:
.section .debug_str,"MS",@progbits,1
 .asciz "stub"

.section .debug_str_offsets,"",@progbits
 .long 0

.section .debug_abbrev,"",@progbits
 .byte 1                           # Abbreviation Code
 .byte 17                          # DW_TAG_compile_unit
 .byte 0                           # DW_CHILDREN_yes
 .byte 37                          # DW_AT_producer
 .byte 37                          # DW_FORM_strx1
 .byte 19                          # DW_AT_language
 .byte 5                           # DW_FORM_data2
 .byte 3                           # DW_AT_name
 .byte 37                          # DW_FORM_strx1
 .byte 114                         # DW_AT_str_offsets_base
 .byte 23                          # DW_FORM_sec_offset
 .byte 16                          # DW_AT_stmt_list
 .byte 23                          # DW_FORM_sec_offset
 .byte 27                          # DW_AT_comp_dir
 .byte 37                          # DW_FORM_strx1
 .byte 17                          # DW_AT_low_pc
 .byte 1                           # DW_FORM_addr
 .byte 18                          # DW_AT_high_pc
 .byte 6                           # DW_FORM_data4
 .byte 0                           # EOM(1)
 .byte 0                           # EOM(2)

 .byte 2                           # Abbreviation Code
 .byte 46                          # DW_TAG_subprogram
 .byte 0                           # DW_CHILDREN_no
 .byte 17                          # DW_AT_low_pc
 .byte 1                           # DW_FORM_addr
 .byte 18                          # DW_AT_high_pc
 .byte 6                           # DW_FORM_data4
 .byte 64                          # DW_AT_frame_base
 .byte 24                          # DW_FORM_exprloc
 .byte 3                           # DW_AT_name
 .byte 37                          # DW_FORM_strx1
 .byte 58                          # DW_AT_decl_file
 .byte 11                          # DW_FORM_data1
 .byte 59                          # DW_AT_decl_line
 .byte 11                          # DW_FORM_data1
 .byte 73                          # DW_AT_type
 .byte 19                          # DW_FORM_ref4
 .byte 63                          # DW_AT_external
 .byte 25                          # DW_FORM_flag_present
 .byte 0                           # EOM(1)
 .byte 0                           # EOM(2)

 .byte 3                           # Abbreviation Code
 .byte 36                          # DW_TAG_base_type
 .byte 0                           # DW_CHILDREN_no
 .byte 3                           # DW_AT_name
 .byte 37                          # DW_FORM_strx1
 .byte 62                          # DW_AT_encoding
 .byte 11                          # DW_FORM_data1
 .byte 11                          # DW_AT_byte_size
 .byte 11                          # DW_FORM_data1
 .byte 0                           # EOM(1)
 .byte 0                           # EOM(2)
 .byte 0                           # EOM(3)

.section .debug_info,"",@progbits
.Lcu_begin0:
 .long 61                         # Length of Unit
 .short 5                         # DWARF version number
 .byte  1                         # DWARF Unit Type
 .byte  8                         # Address Size (in bytes)
 .long  .debug_abbrev             # Offset Into Abbrev. Section

 .byte  1                         # Abbrev [1] 0xc:0x35 DW_TAG_compile_unit
 .byte  0                         # DW_AT_producer
 .short 0                         # DW_AT_language
 .byte  0                         # DW_AT_name
 .long  .Lstr_offsets_base0       # DW_AT_str_offsets_base
 .long  .Lline_table_start0       # DW_AT_stmt_list
 .byte  0                         # DW_AT_comp_dir
 .quad  .Lfunc_begin0             # DW_AT_low_pc
 .long  .Lfunc_end0-.Lfunc_begin0 # DW_AT_high_pc
 
 .byte  2                         # Abbrev [2] 0x26:0x16 DW_TAG_subprogram
 .quad  .Lfunc_begin0             # DW_AT_low_pc
 .long  .Lfunc_end0-.Lfunc_begin0 # DW_AT_high_pc
 .byte  1                         # DW_AT_frame_base
 .byte  87
 .byte  0                         # DW_AT_name
 .byte  1                         # DW_AT_decl_file
 .byte  2                         # DW_AT_decl_line
 .long  60                        # DW_AT_type
                                  # DW_AT_external

 .byte  3                         # Abbrev [3] 0x3c:0x4 DW_TAG_base_type
 .byte  0                         # DW_AT_name
 .byte  5                         # DW_AT_encoding
 .byte  4                         # DW_AT_byte_size
 .byte  0                         # End Of Children Mark

.section .debug_line,"",@progbits
.Lline_table_start0:
