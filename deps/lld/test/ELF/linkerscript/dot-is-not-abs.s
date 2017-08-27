# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS { .text : { *(.text) } \
# RUN:                  foo = .; \
# RUN:                  .bar : { *(.bar) } }" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %t.o -shared
# RUN: llvm-readobj -t -s -section-data %t1 | FileCheck %s

.hidden foo
.long foo - .

.section .bar, "a"
.long 0

# The symbol foo is defined as a position in the file. This means that it is
# not absolute and it is possible to compute the distance from foo to some other
# position in the file. The symbol is not really in any output section, but
# ELF has no magic constant for not absolute, but not in any section.
# Fortunately the value of a symbol in a non relocatable file is a virtual
# address, so the section can be arbitrary.

# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .text
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_EXECINSTR
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x0
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size: 4
# CHECK-NEXT:   Link:
# CHECK-NEXT:   Info:
# CHECK-NEXT:   AddressAlignment:
# CHECK-NEXT:   EntrySize:
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 04000000 |
# CHECK-NEXT:   )
# CHECK-NEXT: }

# CHECK:      Symbol {
# CHECK:        Name: foo
# CHECK-NEXT:   Value: 0x4
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Local
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other [
# CHECK-NEXT:     STV_HIDDEN
# CHECK-NEXT:   ]
# CHECK-NEXT:   Section: .text
# CHECK-NEXT: }
