// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: not ld.lld --vs-diagnostics %t1.o -o %tout 2>&1 \
// RUN:   | FileCheck -check-prefix=ERR -check-prefix=CHECK %s
// RUN: ld.lld --vs-diagnostics --warn-unresolved-symbols %t1.o -o %tout 2>&1 \
// RUN:   | FileCheck -check-prefix=WARN -check-prefix=CHECK %s

// ERR:        undef3.s(15): error: undefined symbol: foo
// WARN:       undef3.s(15): warning: undefined symbol: foo
// CHECK:      >>> referenced by undef3.s:15
// CHECK-NEXT: >>> {{.*}}1.o:(.text+0x{{.+}})

.file 1 "undef3.s"

.global _start, foo
.text
_start:
.loc 1 15
  jmp foo

.section .debug_abbrev,"",@progbits
  .byte  1                      # Abbreviation Code
  .byte 17                      # DW_TAG_compile_unit
  .byte  0                      # DW_CHILDREN_no
  .byte 16                      # DW_AT_stmt_list
  .byte 23                      # DW_FORM_sec_offset
  .byte  0                      # EOM(1)
  .byte  0                      # EOM(2)
  .byte  0                      # EOM(3)

.section .debug_info,"",@progbits
  .long .Lend0 - .Lbegin0       # Length of Unit
.Lbegin0:
  .short 4                      # DWARF version number
  .long  .debug_abbrev          # Offset Into Abbrev. Section
  .byte  8                      # Address Size (in bytes)
  .byte  1                      # Abbrev [1] 0xb:0x1f DW_TAG_compile_unit
  .long  .debug_line            # DW_AT_stmt_list
.Lend0:
  .section .debug_line,"",@progbits
