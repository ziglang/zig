# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld --gdb-index -e main %t.o -o %t 2>&1 | FileCheck %s
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/gdb-index-invalid-ranges.obj.s -o %t2.o
# RUN: llvm-ar rc %t.a %t.o
# RUN: not ld.lld --gdb-index -e main %t2.o %t.a -o %t 2>&1 | FileCheck --check-prefix=ARCHIVE %s

# CHECK: ld.lld: error: {{.*}}gdb-index-invalid-ranges.s.tmp.o:(.debug_info): decoding address ranges: invalid range list entry at offset 0x10
# ARCHIVE: ld.lld: error: {{.*}}gdb-index-invalid-ranges.s.tmp.a(gdb-index-invalid-ranges.s.tmp.o):(.debug_info): decoding address ranges: invalid range list entry at offset 0x10

.section .text.foo1,"ax",@progbits
.globl f1
.Lfunc_begin0:
f1:
 nop
.Lfunc_end0:

.section .debug_abbrev,"",@progbits
.byte 1                       # Abbreviation Code
.byte 17                      # DW_TAG_compile_unit
.byte 0                       # DW_CHILDREN_no
.byte 85                      # DW_AT_ranges
.byte 23                      # DW_FORM_sec_offset
.byte 0                       # EOM(1)
.byte 0                       # EOM(2)
.byte 0                       # EOM(3)

.section .debug_info,"",@progbits
.Lcu_begin0:
.long .Lunit_end0-.Lunit_begin0 # Length of Unit
.Lunit_begin0:
.short 4                      # DWARF version number
.long .debug_abbrev           # Offset Into Abbrev. Section
.byte 8                       # Address Size (in bytes)
.byte 1                       # Abbrev [1] 0xb:0x1f DW_TAG_compile_unit
.long .Ldebug_ranges0         # DW_AT_ranges
.Lunit_end0:

.section .debug_ranges,"",@progbits
.Ldebug_ranges0:
.quad .Lfunc_begin0
.quad .Lfunc_end0
