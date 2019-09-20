# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: ld.lld -r %t1.o -o %t
# RUN: llvm-readobj -S --section-data %t | FileCheck %s

# CHECK:      Name: .comment
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_MERGE
# CHECK-NEXT:   SHF_STRINGS
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size: 7
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment: 1
# CHECK-NEXT: EntrySize: 1
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: 666F6F62 617200                      |foobar.|
# CHECK-NEXT: )


# We used to crash creating a merge and non merge .comment sections.

	.section	.comment,"MS",@progbits,1
	.asciz	"foobar"
