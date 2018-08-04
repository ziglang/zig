# REQUIRES: x86

# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t.obj

# RUN: not lld-link -lldmingw -out:%t.exe -entry:main -subsystem:console %t.obj 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: other

# Check that the comdat section without a symbol isn't left pending once we iterate symbols
# to print source of the undefined symbol.

	.text
	.globl main
main:
	call other
	ret

	.section	.data$pending,"w"
	.linkonce	discard
.Llocal:
	.byte	0
