# REQUIRES: x86
# RUN: llvm-mc -triple x86_64-windows-msvc %s -o %t.obj -filetype=obj
# RUN: lld-link %t.obj -out:%t.dll -dll -nodefaultlib -noentry
# RUN: llvm-nm %t.lib | FileCheck %s

# CHECK: export-weak-alias.s.tmp.dll:
# CHECK: 00000000 T __imp_foo_dll{{$}}
# CHECK: 00000000 T foo_dll{{$}}

	.text
	.def	 @feat.00;
	.scl	3;
	.type	0;
	.endef
	.globl	@feat.00
.set @feat.00, 0
	.file	"t.c"
	.def	 foo_def;
	.scl	2;
	.type	32;
	.endef
	.globl	foo_def                 # -- Begin function foo_def
	.p2align	4, 0x90
foo_def:                                # @foo_def
# %bb.0:                                # %entry
	movl	$42, %eax
	retq
                                        # -- End function
	.section	.drectve,"yn"
	.ascii	" /alternatename:foo=foo_def"
	.ascii	" /export:foo_dll=foo"

	.addrsig
