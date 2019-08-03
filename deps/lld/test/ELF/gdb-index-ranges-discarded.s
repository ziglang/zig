# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: ld.lld --gdb-index -e main %t.o -o %t
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s

# CHECK:      .gdb_index contents:
# CHECK:       Address area offset = 0x28, has 1 entries:
# CHECK-NEXT:    Low/High address = [0x201000, 0x201001) (Size: 0x1), CU id = 0

## .debug_ranges contains 2 entries. .Lfunc_end0 is defined in the discarded
## .text.foo. Test we resolve it to a non-zero value, otherwise the address area
## of .gdb_index will not included [.Lfunc_begin1, .Lfunc_end1).

.section .text.foo,"aex",@progbits
.Lfunc_begin0:
  ret
.Lfunc_end0:

.section .text.bar,"ax",@progbits
.Lfunc_begin1:
  ret
.Lfunc_end1:

.section .debug_abbrev,"",@progbits
  .byte 1         # Abbreviation Code
  .byte 17        # DW_TAG_compile_unit
  .byte 0         # DW_CHILDREN_no
  .byte 85        # DW_AT_ranges
  .byte 23        # DW_FORM_sec_offset
  .byte 0         # EOM(1)
  .byte 0         # EOM(2)
  .byte 0

.section .debug_info,"",@progbits
.Lcu_begin0:
  .long .Lcu_end0 - .Lcu_begin0 - 4
  .short 4        # DWARF version number
  .long  0        # Offset Into Abbrev. Section
  .byte  8        # Address Size
.Ldie0:
  .byte  1        # Abbrev [1] DW_TAG_compile_unit
  .long  0        # DW_AT_ranges
.Lcu_end0:

.section .debug_ranges,"",@progbits
  .quad .Lfunc_begin0
  .quad .Lfunc_end0
  .quad .Lfunc_begin1
  .quad .Lfunc_end1
  .quad 0
  .quad 0
