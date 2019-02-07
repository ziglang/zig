// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: ld.lld  %t.o -o %t
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=Dis %s
// RUN: llvm-readelf -r %t | FileCheck --check-prefix=OutputRelocs %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: ld.lld  %t.o -o %t
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=Dis %s
// RUN: llvm-readelf -r %t | FileCheck --check-prefix=OutputRelocs %s

	.text
	.abiversion 2
	.globl	_start                    # -- Begin function _start
	.p2align	4
	.type	_start,@function
_start:                                   # @_start
.Lfunc_begin0:
.Lfunc_gep0:
	addis 2, 12, .TOC.-.Lfunc_gep0@ha
	addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
	.localentry	_start, .Lfunc_lep0-.Lfunc_gep0
# %bb.0:                                # %entry
	mflr 0
	std 31, -8(1)
	std 0, 16(1)
	stdu 1, -64(1)
	mr 31, 1
	std 30, 48(31)                  # 8-byte Folded Spill
	li 3, 0
	stw 3, 44(31)
	addis 3, 2, a@got@tlsgd@ha
	addi 3, 3, a@got@tlsgd@l
	bl __tls_get_addr(a@tlsgd)
	nop
	lwz 30, 0(3)
	extsw 3, 30
	ld 30, 48(31)                   # 8-byte Folded Reload
	addi 1, 1, 64
	ld 0, 16(1)
	ld 31, -8(1)
	mtlr 0
	blr
	.long	0
	.quad	0
.Lfunc_end0:
	.size	_start, .Lfunc_end0-.Lfunc_begin0

.globl __tls_get_addr
.type __tls_get_addr,@function
__tls_get_addr:

                                        # -- End function
	.type	a,@object               # @a
	.section	.tdata,"awT",@progbits
	.globl	a
	.p2align	2
a:
	.long	55                      # 0x37
	.size	a, 4

// Verify that the input has general-dynamic tls relocation types
// InputRelocs:  Relocation section '.rela.text'
// InputRelocs: R_PPC64_GOT_TLSGD16_HA  {{0+}}  a + 0
// InputRelocs: R_PPC64_GOT_TLSGD16_LO  {{0+}}  a + 0
// InputRelocs: R_PPC64_TLSGD           {{0+}}  a + 0

// Verify that the general-dynamic sequence is  relaxed to local exec.
// #ha(a@tprel) --> (0 - 0x7000 + 0x8000) >> 16 = 0
// #lo(a@tprel)) --> (0 - 0x7000) &  0xFFFF =  -0x7000 = -28672
// Dis: _start:
// Dis: nop
// Dis: addis 3, 13, 0
// Dis: nop
// Dis: addi 3, 3, -28672

// Verify that no general-dynamic relocations exist for the dynamic linker.
// OutputRelocs-NOT: R_PPC64_DTPMOD64
// OutputRelocs-NOT: R_PPC64_DTPREL64
