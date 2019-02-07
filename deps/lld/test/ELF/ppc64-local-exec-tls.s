// REQUIRES: ppc
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: ld.lld  %t.o -o %t
// RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=Dis %s

	.text
	.abiversion 2
	.globl	test_local_exec                    # -- Begin function test_local_exec
	.p2align	4
	.type	test_local_exec,@function
test_local_exec:                                   # @test_local_exec
.Lfunc_begin0:
# %bb.0:                                # %entry
	li 3, 0
	stw 3, -12(1)
	addis 3, 13, a@tprel@ha
	addi 3, 3, a@tprel@l
	ld 3, 0(3)
	mr 4, 3
	extsw 3, 4
	blr
	.long	0
	.quad	0
.Lfunc_end0:
	.size	test_local_exec, .Lfunc_end0-.Lfunc_begin0
                                        # -- End function
test_tprel:
.Lfunc_gep1:
  addis 2, 12, .TOC.-.Lfunc_gep1@ha
  addi 2, 2, .TOC.-.Lfunc_gep1@l
.Lfunc_lep1:
  .localentry test_tprel, .Lfunc_lep1-.Lfunc_gep1
  addi 3, 13, b@tprel
  blr


test_hi:
.Lfunc_gep2:
  addis 2, 12, .TOC.-.Lfunc_gep2@ha
  addi  2, 2,  .TOC.-.Lfunc_gep2@l
.Lfunc_lep2:
  .localentry test_hi, .Lfunc_lep2-.Lfunc_gep2
  addis 3, 13, b@tprel@h
  blr

test_ds:
.Lfunc_gep3:
  addis 2, 12, .TOC.-.Lfunc_gep3@ha
  addi 2, 2, .TOC.-.Lfunc_gep3@l
.Lfunc_lep3:
  .localentry test_ds, .Lfunc_lep3-.Lfunc_gep3
  ld 3, b@tprel, 13
  blr

test_lo_ds:
.Lfunc_gep4:
  addis 2, 12, .TOC.-.Lfunc_gep4@ha
  addi 2, 2, .TOC.-.Lfunc_gep4@l
.Lfunc_lep4:
  .localentry test_lo_ds, .Lfunc_lep4-.Lfunc_gep4
  ld 3, b@tprel@l, 13
  blr

test_highest_a:
.Lfunc_gep5:
  addis 2, 12, .TOC.-.Lfunc_gep5@ha
  addi  2, 2,  .TOC.-.Lfunc_gep5@l
.Lfunc_lep5:
  .localentry test_highest_a, .Lfunc_lep5-.Lfunc_gep5
  lis 4, b@tprel@highesta
  ori 4, 4, b@tprel@highera
  lis 5, b@tprel@ha
  addi 5, 5, b@tprel@l
  sldi 4, 4, 32
  or   4, 4, 5
  add  3, 13, 4
  blr

test_highest:
.Lfunc_gep6:
  addis 2, 12, .TOC.-.Lfunc_gep6@ha
  addi  2, 2,  .TOC.-.Lfunc_gep6@l
.Lfunc_lep6:
  .localentry test_highest, .Lfunc_lep6-.Lfunc_gep6
  lis 4, b@tprel@highest
  ori 4, 4, b@tprel@higher
  sldi 4, 4, 32
  oris  4, 4, b@tprel@h
  ori   4, 4, b@tprel@l
  add  3, 13, 4
  blr

	.type	a,@object               # @a
	.type	b,@object               # @b
	.section	.tdata,"awT",@progbits
	.p2align	3
a:
	.quad	55                      # 0x37
	.size	a, 8

b:
	.quad	55                      # 0x37
	.size	b, 8

// Verify that the input has every initial-exec tls relocation type.
// InputRelocs: Relocation section '.rela.text'
// InputRelocs: R_PPC64_TPREL16_HA {{0+}} a + 0
// InputRelocs: R_PPC64_TPREL16_LO {{0+}} a + 0
// InputRelocs: R_PPC64_TPREL16 {{0+8}} b + 0
// InputRelocs: R_PPC64_TPREL16_HI {{0+8}} b + 0
// InputRelocs: R_PPC64_TPREL16_DS {{0+8}} b + 0
// InputRelocs: R_PPC64_TPREL16_LO_DS {{0+8}} b + 0
// InputRelocs: R_PPC64_TPREL16_HIGHESTA {{0+8}} b + 0
// InputRelocs: R_PPC64_TPREL16_HIGHERA {{0+8}} b + 0
// InputRelocs: R_PPC64_TPREL16_HIGHEST {{0+8}} b + 0
// InputRelocs: R_PPC64_TPREL16_HIGHER {{0+8}} b + 0

// The start of the TLS storage area is 0x7000 bytes before the thread pointer (r13).
// We are building the address of the first TLS variable, relative to the thread pointer.
// #ha(a@tprel) --> (0 - 0x7000 + 0x8000) >> 16 = 0
// #lo(a@tprel)) --> (0 - 0x7000) &  0xFFFF =  -0x7000 = -28672
// Dis: test_local_exec:
// Dis: addis 3, 13, 0
// Dis: addi 3, 3, -28672

// We are building the offset for the second TLS variable
// Offset within tls storage - 0x7000
// b@tprel = 8 - 0x7000 = 28664
// Dis: test_tprel:
// Dis: addi 3, 13, -28664

// #hi(b@tprel) --> (8 - 0x7000) >> 16 = -1
// Dis: test_hi:
// Dis: addis 3, 13, -1

// b@tprel = 8 - 0x7000 = -28664
// Dis: test_ds:
// Dis: ld 3, -28664(13)

// #lo(b@tprel) --> (8 - 0x7000) & 0xFFFF = -28664
// Dis: test_lo_ds:
// Dis: ld 3, -28664(13)

// #highesta(b@tprel) --> ((0x8 - 0x7000 + 0x8000) >> 48) & 0xFFFF = 0
// #highera(b@tprel)  --> ((0x8 - 0x7000 + 0x8000) >> 32) & 0xFFFF = 0
// #ha(k@dtprel)       --> ((0x8 - 0x7000 + 0x8000) >> 16) & 0xFFFF = 0
// #lo(k@dtprel)       --> ((0x8 - 0x7000) & 0xFFFF = -28664
// Dis: test_highest_a:
// Dis: lis 4, 0
// Dis: ori 4, 4, 0
// Dis: lis 5, 0
// Dis: addi 5, 5, -28664

// #highest(b@tprel) --> ((0x8 - 0x7000) >> 48) & 0xFFFF = 0xFFFF = -1
// #higher(b@tprel)  --> ((0x8 - 0x7000) >> 32) & 0xFFFF = 0xFFFF = 65535
// #hi(k@dtprel)      --> ((0x8 - 0x7000) >> 16) & 0xFFFF = 0xFFFF = 65535
// #lo(k@dtprel)      --> ((0x8 - 0x7000) & 0xFFFF = 33796
// Dis: test_highest:
// Dis: lis 4, -1
// Dis: ori 4, 4, 65535
// Dis: oris 4, 4, 65535
// Dis: ori 4, 4, 36872
