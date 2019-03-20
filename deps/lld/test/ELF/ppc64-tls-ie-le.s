// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-tls-ie-le.s -o %t2.o
// RUN: ld.lld -dynamic-linker /lib64/ld64.so.2 %t.o %t2.o -o %t
// RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: llvm-readelf -r %t | FileCheck --check-prefix=OutputRelocs %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=Dis %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-tls-ie-le.s -o %t2.o
// RUN: ld.lld -dynamic-linker /lib64/ld64.so.2 %t.o %t2.o -o %t
// RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: llvm-readelf -r %t | FileCheck --check-prefix=OutputRelocs %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=Dis %s

	.text
	.abiversion 2
test1:                                  # @test1
	addis 3, 2, c@got@tprel@ha
	ld 3, c@got@tprel@l(3)
	lbzx 3, 3, c@tls
	blr
test2:                                  # @test2
	addis 3, 2, s@got@tprel@ha
	ld 3, s@got@tprel@l(3)
	lhzx 3, 3, s@tls
	blr
test3:                                  # @test3
	addis 3, 2, i@got@tprel@ha
	ld 3, i@got@tprel@l(3)
	lwzx 3, 3, i@tls
	blr
test4:                                  # @test4
	addis 3, 2, l@got@tprel@ha
	ld 3, l@got@tprel@l(3)
	ldx 3, 3, l@tls
	blr
test5:                                  # @test5
	addis 4, 2, c@got@tprel@ha
	ld 4, c@got@tprel@l(4)
	stbx 3, 4, c@tls
	blr
test6:                                  # @test6
	addis 4, 2, s@got@tprel@ha
	ld 4, s@got@tprel@l(4)
	sthx 3, 4, s@tls
	blr
test7:                                  # @test7
	addis 4, 2, i@got@tprel@ha
	ld 4, i@got@tprel@l(4)
	stwx 3, 4, i@tls
	blr
test8:                                  # @test8
	addis 4, 2, l@got@tprel@ha
	ld 4, l@got@tprel@l(4)
	stdx 3, 4, l@tls
	blr
test9:                                  # @test9
	addis 3, 2, i@got@tprel@ha
	ld 3, i@got@tprel@l(3)
	add 3, 3, i@tls
	blr
test_ds:                                  # @test_ds
	ld 4, l@got@tprel(2)
	stdx 3, 4, l@tls
	blr


// Verify that the input has initial-exec tls relocation types.
// InputRelocs: Relocation section '.rela.text'
// InputRelocs: R_PPC64_GOT_TPREL16_HA {{0+}} c + 0
// InputRelocs: R_PPC64_GOT_TPREL16_LO_DS {{0+}} c + 0
// InputRelocs: R_PPC64_TLS {{0+}} c + 0
// InputRelocs: R_PPC64_GOT_TPREL16_HA {{0+}} s + 0
// InputRelocs: R_PPC64_GOT_TPREL16_LO_DS {{0+}} s + 0
// InputRelocs: R_PPC64_TLS {{0+}} s + 0
// InputRelocs: R_PPC64_GOT_TPREL16_HA {{0+}} i + 0
// InputRelocs: R_PPC64_GOT_TPREL16_LO_DS {{0+}} i + 0
// InputRelocs: R_PPC64_TLS {{0+}} i + 0
// InputRelocs: R_PPC64_GOT_TPREL16_HA {{0+}} l + 0
// InputRelocs: R_PPC64_GOT_TPREL16_LO_DS {{0+}} l + 0
// InputRelocs: R_PPC64_TLS {{0+}} l + 0
// InputRelocs: R_PPC64_GOT_TPREL16_DS {{0+}} l + 0
// InputRelocs: R_PPC64_TLS {{0+}} l + 0

// Verify that no initial-exec relocations exist for the dynamic linker.
// OutputRelocs-NOT: R_PPC64_TPREL64  {{0+}}  c + 0
// OutputRelocs-NPT: R_PPC64_TPREL64  {{0+}}  s + 0
// OutputRelocs-NOT: R_PPC64_TPREL64  {{0+}}  i + 0
// OutputRelocs-NOT: R_PPC64_TPREL64  {{0+}}  l + 0

// Dis: test1:
// Dis: nop
// Dis: addis 3, 13, 0
// Dis: lbz 3, -28672(3)

// Dis: test2:
// Dis: nop
// Dis: addis 3, 13, 0
// Dis: lhz 3, -28670(3)

// Dis: test3:
// Dis: nop
// Dis: addis 3, 13, 0
// Dis: lwz 3, -28668(3)

// Dis: test4:
// Dis: nop
// Dis: addis 3, 13, 0
// Dis: ld 3, -28664(3)

// Dis: test5:
// Dis: nop
// Dis: addis 4, 13, 0
// Dis: stb 3, -28672(4)

// Dis: test6:
// Dis: nop
// Dis: addis 4, 13, 0
// Dis: sth 3, -28670(4)

// Dis: test7:
// Dis: nop
// Dis: addis 4, 13, 0
// Dis: stw 3, -28668(4)

// Dis: test8:
// Dis: nop
// Dis: addis 4, 13, 0
// Dis: std 3, -28664(4)

// Dis: test9:
// Dis: nop
// Dis: addis 3, 13, 0
// Dis: addi 3, 3, -28668

// Dis: test_ds:
// Dis: addis 4, 13, 0
// Dis: std 3, -28664(4)
