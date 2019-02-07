# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --gdb-index %t.o -o %t
# RUN: llvm-dwarfdump -gdb-index %t | FileCheck %s

# CuIndexAndAttrs of _start:
#   Attributes << 24 | CuIndex = 48 << 24 | 0 = 0x30000000
# CuIndexAndAttrs of foo:
#   Attributes << 24 | CuIndex = 48 << 24 | 1 = 0x30000001
# CHECK:      Symbol table
# CHECK-DAG:      String name: _start, CU vector index: 0
# CHECK-DAG:      String name: foo, CU vector index: 1
# CHECK:      Constant pool
# CHECK-NEXT:   0(0x0): 0x30000000
# CHECK-NEXT:   1(0x8): 0x30000001

.globl _start, foo
_start:
foo:

.section .debug_abbrev,"",@progbits
	.byte	1              # Abbreviation Code
	.byte	17             # DW_TAG_compile_unit
	.byte	1              # DW_CHILDREN_yes
	.ascii	"\264B"        # DW_AT_GNU_pubnames
	.byte	25             # DW_FORM_flag_present
	.byte	0              # EOM(1)
	.byte	0              # EOM(2)
	.byte	2              # Abbreviation Code
	.byte	46             # DW_TAG_subprogram
	.byte	0              # DW_CHILDREN_no
	.byte	3              # DW_AT_name
	.byte	8              # DW_FORM_string
	.byte	0              # EOM(1)
	.byte	0              # EOM(2)
	.byte	0

.section .debug_info,"",@progbits
.Lcu_begin0:
	.long	.Lcu_end0 - .Lcu_begin0 - 4
	.short	4              # DWARF version number
	.long	0              # Offset Into Abbrev. Section
	.byte	4              # Address Size
.Ldie0:
	.byte	1              # Abbrev [1] DW_TAG_compile_unit
	.byte	2              # Abbrev [2] DW_TAG_subprogram
	.asciz	"_start"       # DW_AT_name
	.byte	0
	.byte	0
.Lcu_end0:
.Lcu_begin1:
	.long	.Lcu_end1 - .Lcu_begin1 - 4
	.short	4              # DWARF version number
	.long	0              # Offset Into Abbrev. Section
	.byte	4              # Address Size
.Ldie1:
	.byte	1              # Abbrev [1] DW_TAG_compile_unit
	.byte	2              # Abbrev [2] DW_TAG_subprogram
	.asciz	"foo"          # DW_AT_name
	.byte	0
.Lcu_end1:

# Swap sets to test the case where pubnames are in a
# different order than the CUs they refer to.
.section .debug_gnu_pubnames,"",@progbits
	# CuIndex: 1
	.long	.LpubNames_end1 - .LpubNames_begin1
.LpubNames_begin1:
	.short	2              # Version
	.long	.Lcu_begin1    # CU Offset
	.long	.Lcu_end1 - .Lcu_begin1
	.long	.Ldie1 - .Lcu_begin1
	.byte	48             # Attributes: FUNCTION, EXTERNAL
	.asciz	"foo"          # External Name
	.long	0
.LpubNames_end1:

	# CuIndex: 0
	.long	.LpubNames_end0 - .LpubNames_begin0
.LpubNames_begin0:
	.short	2              # Version
	.long	.Lcu_begin0    # CU Offset
	.long	.Lcu_end0 - .Lcu_begin0
	.long	.Ldie0 - .Lcu_begin0
	.byte	48             # Attributes: FUNCTION, EXTERNAL
	.asciz	"_start"       # External Name
	.long	0
.LpubNames_end0:
