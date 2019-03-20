# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/gdb-index-multiple-cu-2.s -o %t1.o
# RUN: ld.lld --gdb-index %t.o %t1.o -o %t
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s

# %t.o has 2 CUs while %t1 has 1, thus _start in %t1.o should have CuIndex 2.
# Attributes << 24 | CuIndex = 48 << 24 | 2 = 0x30000002
# CHECK:      Constant pool
# CHECK-NEXT:   0(0x0): 0x30000002

.section .debug_abbrev,"",@progbits
	.byte	1              # Abbreviation Code
	.byte	17             # DW_TAG_compile_unit
	.byte	0              # DW_CHILDREN_yes
	.byte	0              # EOM(1)
	.byte	0              # EOM(2)
	.byte	0

.section .debug_info,"",@progbits
.Lcu_begin0:
	.long	.Lcu_end0 - .Lcu_begin0 - 4
	.short	4              # DWARF version number
	.long	0              # Offset Into Abbrev. Section
	.byte	4              # Address Size
	.byte	1              # Abbrev [1] DW_TAG_compile_unit
	.byte	0
.Lcu_end0:
.Lcu_begin1:
	.long	.Lcu_end1 - .Lcu_begin1 - 4
	.short	4              # DWARF version number
	.long	0              # Offset Into Abbrev. Section
	.byte	4              # Address Size
	.byte	1              # Abbrev [1] DW_TAG_compile_unit
	.byte	0
.Lcu_end1:
