# REQUIRES: x86, zlib
# RUN: llvm-mc -filetype=obj -triple i686-linux-gnu -compress-debug-sections=zlib %s -o %t.o
# RUN: llvm-readobj -sections %t.o | FileCheck -check-prefix=OBJ %s
# RUN: not ld.lld %t.o %t.o -o %tout 2>&1 | FileCheck -check-prefix=ERROR %s

# OBJ:      Sections [
# OBJ:        Section {
# OBJ:          Index: 3
# OBJ-NEXT:     Name: .debug_line (16)
# OBJ-NEXT:     Type: SHT_PROGBITS (0x1)
# OBJ-NEXT:     Flags [ (0x800)
# OBJ-NEXT:       SHF_COMPRESSED (0x800)
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
