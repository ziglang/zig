# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: ld.lld --gdb-index %t.o %t.o -o %t

## .debug_info has a relocation to .text.foo . The second %t.o is discarded.
## Check we don't error on the relocation.
# CHECK: .rela.debug_info {
# CHECK-NEXT: 0xC R_X86_64_64 .text.foo 0x0

.section .text.foo,"axG",@progbits,foo,comdat
.globl foo
.Lfunc_begin0:
foo:
  ret
.Lfunc_end0:

.section .debug_abbrev,"",@progbits
  .byte   1       # Abbreviation Code
  .byte   17      # DW_TAG_compile_unit
  .byte   1       # DW_CHILDREN_yes
  .byte   17      # DW_AT_low_pc
  .byte   1       # DW_FORM_addr
  .byte   18      # DW_AT_high_pc
  .byte   6       # DW_FORM_data4
  .ascii  "\264B" # DW_AT_GNU_pubnames
  .byte   25      # DW_FORM_flag_present
  .byte   0       # EOM(1)
  .byte   0       # EOM(2)
  .byte   2       # Abbreviation Code
  .byte   46      # DW_TAG_subprogram
  .byte   0       # DW_CHILDREN_no
  .byte   3       # DW_AT_name
  .byte   8       # DW_FORM_string
  .byte   0       # EOM(1)
  .byte   0       # EOM(2)
  .byte   0

.section .debug_info,"",@progbits
.Lcu_begin0:
  .long   .Lcu_end0 - .Lcu_begin0 - 4
  .short  4              # DWARF version number
  .long   0              # Offset Into Abbrev. Section
  .byte   4              # Address Size
.Ldie0:
  .byte   1              # Abbrev [1] DW_TAG_compile_unit
  .quad   .Lfunc_begin0  # DW_AT_low_pc
  .long   .Lfunc_end0 - .Lfunc_begin0 # DW_AT_high_pc
  .byte   2              # Abbrev [2] DW_TAG_subprogram
  .asciz  "foo"          # DW_AT_name
  .byte   0
.Lcu_end0:

.section .debug_gnu_pubnames,"",@progbits
  .long   .LpubNames_end0 - .LpubNames_begin0
.LpubNames_begin0:
  .short  2              # Version
  .long   .Lcu_begin0    # CU Offset
  .long   .Lcu_end0 - .Lcu_begin0
  .long   .Ldie0 - .Lcu_begin0
  .byte   48             # Attributes: FUNCTION, EXTERNAL
  .asciz  "foo"          # External Name
  .long   0
.LpubNames_end0:
