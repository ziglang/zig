# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .foo : { *(.foo) } .bar : { *(.got.plt) BYTE(0x11) }}" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj -s %t | FileCheck %s

## We have ".got.plt" synthetic section with SHF_ALLOC|SHF_WRITE flags.
## It is empty, so linker removes it, but it has to keep ".got.plt" output
## section because of the BYTE command. Here we check that the output section
## still remembers what the flags of .got.plt are.

# CHECK:     Section {
# CHECK:       Index: 2
# CHECK:       Name: .bar
# CHECK-NEXT:  Type: SHT_PROGBITS
# CHECK-NEXT:  Flags [
# CHECK-NEXT:    SHF_ALLOC
# CHECK-NEXT:    SHF_WRITE
# CHECK-NEXT:  ]

## Check flags are not the same if we omit empty synthetic section in script.
# RUN: echo "SECTIONS { .foo : { *(.foo) } .bar : { BYTE(0x11) }}" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj -s %t | FileCheck --check-prefix=EMPTY %s

# EMPTY:     Section {
# EMPTY:       Index: 2
# EMPTY:       Name: .bar
# EMPTY-NEXT:  Type: SHT_PROGBITS
# EMPTY-NEXT:  Flags [
# EMPTY-NEXT:    SHF_ALLOC
# EMPTY-NEXT:    SHF_EXECINSTR
# EMPTY-NEXT:  ]

.section .foo,"ax"
.quad 0
