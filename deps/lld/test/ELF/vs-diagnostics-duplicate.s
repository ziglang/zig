// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/vs-diagnostics-duplicate2.s -o %t2.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/vs-diagnostics-duplicate3.s -o %t3.o
// RUN: not ld.lld --vs-diagnostics %t1.o %t2.o %t3.o -o %tout 2>&1 | FileCheck %s

// Case 1. Both symbols have full source location.
// CHECK:      duplicate.s(15): error: duplicate symbol: bar
// CHECK-NEXT: >>> defined at duplicate.s:15
// CHECK-NEXT: >>>{{.*}}1.o:(.text+0x{{.+}})
// CHECK: >>> defined at duplicate2.s:20
// CHECK: >>>{{.*}}2.o:(.text+0x{{.+}})

// Case 2. The source locations are unknown for both symbols.
// CHECK:      {{.*}}ld.lld{{.*}}: error: duplicate symbol: foo
// CHECK-NEXT: >>> defined at {{.*}}1.o:(.text+0x{{.+}})
// CHECK-NEXT: >>> defined at {{.*}}2.o:(.text+0x{{.+}})

// Case 3. For the second definition of `baz` we know only the source file found in a STT_FILE symbol.
// CHECK:      duplicate.s(30): error: duplicate symbol: baz
// CHECK-NEXT: >>> defined at duplicate.s:30
// CHECK-NEXT: >>> {{.*}}1.o:(.text+0x{{.+}})
// CHECK-NEXT: >>> defined at duplicate3.s
// CHECK-NEXT: >>>            {{.*}}3.o:(.text+0x{{.+}})

.global _start, foo, bar, baz
.text
_start:
  nop

foo:
  nop

.file 1 "duplicate.s"
.loc 1 15

bar:
  nop

.loc 1 30
baz:
  nop

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
