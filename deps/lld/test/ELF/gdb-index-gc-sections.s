# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux -o %t %s
# RUN: ld.lld --gdb-index --gc-sections -o %t2 %t
# RUN: llvm-dwarfdump -gdb-index %t2 | FileCheck %s

# CHECK: Address area offset = 0x28, has 1 entries:
# CHECK-NEXT:    Low/High address = [0x201000, 0x201001) (Size: 0x1), CU id = 0

# Generated with: (clang r302976)
# echo "void _start() {} void dead() {}" | \
# clang -Os -g -S -ffunction-sections -o gdb-index-gc-sections.s -x c - -Xclang -fdebug-compilation-dir -Xclang .

	.text
	.file	"-"
	.section	.text._start,"ax",@progbits
	.globl	_start
	.type	_start,@function
_start:                                 # @_start
.Lfunc_begin0:
	.file	1 "<stdin>"
	.loc	1 1 0                   # <stdin>:1:0
	.cfi_startproc
# BB#0:                                 # %entry
	.loc	1 1 16 prologue_end     # <stdin>:1:16
	retq
.Ltmp0:
.Lfunc_end0:
	.size	_start, .Lfunc_end0-_start
	.cfi_endproc

	.section	.text.dead,"ax",@progbits
	.globl	dead
	.type	dead,@function
dead:                                   # @dead
.Lfunc_begin1:
	.loc	1 1 0                   # <stdin>:1:0
	.cfi_startproc
# BB#0:                                 # %entry
	.loc	1 1 31 prologue_end     # <stdin>:1:31
	retq
.Ltmp1:
.Lfunc_end1:
	.size	dead, .Lfunc_end1-dead
	.cfi_endproc

	.section	.debug_str,"MS",@progbits,1
.Linfo_string0:
	.asciz	"clang version 5.0.0 "  # string offset=0
.Linfo_string1:
	.asciz	"-"                     # string offset=21
.Linfo_string2:
	.asciz	"."                     # string offset=23
.Linfo_string3:
	.asciz	"_start"                # string offset=25
.Linfo_string4:
	.asciz	"dead"                  # string offset=32
	.section	.debug_loc,"",@progbits
	.section	.debug_abbrev,"",@progbits
	.byte	1                       # Abbreviation Code
	.byte	17                      # DW_TAG_compile_unit
	.byte	1                       # DW_CHILDREN_yes
	.byte	37                      # DW_AT_producer
	.byte	14                      # DW_FORM_strp
	.byte	19                      # DW_AT_language
	.byte	5                       # DW_FORM_data2
	.byte	3                       # DW_AT_name
	.byte	14                      # DW_FORM_strp
	.byte	16                      # DW_AT_stmt_list
	.byte	23                      # DW_FORM_sec_offset
	.byte	27                      # DW_AT_comp_dir
	.byte	14                      # DW_FORM_strp
	.byte	17                      # DW_AT_low_pc
	.byte	1                       # DW_FORM_addr
	.byte	85                      # DW_AT_ranges
	.byte	23                      # DW_FORM_sec_offset
	.byte	0                       # EOM(1)
	.byte	0                       # EOM(2)
	.byte	2                       # Abbreviation Code
	.byte	46                      # DW_TAG_subprogram
	.byte	0                       # DW_CHILDREN_no
	.byte	17                      # DW_AT_low_pc
	.byte	1                       # DW_FORM_addr
	.byte	18                      # DW_AT_high_pc
	.byte	6                       # DW_FORM_data4
	.byte	64                      # DW_AT_frame_base
	.byte	24                      # DW_FORM_exprloc
	.byte	3                       # DW_AT_name
	.byte	14                      # DW_FORM_strp
	.byte	58                      # DW_AT_decl_file
	.byte	11                      # DW_FORM_data1
	.byte	59                      # DW_AT_decl_line
	.byte	11                      # DW_FORM_data1
	.byte	63                      # DW_AT_external
	.byte	25                      # DW_FORM_flag_present
	.byte	0                       # EOM(1)
	.byte	0                       # EOM(2)
	.byte	0                       # EOM(3)
	.section	.debug_info,"",@progbits
.Lcu_begin0:
	.long	81                      # Length of Unit
	.short	4                       # DWARF version number
	.long	.debug_abbrev           # Offset Into Abbrev. Section
	.byte	8                       # Address Size (in bytes)
	.byte	1                       # Abbrev [1] 0xb:0x4a DW_TAG_compile_unit
	.long	.Linfo_string0          # DW_AT_producer
	.short	12                      # DW_AT_language
	.long	.Linfo_string1          # DW_AT_name
	.long	.Lline_table_start0     # DW_AT_stmt_list
	.long	.Linfo_string2          # DW_AT_comp_dir
	.quad	0                       # DW_AT_low_pc
	.long	.Ldebug_ranges0         # DW_AT_ranges
	.byte	2                       # Abbrev [2] 0x2a:0x15 DW_TAG_subprogram
	.quad	.Lfunc_begin0           # DW_AT_low_pc
	.long	.Lfunc_end0-.Lfunc_begin0 # DW_AT_high_pc
	.byte	1                       # DW_AT_frame_base
	.byte	87
	.long	.Linfo_string3          # DW_AT_name
	.byte	1                       # DW_AT_decl_file
	.byte	1                       # DW_AT_decl_line
                                        # DW_AT_external
	.byte	2                       # Abbrev [2] 0x3f:0x15 DW_TAG_subprogram
	.quad	.Lfunc_begin1           # DW_AT_low_pc
	.long	.Lfunc_end1-.Lfunc_begin1 # DW_AT_high_pc
	.byte	1                       # DW_AT_frame_base
	.byte	87
	.long	.Linfo_string4          # DW_AT_name
	.byte	1                       # DW_AT_decl_file
	.byte	1                       # DW_AT_decl_line
                                        # DW_AT_external
	.byte	0                       # End Of Children Mark
	.section	.debug_ranges,"",@progbits
.Ldebug_ranges0:
	.quad	.Lfunc_begin0
	.quad	.Lfunc_end0
	.quad	.Lfunc_begin1
	.quad	.Lfunc_end1
	.quad	0
	.quad	0
	.section	.debug_macinfo,"",@progbits
.Lcu_macro_begin0:
	.byte	0                       # End Of Macro List Mark
	.section	.debug_pubnames,"",@progbits
	.long	.LpubNames_end0-.LpubNames_begin0 # Length of Public Names Info
.LpubNames_begin0:
	.short	2                       # DWARF Version
	.long	.Lcu_begin0             # Offset of Compilation Unit Info
	.long	85                      # Compilation Unit Length
	.long	42                      # DIE offset
	.asciz	"_start"                # External Name
	.long	63                      # DIE offset
	.asciz	"dead"                  # External Name
	.long	0                       # End Mark
.LpubNames_end0:

	.ident	"clang version 5.0.0 "
	.section	".note.GNU-stack","",@progbits
	.section	.debug_line,"",@progbits
.Lline_table_start0:
