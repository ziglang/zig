# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --gdb-index %t.o -o %t
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s

# CHECK:       Address area offset = 0x28, has 1 entries:
# CHECK-NEXT:    Low/High address = [0x201000, 0x201001) (Size: 0x1), CU id = 0

  .text
  .globl main
main:                            # @main
.Lfunc_begin0:
  retq
.Lfunc_end0:
  .section  .debug_abbrev,"",@progbits
  .byte  1                       # Abbreviation Code
  .byte  17                      # DW_TAG_compile_unit
  .byte  0                       # DW_CHILDREN_no
  .byte  115                     # DW_AT_addr_base
  .byte  23                      # DW_FORM_sec_offset
  .byte  17                      # DW_AT_low_pc
  .byte  27                      # DW_FORM_addrx
  .byte  18                      # DW_AT_high_pc
  .byte  6                       # DW_FORM_data4
  .byte  0                       # EOM(1)
  .byte  0                       # EOM(2)
  .byte  0                       # EOM(3)
  
  .section  .debug_info,"",@progbits
.Lcu_begin0:
  .long  .Ldebug_info_end0-.Ldebug_info_start0 # Length of Unit
.Ldebug_info_start0:
  .short  5                      # DWARF version number
  .byte  1                       # DWARF Unit Type
  .byte  8                       # Address Size (in bytes)
  .long  .debug_abbrev           # Offset Into Abbrev. Section
  .byte  1                       # Abbrev [1] 0xc:0x2b DW_TAG_compile_unit
  .long  .Laddr_table_base0      # DW_AT_addr_base
  .byte  0                       # DW_AT_low_pc
  .long  .Lfunc_end0-.Lfunc_begin0 # DW_AT_high_pc
.Ldebug_info_end0:

  .section  .debug_addr,"",@progbits
  .long  12
  .short  5
  .byte  8
  .byte  0
.Laddr_table_base0:
  .quad  .Lfunc_begin0
