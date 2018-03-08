# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o

## Input is reduced from following code and invocation:
## clang++ -gsplit-dwarf -c test.ii -o test.s -S
## clang version: 6.0.0 (trunk 318293)
##
## test.ii:
## int a;
##
## Debug information does not contain any address ranges.
## We crashed in that case. Check we don't.
# RUN: ld.lld --gdb-index %t1.o -o %t

.section  .debug_str,"MS",@progbits,1
.Lskel_string0:
  .asciz  "t.dwo"
.Lskel_string1:
  .asciz  "path"

.section  .debug_abbrev,"",@progbits
  .byte  1                       # Abbreviation Code
  .byte  17                      # DW_TAG_compile_unit
  .byte  0                       # DW_CHILDREN_no
  .byte  16                      # DW_AT_stmt_list
  .byte  23                      # DW_FORM_sec_offset
  .ascii  "\260B"                # DW_AT_GNU_dwo_name
  .byte  14                      # DW_FORM_strp
  .byte  27                      # DW_AT_comp_dir
  .byte  14                      # DW_FORM_strp
  .ascii  "\261B"                # DW_AT_GNU_dwo_id
  .byte  7                       # DW_FORM_data8
  .ascii  "\263B"                # DW_AT_GNU_addr_base
  .byte  23                      # DW_FORM_sec_offset
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)
  .byte  0                       # EOM(3)

.section .debug_info,"",@progbits
  .long  32                      # Length of Unit
  .short  4                      # DWARF version number
  .long  .debug_abbrev           # Offset Into Abbrev. Section
  .byte  8                       # Address Size (in bytes)
  .byte  1                       # Abbrev [1] 0xb:0x19 DW_TAG_compile_unit
  .long  0                       # DW_AT_stmt_list
  .long  .Lskel_string0          # DW_AT_GNU_dwo_name
  .long  .Lskel_string1          # DW_AT_comp_dir
  .quad  -3824446529333676116    # DW_AT_GNU_dwo_id
  .long  0                       # DW_AT_GNU_addr_base
