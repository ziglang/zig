# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --gdb-index %t.o -o %t
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s

## Testcase is based on output produced by gcc version 5.4.1 20160904
## it has duplicate entries in .debug_gnu_pubtypes which seems to be
## compiler bug. In that case it is useless to have them in .gdb_index
## and we filter such entries out to reduce size of .gdb_index.

## CHECK: Constant pool offset = {{.*}}, has 1 CU vectors:
## CHECK-NOT: 0(0x0): 0x90000000 0x90000000

.section .debug_abbrev,"",@progbits
 .byte 1                       # Abbreviation Code
 .byte 17                      # DW_TAG_compile_unit
 .byte 0                       # DW_CHILDREN_no
 .byte 16                      # DW_AT_stmt_list
 .byte 23                      # DW_FORM_sec_offset
 .ascii "\260B"                # DW_AT_GNU_dwo_name
 .byte 14                      # DW_FORM_strp
 .byte 27                      # DW_AT_comp_dir
 .byte 14                      # DW_FORM_strp
 .ascii "\264B"                # DW_AT_GNU_pubnames
 .byte 25                      # DW_FORM_flag_present
 .ascii "\261B"                # DW_AT_GNU_dwo_id
 .byte 7                       # DW_FORM_data8
 .ascii "\263B"                # DW_AT_GNU_addr_base
 .byte 23                      # DW_FORM_sec_offset
 .byte 0                       # EOM(1)
 .byte 0                       # EOM(2)
 .byte 0                       # EOM(3)

.section .debug_info,"",@progbits
.Lcu_begin0:
 .long 32                       # Length of Unit
 .short 4                       # DWARF version number
 .long .debug_abbrev            # Offset Into Abbrev. Section
 .byte 8                        # Address Size (in bytes)
 .byte 1                        # Abbrev [1] 0xb:0x19 DW_TAG_compile_unit
 .long 0                        # DW_AT_stmt_list
 .long 0                        # DW_AT_GNU_dwo_name
 .long 0                        # DW_AT_comp_dir
 .quad 0                        # DW_AT_GNU_dwo_id
 .long 0                        # DW_AT_GNU_addr_base

.section .debug_gnu_pubtypes,"",@progbits
.long .LpubTypes_end0-.LpubTypes_begin0 # Length of Public Types Info
.LpubTypes_begin0:
 .short 2                      # DWARF Version
 .long .Lcu_begin0             # Offset of Compilation Unit Info
 .long 36                      # Compilation Unit Length
 .long 36                      # DIE offset
 .byte 144                     # Kind: TYPE, STATIC
 .asciz "int"                  # External Name
 .long 36                      # DIE offset
 .byte 144                     # Kind: TYPE, STATIC
 .asciz "int"                  # External Name
 .long 0                       # End Mark
.LpubTypes_end0:
