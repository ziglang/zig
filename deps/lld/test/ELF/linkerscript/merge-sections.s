# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS { \
# RUN:   . = SIZEOF_HEADERS; \
# RUN:   .foo : { begin = .; *(.foo.*) end = .;} \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t -shared
# RUN: llvm-readobj -s -t %t1 | FileCheck %s

# CHECK:        Name: .foo
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_MERGE
# CHECK-NEXT:     SHF_STRINGS
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x[[ADDR1:.*]]
# CHECK-NEXT:   Offset: 0x[[ADDR1]]
# CHECK-NEXT:   Size: 14
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 2
# CHECK-NEXT:   EntrySize: 0
# CHECK-NEXT: }

# CHECK:      Name: begin
# CHECK-NEXT: Value: 0x[[ADDR1]]

# CHECK:      Name: end
# CHECK-NEXT: Value: 0x236

# Check that we don't crash with --gc-sections
# RUN: ld.lld --gc-sections -o %t2 --script %t.script %t -shared
# RUN: llvm-readobj -s -t %t2 | FileCheck %s --check-prefix=GC

# GC:        Name: .foo
# GC-NEXT:   Type: SHT_NOBITS
# GC-NEXT:   Flags [
# GC-NEXT:     SHF_ALLOC
# GC-NEXT:   ]

.section        .foo.1a,"aMS",@progbits,1
.asciz "foo"

.section        .foo.1b,"aMS",@progbits,1
.asciz "foo"

.section        .foo.2a,"aM",@progbits,1
.byte 42

.section        .foo.2b,"aM",@progbits,1
.byte 42

.section        .foo.3a,"aM",@progbits,2
.align 2
.short 42

.section        .foo.3b,"aM",@progbits,2
.align 2
.short 42
