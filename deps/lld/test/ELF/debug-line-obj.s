# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux -dwarf-version=5 %s -o %t.o
# RUN: not ld.lld %t.o -o %t1 2>&1 | FileCheck %s

# When compiling with -ffunction-sections, .debug_line may contain descriptions
# of locations from the different text sections. Until relocated such
# descriptions might contain overlapping offsets. Check LLD is able to report
# the error locations correctly in this case.

# CHECK:      error: undefined symbol: foo()
# CHECK-NEXT: >>> referenced by test.cpp:2
# CHECK-NEXT: >>>               {{.*}}.o:(bar())
# CHECK-NEXT: >>> referenced by test.cpp:3
# CHECK-NEXT: >>>               {{.*}}.o:(baz())

# The code below is the reduced version of the output
# from the following invocation and source:
#
# // test.cpp:
# int foo();
# int bar() { return foo(); }
# int baz() { return foo(); }
#
# clang -gdwarf-5 -ffunction-sections test.cpp -o test.s -S

.text
.file  "test.cpp"
.section  .text._Z3barv,"ax",@progbits
.globl  _Z3barv
.type  _Z3barv,@function
_Z3barv:
.Lfunc_begin0:
  .file  0 "/path" "test.cpp" md5 0x9ff11a8404ab4d032ee2dd4f5f8c4140
  .loc  0 2 0                   # test.cpp:2:0
  .loc  0 2 20 prologue_end     # test.cpp:2:20
  callq  _Z3foov
  .loc  0 2 13 is_stmt 0        # test.cpp:2:13
.Lfunc_end0:
.size  _Z3barv, .Lfunc_end0-_Z3barv
                                        # -- End function
.section  .text._Z3bazv,"ax",@progbits
.globl  _Z3bazv                 # -- Begin function _Z3bazv
  .type  _Z3bazv,@function
_Z3bazv:                                # @_Z3bazv
.Lfunc_begin1:
  .loc  0 3 0 is_stmt 1         # test.cpp:3:0
  .loc  0 3 20 prologue_end     # test.cpp:3:20
  callq  _Z3foov
  .loc  0 3 13 is_stmt 0        # test.cpp:3:13
.Lfunc_end1:
  .size  _Z3bazv, .Lfunc_end1-_Z3bazv

.section  .debug_str,"MS",@progbits,1
.Linfo_string0:
  .asciz  "stub"

.section  .debug_str_offsets,"",@progbits
  .long  8
  .short  5
  .short  0
.Lstr_offsets_base0:
  .long  .Linfo_string0

.section  .debug_abbrev,"",@progbits
  .byte  1                       # Abbreviation Code
  .byte  17                      # DW_TAG_compile_unit
  .byte  1                       # DW_CHILDREN_yes
  .byte  37                      # DW_AT_producer
  .byte  37                      # DW_FORM_strx1
  .byte  19                      # DW_AT_language
  .byte  5                       # DW_FORM_data2
  .byte  3                       # DW_AT_name
  .byte  37                      # DW_FORM_strx1
  .byte  114                     # DW_AT_str_offsets_base
  .byte  23                      # DW_FORM_sec_offset
  .byte  16                      # DW_AT_stmt_list
  .byte  23                      # DW_FORM_sec_offset
  .byte  27                      # DW_AT_comp_dir
  .byte  37                      # DW_FORM_strx1
  .byte  115                     # DW_AT_addr_base
  .byte  23                      # DW_FORM_sec_offset
  .byte  17                      # DW_AT_low_pc
  .byte  1                       # DW_FORM_addr
  .byte  85                      # DW_AT_ranges
  .byte  35                      # DW_FORM_rnglistx
  .byte  116                     # DW_AT_rnglists_base
  .byte  23                      # DW_FORM_sec_offset
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)
  .byte  2                       # Abbreviation Code
  .byte  46                      # DW_TAG_subprogram
  .byte  0                       # DW_CHILDREN_no
  .byte  17                      # DW_AT_low_pc
  .byte  27                      # DW_FORM_addrx
  .byte  18                      # DW_AT_high_pc
  .byte  6                       # DW_FORM_data4
  .byte  64                      # DW_AT_frame_base
  .byte  24                      # DW_FORM_exprloc
  .byte  110                     # DW_AT_linkage_name
  .byte  37                      # DW_FORM_strx1
  .byte  3                       # DW_AT_name
  .byte  37                      # DW_FORM_strx1
  .byte  58                      # DW_AT_decl_file
  .byte  11                      # DW_FORM_data1
  .byte  59                      # DW_AT_decl_line
  .byte  11                      # DW_FORM_data1
  .byte  73                      # DW_AT_type
  .byte  19                      # DW_FORM_ref4
  .byte  63                      # DW_AT_external
  .byte  25                      # DW_FORM_flag_present
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)
  .byte  3                       # Abbreviation Code
  .byte  36                      # DW_TAG_base_type
  .byte  0                       # DW_CHILDREN_no
  .byte  3                       # DW_AT_name
  .byte  37                      # DW_FORM_strx1
  .byte  62                      # DW_AT_encoding
  .byte  11                      # DW_FORM_data1
  .byte  11                      # DW_AT_byte_size
  .byte  11                      # DW_FORM_data1
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)
  .byte  0                       # EOM(3)
 
.section  .debug_info,"",@progbits
.Lcu_begin0:
  .long  .Ldebug_info_end0-.Ldebug_info_start0 # Length of Unit
.Ldebug_info_start0:
  .short  5                       # DWARF version number
  .byte  1                       # DWARF Unit Type
  .byte  8                       # Address Size (in bytes)
  .long  .debug_abbrev           # Offset Into Abbrev. Section
  .byte  1                       # Abbrev [1] 0xc:0x44 DW_TAG_compile_unit
  .byte  0                       # DW_AT_producer
  .short  4                       # DW_AT_language
  .byte  0                       # DW_AT_name
  .long  .Lstr_offsets_base0     # DW_AT_str_offsets_base
  .long  .Lline_table_start0     # DW_AT_stmt_list
  .byte  2                       # DW_AT_comp_dir
  .long  0      # DW_AT_addr_base
  .quad  0                       # DW_AT_low_pc
  .byte  0                       # DW_AT_ranges
  .long  0  # DW_AT_rnglists_base
  .byte  2                       # Abbrev [2] 0x2b:0x10 DW_TAG_subprogram
  .byte  0                       # DW_AT_low_pc
  .long  .Lfunc_end0-.Lfunc_begin0 # DW_AT_high_pc
  .byte  1                       # DW_AT_frame_base
  .byte  86
  .byte  3                       # DW_AT_linkage_name
  .byte  0                       # DW_AT_name
  .byte  1                       # DW_AT_decl_file
  .byte  2                       # DW_AT_decl_line
  .long  75                      # DW_AT_type
                                        # DW_AT_external
  .byte  2                       # Abbrev [2] 0x3b:0x10 DW_TAG_subprogram
  .byte  1                       # DW_AT_low_pc
  .long  .Lfunc_end1-.Lfunc_begin1 # DW_AT_high_pc
  .byte  1                       # DW_AT_frame_base
  .byte  86
  .byte  6                       # DW_AT_linkage_name
  .byte  0                       # DW_AT_name
  .byte  1                       # DW_AT_decl_file
  .byte  3                       # DW_AT_decl_line
  .long  75                      # DW_AT_type
                                        # DW_AT_external
  .byte  3                       # Abbrev [3] 0x4b:0x4 DW_TAG_base_type
  .byte  0                       # DW_AT_name
  .byte  5                       # DW_AT_encoding
  .byte  4                       # DW_AT_byte_size
  .byte  0                       # End Of Children Mark
.Ldebug_info_end0:

.section  .debug_line,"",@progbits
.Lline_table_start0:
