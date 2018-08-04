// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: ld.lld -shared -z notext %t.o -o %t.so
// RUN: llvm-readelf -dyn-relocations %t.so | FileCheck %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: ld.lld -shared -z notext %t.o -o %t.so
// RUN: llvm-readelf -dyn-relocations %t.so | FileCheck %s


// CHECK-NOT: foo
// CHECK-NOT: bar

	.text
	.abiversion 2
	.globl	baz
	.p2align	4
	.type	baz,@function
baz:
.Lfunc_begin0:
.Lfunc_gep0:
	addis 2, 12, .TOC.-.Lfunc_gep0@ha
	addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
	.localentry	baz, .Lfunc_lep0-.Lfunc_gep0
	mflr 0
	std 0, 16(1)
	stdu 1, -64(1)
	std 30, 48(1)
	std 29, 40(1)
	mr 30, 3
	bl foo
	mr 29, 3
	mr 3, 30
	bl bar
	mullw 3, 3, 29
	ld 30, 48(1)
	ld 29, 40(1)
	extsw 3, 3
	addi 1, 1, 64
	ld 0, 16(1)
	mtlr 0
	blr
	.long	0
	.quad	0
.Lfunc_end0:
	.size	baz, .Lfunc_end0-.Lfunc_begin0

	.p2align	4
	.type	foo,@function
foo:
.Lfunc_begin1:
	mullw 3, 3, 3
	extsw 3, 3
	blr
	.long	0
	.quad	0
.Lfunc_end1:
	.size	foo, .Lfunc_end1-.Lfunc_begin1

        .p2align	4
	.type	bar,@function
bar:
.Lfunc_begin2:
.Lfunc_gep2:
	addis 2, 12, .TOC.-.Lfunc_gep2@ha
	addi 2, 2, .TOC.-.Lfunc_gep2@l
.Lfunc_lep2:
	.localentry	bar, .Lfunc_lep2-.Lfunc_gep2
	mflr 0
	std 0, 16(1)
	stdu 1, -48(1)
	std 30, 32(1)
	mr 30, 3
	bl foo
	mullw 3, 3, 30
	ld 30, 32(1)
	extsw 3, 3
	addi 1, 1, 48
	ld 0, 16(1)
	mtlr 0
	blr
	.long	0
	.quad	0
.Lfunc_end2:
	.size	bar, .Lfunc_end2-.Lfunc_begin2
