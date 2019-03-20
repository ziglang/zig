.globl _start
_start:

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
.Ldie:
	.byte	1              # Abbrev [1] DW_TAG_compile_unit
	.byte	2              # Abbrev [2] DW_TAG_subprogram
	.asciz	"_start"       # DW_AT_name
	.byte	0
.Lcu_end0:

# .debug_gnu_pubnames has just one set, associated with .Lcu_begin1 (CuIndex: 1)
.section .debug_gnu_pubnames,"",@progbits
	.long	.LpubNames_end0 - .LpubNames_begin0
.LpubNames_begin0:
	.short	2              # Version
	.long	.Lcu_begin0    # CU Offset
	.long	.Lcu_end0 - .Lcu_begin0
	.long	.Ldie - .Lcu_begin0
	.byte	48             # Attributes: FUNCTION, EXTERNAL
	.asciz	"_start"       # External Name
	.long	0
.LpubNames_end0:
