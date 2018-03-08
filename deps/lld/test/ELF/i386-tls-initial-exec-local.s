# REQUIRES: x86
# RUN: llvm-mc %s -o %t.o -filetype=obj -triple=i386-pc-linux
# RUN: ld.lld %t.o -o %t.so -shared
# RUN: llvm-readobj --relocations --sections --section-data %t.so | FileCheck %s

# Check initial exec access to a local symbol.

# CHECK:      Name: .got (
# CHECK-NEXT: Type:
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_WRITE
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size: 8
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment:
# CHECK-NEXT: EntrySize:
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: 00000000 04000000
# CHECK-NEXT: )

# CHECK:      R_386_TLS_TPOFF - 0x0
# CHECK-NEXT: R_386_TLS_TPOFF - 0x0

	movl	bar1@GOTNTPOFF(%eax), %ecx
	movl	bar2@GOTNTPOFF(%eax), %eax

	.section	.tdata,"awT",@progbits
bar1:
	.long	42

bar2:
	.long	42
