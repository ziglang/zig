// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: llvm-readelf -r %t.so | FileCheck --check-prefix=OutputRelocs %s
// RUN: llvm-objdump --section-headers %t.so | FileCheck --check-prefix=CheckGot %s
// RUN: llvm-objdump -d %t.so | FileCheck --check-prefix=Dis %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: llvm-readelf -r %t.so | FileCheck --check-prefix=OutputRelocs %s
// RUN: llvm-objdump --section-headers %t.so | FileCheck --check-prefix=CheckGot %s
// RUN: llvm-objdump -d %t.so | FileCheck --check-prefix=Dis %s

	.text
	.abiversion 2
	.globl	test
	.p2align	4
	.type	test,@function
test:
.Lfunc_gep0:
	addis 2, 12, .TOC.-.Lfunc_gep0@ha
	addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
	.localentry	test, .Lfunc_lep0-.Lfunc_gep0
	mflr 0
	std 31, -8(1)
	std 0, 16(1)
	stdu 1, -48(1)
	mr 31, 1
	std 30, 32(31)
	addis 3, 2, i@got@tlsgd@ha
	addi 3, 3, i@got@tlsgd@l
	bl __tls_get_addr(i@tlsgd)
	nop
	lwz 30, 0(3)
	extsw 3, 30
	ld 30, 32(31)
	addi 1, 1, 48
	ld 0, 16(1)
	ld 31, -8(1)
	mtlr 0
	blr


test_hi:
.Lfunc_gep1:
  addis 2, 12, .TOC.-.Lfunc_gep1@ha
  addi  2, 2,  .TOC.-.Lfunc_gep1@l
.Lfunc_lep1:
  .localentry test2, .Lfunc_lep1-.Lfunc_gep1
  addis 3, 0, j@got@tlsgd@h
  blr

test_16:
.Lfunc_gep2:
  addis 2, 12, .TOC.-.Lfunc_gep2@ha
  addi 2, 2, .TOC.-.Lfunc_gep2@l
.Lfunc_lep2:
  .localentry test16, .Lfunc_lep2-.Lfunc_gep2
  addi 3, 0, k@got@tlsgd
  blr

// Verify that the input has every general-dynamic tls relocation type.
// InputRelocs:  Relocation section '.rela.text'
// InputRelocs: R_PPC64_GOT_TLSGD16_HA  {{0+}}  i + 0
// InputRelocs: R_PPC64_GOT_TLSGD16_LO  {{0+}}  i + 0
// InputRelocs: R_PPC64_TLSGD           {{0+}}  i + 0
// InputRelocs: R_PPC64_GOT_TLSGD16_HI  {{0+}}  j + 0
// InputRelocs: R_PPC64_GOT_TLSGD16     {{0+}}  k + 0

// There is 2 got entries for each tls variable that is accessed with the
// general-dynamic model.  The entries can be though of as a structure to be
// filled in by the dynamic linker:
// typedef struct {
//  unsigned long int ti_module; --> R_PPC64_DTPMOD64
//  unsigned long int ti_offset; --> R_PPC64_DTPREL64
//} tls_index;
// OutputRelocs: Relocation section '.rela.dyn' at offset 0x{{[0-9a-f]+}} contains 6 entries:
// OutputRelocs: R_PPC64_DTPMOD64  {{0+}}  i + 0
// OutputRelocs: R_PPC64_DTPREL64  {{0+}}  i + 0
// OutputRelocs: R_PPC64_DTPMOD64  {{0+}}  j + 0
// OutputRelocs: R_PPC64_DTPREL64  {{0+}}  j + 0
// OutputRelocs: R_PPC64_DTPMOD64  {{0+}}  k + 0
// OutputRelocs: R_PPC64_DTPREL64  {{0+}}  k + 0

// Check that the got has 7 entires. (1 for the TOC and 3 structures of
// 2 entries for the tls variables). Also verify the address so we can check
// the offsets we calculated for each relocation type.
// CheckGot: got          00000038 00000000000200f0

// got starts at 0x200f0, so .TOC. will be 0x280f0.

// We are building the address of the first tls_index in the got which starts at
// 0x200f8 (got[1]).
// #ha(i@got@tlsgd) --> (0x200f8 - 0x280f0 + 0x8000) >> 16 = 0
// #lo(i@got@tlsgd) --> (0x200f8 - 0x280f0) & 0xFFFF =  -7ff8 = -32760
// Dis:  test:
// Dis:    addis 3, 2, 0
// Dis:    addi 3, 3, -32760

// Second tls_index starts at got[3].
// #hi(j@got@tlsgd) --> (0x20108 - 0x280f0) >> 16 = -1
// Dis: test_hi:
// Dis:   lis 3, -1

// Third tls index is at got[5].
// k@got@tlsgd --> (0x20118 -  0x280f0) = -0x7fd8 = -32728
// Dis: test_16:
// Dis:   li 3, -32728
