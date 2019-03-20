// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-tls.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld -dynamic-linker /lib64/ld64.so.2 %t.o %t2.so -o %t
// RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: llvm-readelf -r %t | FileCheck --check-prefix=OutputRelocs %s
// RUN: llvm-objdump --section-headers %t | FileCheck --check-prefix=CheckGot %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=Dis %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-tls.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld -dynamic-linker /lib64/ld64.so.2 %t.o %t2.so -o %t
// RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: llvm-readelf -r %t | FileCheck --check-prefix=OutputRelocs %s
// RUN: llvm-objdump --section-headers %t | FileCheck --check-prefix=CheckGot %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=Dis %s

	.text
	.abiversion 2
	.file	"intial_exec.c"
	.globl	test_initial_exec                    # -- Begin function test_initial_exec
	.p2align	4
	.type	test_initial_exec,@function
test_initial_exec:                                   # @test_initial_exec
.Lfunc_begin0:
.Lfunc_gep0:
	addis 2, 12, .TOC.-.Lfunc_gep0@ha
	addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
	.localentry	test_initial_exec, .Lfunc_lep0-.Lfunc_gep0
# %bb.0:                                # %entry
	li 3, 0
	stw 3, -12(1)
	addis 3, 2, a@got@tprel@ha
	ld 3, a@got@tprel@l(3)
	lwzx 4, 3, a@tls
	extsw 3, 4
	blr


test_hi:
.Lfunc_gep1:
  addis 2, 12, .TOC.-.Lfunc_gep1@ha
  addi  2, 2,  .TOC.-.Lfunc_gep1@l
.Lfunc_lep1:
  .localentry test2, .Lfunc_lep1-.Lfunc_gep1
  addis 3, 0, b@got@tprel@h
  blr

test_ds:
.Lfunc_gep2:
  addis 2, 12, .TOC.-.Lfunc_gep2@ha
  addi 2, 2, .TOC.-.Lfunc_gep2@l
.Lfunc_lep2:
  .localentry test16, .Lfunc_lep2-.Lfunc_gep2
  addi 3, 0, c@got@tprel
  blr

// Verify that the input has every initial-exec tls relocation type.
// InputRelocs: Relocation section '.rela.text'
// InputRelocs: R_PPC64_GOT_TPREL16_HA {{0+}} a + 0
// InputRelocs: R_PPC64_GOT_TPREL16_LO_DS {{0+}} a + 0
// InputRelocs: R_PPC64_TLS {{0+}} a + 0
// InputRelocs: R_PPC64_GOT_TPREL16_HI {{0+}} b + 0
// InputRelocs: R_PPC64_GOT_TPREL16_DS {{0+}} c + 0

// There is a got entry for each tls variable that is accessed with the
// initial-exec model to be filled in by the dynamic linker.
// OutputRelocs: Relocation section '.rela.dyn' at offset 0x{{[0-9a-f]+}} contains 3 entries:
// OutputRelocs: R_PPC64_TPREL64  {{0+}}  a + 0
// OutputRelocs: R_PPC64_TPREL64  {{0+}}  b + 0
// OutputRelocs: R_PPC64_TPREL64  {{0+}}  c + 0

// Check that the got has 4 entires. (1 for the TOC and 3 entries for TLS
// variables). Also verify the address so we can check
// the offsets we calculated for each relocation type.
// CheckGot: got          00000020 00000000100200c0

// GOT stats at 0x100200c0, so TOC will be 0x100280c0

// We are building the address of the first TLS got entry which contains the
// offset of the tls variable relative to the thread pointer.
// 0x100200c8 (got[1]).
// #ha(a@got@tprel) --> (0x100200c8 - 0x100280c0 + 0x8000) >> 16 = 0
// #lo(a@got@tprel)) --> (0x100200c8 - 0x100280c0) & 0xFFFF =  -7ff8 = -32760
// Dis:  test_initial_exec:
// Dis:    addis 3, 2, 0
// Dis:    ld 3, -32760(3)
// Dis:    lwzx 4, 3, 13

// Second TLS got entry starts at got[2] 0x100200d0
// #hi(b@got@tprel) --> (0x100200d0 - 0x100280c0) >> 16 = -1
// Dis: test_hi:
// Dis:   lis 3, -1

// Third TLS got entry starts at got[3] 0x100200d8.
// c@got@tprel--> (0x100200d8. -  0x100280c0) = -0x7fe8 = 32744
// Dis: test_ds:
// Dis:   li 3, -32744
