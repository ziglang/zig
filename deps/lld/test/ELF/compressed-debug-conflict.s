# REQUIRES: x86, zlib
# RUN: llvm-mc -filetype=obj -triple i686-linux-gnu -compress-debug-sections=zlib %s -o %t.o
# RUN: llvm-readobj -sections %t.o | FileCheck -check-prefix=OBJ %s
# RUN: not ld.lld %t.o %t.o -o /dev/null 2>&1 | FileCheck -check-prefix=ERROR %s

# OBJ:      Sections [
# OBJ:        Section {
# OBJ:          Index:
# OBJ:          Name: .debug_line
# OBJ-NEXT:     Type: SHT_PROGBITS
# OBJ-NEXT:     Flags [
# OBJ-NEXT:       SHF_COMPRESSED
# OBJ-NEXT:     ]

# ERROR:      error: duplicate symbol: main
# ERROR-NEXT: >>> defined at reduced.c:2 (/tmp/reduced.c:2)
# ERROR-NEXT: >>>
# ERROR-NEXT: >>> defined at reduced.c:2 (/tmp/reduced.c:2)
# ERROR-NEXT: >>>

	.text
	.file	"reduced.c"
	.globl	main
main:
	.file	1 "/tmp" "reduced.c"
	.loc	1 2 0
	xorl	%eax, %eax
	retl
	.file	2 "/tmp/repeat/repeat/repeat/repeat" "repeat.h"

	.section	.debug_abbrev,"",@progbits
	.byte	1                       # Abbreviation Code
	.byte	17                      # DW_TAG_compile_unit
	.byte	0                       # DW_CHILDREN_no
	.byte	16                      # DW_AT_stmt_list
	.byte	23                      # DW_FORM_sec_offset
	.byte	0                       # EOM(1)
	.byte	0                       # EOM(2)
	.byte	0                       # EOM(3)

        .section	.debug_info,"",@progbits
	.long	.Lend0 - .Lbegin0       # Length of Unit
.Lbegin0:
	.short	4                       # DWARF version number
	.long	.debug_abbrev           # Offset Into Abbrev. Section
	.byte	4                       # Address Size (in bytes)
	.byte	1                       # Abbrev [1] 0xb:0x1f DW_TAG_compile_unit
	.long	.debug_line             # DW_AT_stmt_list
.Lend0:
	.section	.debug_line,"",@progbits
