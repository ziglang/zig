# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: ld.lld --gdb-index %t1.o -o %t
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s

## The code contains DWARF v5 sections .debug_rnglists and .debug_addr.
## Check we are able to build the correct address
## area using address range lists.

# CHECK:      .gdb_index contents:
# CHECK:      Address area offset = 0x28, has 2 entries:
# CHECK-NEXT:  Low/High address = [0x201000, 0x201001) (Size: 0x1), CU id = 0
# CHECK-NEXT:  Low/High address = [0x201001, 0x201003) (Size: 0x2), CU id = 0

.text
.section .text._Z3zedv,"ax",@progbits
.Lfunc_begin0:
  retq
.Lfunc_end0:

.section .text.main,"ax",@progbits
.Lfunc_begin1:
 retq
 retq
.Lfunc_end1:

.section .debug_str_offsets,"",@progbits
.long 32
.short 5
.short 0
.Lstr_offsets_base0:
 .long .Linfo_string0
 .long .Linfo_string0
 .long .Linfo_string0
 .long .Linfo_string0
 .long .Linfo_string0
 .long .Linfo_string0
 .long .Linfo_string0

.section .debug_str,"MS",@progbits,1
.Linfo_string0:
 .asciz "stub"

.section .debug_abbrev,"",@progbits
  .byte  1                           # Abbreviation Code
  .byte  17                          # DW_TAG_compile_unit
  .byte  1                           # DW_CHILDREN_yes
  .byte  37                          # DW_AT_producer
  .byte  37                          # DW_FORM_strx1
  .byte  19                          # DW_AT_language
  .byte  5                           # DW_FORM_data2
  .byte  3                           # DW_AT_name
  .byte  37                          # DW_FORM_strx1
  .byte  114                         # DW_AT_str_offsets_base
  .byte  23                          # DW_FORM_sec_offset
  .byte  16                          # DW_AT_stmt_list
  .byte  23                          # DW_FORM_sec_offset
  .byte  27                          # DW_AT_comp_dir
  .byte  37                          # DW_FORM_strx1
  .byte  115                         # DW_AT_addr_base
  .byte  23                          # DW_FORM_sec_offset
  .byte  17                          # DW_AT_low_pc
  .byte  1                           # DW_FORM_addr
  .byte  85                          # DW_AT_ranges
  .byte  35                          # DW_FORM_rnglistx
  .byte  116                         # DW_AT_rnglists_base
  .byte  23                          # DW_FORM_sec_offset
  .byte  0                           # EOM(1)
  .byte  0                           # EOM(2)
  .byte  2                           # Abbreviation Code
  .byte  46                          # DW_TAG_subprogram
  .byte  0                           # DW_CHILDREN_no
  .byte  17                          # DW_AT_low_pc
  .byte  27                          # DW_FORM_addrx
  .byte  18                          # DW_AT_high_pc
  .byte  6                           # DW_FORM_data4
  .byte  64                          # DW_AT_frame_base
  .byte  24                          # DW_FORM_exprloc
  .byte  110                         # DW_AT_linkage_name
  .byte  37                          # DW_FORM_strx1
  .byte  3                           # DW_AT_name
  .byte  37                          # DW_FORM_strx1
  .byte  58                          # DW_AT_decl_file
  .byte  11                          # DW_FORM_data1
  .byte  59                          # DW_AT_decl_line
  .byte  11                          # DW_FORM_data1
  .byte  73                          # DW_AT_type
  .byte  19                          # DW_FORM_ref4
  .byte  63                          # DW_AT_external
  .byte  25                          # DW_FORM_flag_present
  .byte  0                           # EOM(1)
  .byte  0                           # EOM(2)
  .byte  3                           # Abbreviation Code
  .byte  46                          # DW_TAG_subprogram
  .byte  0                           # DW_CHILDREN_no
  .byte  17                          # DW_AT_low_pc
  .byte  27                          # DW_FORM_addrx
  .byte  18                          # DW_AT_high_pc
  .byte  6                           # DW_FORM_data4
  .byte  64                          # DW_AT_frame_base
  .byte  24                          # DW_FORM_exprloc
  .byte  3                           # DW_AT_name
  .byte  37                          # DW_FORM_strx1
  .byte  58                          # DW_AT_decl_file
  .byte  11                          # DW_FORM_data1
  .byte  59                          # DW_AT_decl_line
  .byte  11                          # DW_FORM_data1
  .byte  73                          # DW_AT_type
  .byte  19                          # DW_FORM_ref4
  .byte  63                          # DW_AT_external
  .byte  25                          # DW_FORM_flag_present
  .byte  0                           # EOM(1)
  .byte  0                           # EOM(2)
  .byte  4                           # Abbreviation Code
  .byte  36                          # DW_TAG_base_type
  .byte  0                           # DW_CHILDREN_no
  .byte  3                           # DW_AT_name
  .byte  37                          # DW_FORM_strx1
  .byte  62                          # DW_AT_encoding
  .byte  11                          # DW_FORM_data1
  .byte  11                          # DW_AT_byte_size
  .byte  11                          # DW_FORM_data1
  .byte  0                           # EOM(1)
  .byte  0                           # EOM(2)
  .byte  0                           # EOM(3)

.section .debug_info,"",@progbits
.Lcu_begin0:
  .long  75                          # Length of Unit
  .short 5                           # DWARF version number
  .byte  1                           # DWARF Unit Type
  .byte  8                           # Address Size (in bytes)
  .long  .debug_abbrev               # Offset Into Abbrev. Section
  
  .byte  1                           # Abbrev [1] 0xc:0x43 DW_TAG_compile_unit
  .byte  0                           # DW_AT_producer
  .short 4                           # DW_AT_language
  .byte  1                           # DW_AT_name
  .long  .Lstr_offsets_base0         # DW_AT_str_offsets_base
  .long  0                           # DW_AT_stmt_list
  .byte  2                           # DW_AT_comp_dir
  .long  .Laddr_table_base0          # DW_AT_addr_base
  .quad  0                           # DW_AT_low_pc
  .byte  0                           # DW_AT_ranges
  .long  .Lrnglists_table_base0      # DW_AT_rnglists_base

  .byte 2                            # Abbrev [2] 0x2b:0x10 DW_TAG_subprogram
  .byte 0                            # DW_AT_low_pc
  .long .Lfunc_end0-.Lfunc_begin0    # DW_AT_high_pc
  .byte 1                            # DW_AT_frame_base
  .byte 86
  .byte 3                            # DW_AT_linkage_name
  .byte 4                            # DW_AT_name
  .byte 1                            # DW_AT_decl_file
  .byte 1                            # DW_AT_decl_line
  .long 74                           # DW_AT_type
                                     # DW_AT_external

  .byte  3                           # Abbrev [3] 0x3b:0xf DW_TAG_subprogram
  .byte  1                           # DW_AT_low_pc
  .long  .Lfunc_end1-.Lfunc_begin1   # DW_AT_high_pc
  .byte  1                           # DW_AT_frame_base
  .byte  86
  .byte  6                           # DW_AT_name
  .byte  1                           # DW_AT_decl_file
  .byte  5                           # DW_AT_decl_line
  .long  74                          # DW_AT_type
                                     # DW_AT_external

  .byte  4                           # Abbrev [4] 0x4a:0x4 DW_TAG_base_type
  .byte  5                           # DW_AT_name
  .byte  5                           # DW_AT_encoding
  .byte  4                           # DW_AT_byte_size
  .byte  0                           # End Of Children Mark

.section .debug_rnglists,"",@progbits
.long .Ldebug_rnglist_table_end0-.Ldebug_rnglist_table_start0 # Length
.Ldebug_rnglist_table_start0:        
  .short 5                           # Version
  .byte  8                           # Address size
  .byte  0                           # Segment selector size
  .long  1                           # Offset entry count
.Lrnglists_table_base0:
  .long .Ldebug_ranges0-.Lrnglists_table_base0
.Ldebug_ranges0:
  .byte 3                            # DW_RLE_startx_length
  .byte 0                            #   start index
  .uleb128 .Lfunc_end0-.Lfunc_begin0 #   length
  .byte 3                            # DW_RLE_startx_length
  .byte 1                            #   start index
  .uleb128 .Lfunc_end1-.Lfunc_begin1 #   length
  .byte 0                            # DW_RLE_end_of_list
.Ldebug_rnglist_table_end0:

.section .debug_addr,"",@progbits
  .long  20
  .short 5
  .byte  8
  .byte  0
.Laddr_table_base0:
  .quad .Lfunc_begin0
  .quad .Lfunc_begin1
