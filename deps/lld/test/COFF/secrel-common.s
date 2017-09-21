# RUN: llvm-mc %s -filetype=obj -triple=x86_64-windows-msvc -o %t.obj
# RUN: lld-link -entry:main -nodefaultlib %t.obj -out:%t.exe
# RUN: llvm-readobj %t.exe -sections -section-data | FileCheck %s

# Section relocations against common symbols resolve to .bss.

# CHECK: Sections [
# CHECK:   Section {
# CHECK:     Number: 1
# CHECK:     Name: .bss (2E 62 73 73 00 00 00 00)
# CHECK:     VirtualSize: 0x4
# CHECK:   }
# CHECK:   Section {
# CHECK:     Number: 2
# CHECK:     Name: .rdata (2E 72 64 61 74 61 00 00)
# CHECK:     SectionData (
# CHECK:       0000: 00000000 01000000 |........|
# CHECK:     )
# CHECK:   }
# CHECK:   Section {
# CHECK:     Number: 3
# CHECK:     Name: .text (2E 74 65 78 74 00 00 00)
# CHECK:     VirtualSize: 0x1
# CHECK:     SectionData (
# CHECK:       0000: C3                                   |.|
# CHECK:     )
# CHECK:   }
# CHECK-NOT: Section
# CHECK: ]

.text
.global main
main:
ret

.comm   common_global,4,2

.section .rdata,"dr"
.secrel32 common_global
.secidx common_global
.short 0
