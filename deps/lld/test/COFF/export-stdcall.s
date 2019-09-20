# REQUIRES: x86
# RUN: llvm-mc -triple i686-windows-msvc %s -o %t.obj -filetype=obj
# RUN: lld-link -safeseh:no %t.obj -out:%t.dll -dll -nodefaultlib -noentry -export:foo_std=bar_std -export:foo_fast=bar_fast
# RUN: llvm-nm %t.lib | FileCheck %s

# MSVC fudges the lookup of 'bar' to allow it to find the stdcall function
# _bar_std@8, and then exports _foo_std@8. Same for fastcall and other mangling
# schemes.

# CHECK: export-stdcall.s.tmp.dll:
# CHECK: 00000000 T @foo_fast@8
# CHECK: 00000000 T __imp_@foo_fast@8

# CHECK: export-stdcall.s.tmp.dll:
# CHECK: 00000000 T __imp__foo_std@8
# CHECK: 00000000 T _foo_std@8

	.text
	.def	 _bar_std@8; .scl	2; .type	32; .endef
	.globl	_bar_std@8
_bar_std@8:
	movl	8(%esp), %eax
	movl	4(%esp), %ecx
	leal	42(%ecx,%eax), %eax
	retl	$8

	.def	 @bar_fast@8; .scl	2; .type	32; .endef
	.globl	@bar_fast@8
@bar_fast@8:
	leal	42(%ecx,%eax), %eax
	retl

