# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: ld.lld --gdb-index %t1.o -o %t
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s

# CHECK:      .gdb_index contents:
# CHECK:       Address area offset = 0x28, has 2 entries:
# CHECK-NEXT:  Low/High address = [0x201000, 0x201001) (Size: 0x1), CU id = 0
# CHECK-NEXT:  Low/High address = [0x201003, 0x201006) (Size: 0x3), CU id = 0

.text
.globl foo
.type foo,@function
foo:
.Lfunc_begin0:
  nop
.Ltmp0:
  nop
  nop
.Ltmp1:
  nop
  nop
  nop
.Ltmp2:

.section .debug_abbrev,"",@progbits
.byte 1                       # Abbreviation Code
.byte 17                      # DW_TAG_compile_unit
.byte 0                       # DW_CHILDREN_no
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
.byte 85                      # DW_AT_ranges
.byte 23                      # DW_FORM_sec_offset
.byte 0                       # EOM(1)
.byte 0                       # EOM(2)
.byte 0                       # EOM(3)

.section .debug_info,"",@progbits
.Lcu_begin0:
.long 38                      # Length of Unit
.short 4                      # DWARF version number
.long .debug_abbrev           # Offset Into Abbrev. Section
.byte 8                       # Address Size (in bytes)
.byte 1                       # Abbrev [1] 0xb:0x1f DW_TAG_compile_unit
.long 0                       # DW_AT_producer
.short 4                      # DW_AT_language
.long 0                       # DW_AT_name
.long 0                       # DW_AT_stmt_list
.long 0                       # DW_AT_comp_dir
.quad .Lfunc_begin0           # DW_AT_low_pc
.long .Ldebug_ranges0         # DW_AT_ranges

.section .debug_ranges,"",@progbits
.Ldebug_ranges0:
 .quad .Lfunc_begin0-.Lfunc_begin0
 .quad .Ltmp0-.Lfunc_begin0
 .quad .Ltmp1-.Lfunc_begin0
 .quad .Ltmp2-.Lfunc_begin0
 .quad 0
 .quad 0
