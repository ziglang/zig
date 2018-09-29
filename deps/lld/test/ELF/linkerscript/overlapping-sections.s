# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "SECTIONS { \
# RUN:   .sec1 0x8000 : AT(0x8000) { sec1_start = .; *(.first_sec) sec1_end = .;} \
# RUN:   .sec2 0x8800 : AT(0x8080) { sec2_start = .; *(.second_sec) sec2_end = .;} \
# RUN: }" > %t-lma.script
# RUN: not ld.lld -o %t.so --script %t-lma.script %t.o -shared 2>&1 | FileCheck %s -check-prefix LMA-OVERLAP-ERR
# LMA-OVERLAP-ERR:      error: section .sec1 load address range overlaps with .sec2
# LMA-OVERLAP-ERR-NEXT: >>> .sec1 range is [0x8000, 0x80FF]
# LMA-OVERLAP-ERR-NEXT: >>> .sec2 range is [0x8080, 0x817F]

# Check that we create the expected binary with --noinhibit-exec or --no-check-sections:
# RUN: ld.lld -o %t.so --script %t-lma.script %t.o -shared --noinhibit-exec
# RUN: ld.lld -o %t.so --script %t-lma.script %t.o -shared --no-check-sections -fatal-warnings
# RUN: ld.lld -o %t.so --script %t-lma.script %t.o -shared --check-sections --no-check-sections -fatal-warnings

# Verify that the .sec2 was indeed placed in a PT_LOAD where the PhysAddr
# overlaps with where .sec1 is loaded:
# RUN: llvm-readobj -sections -program-headers -elf-output-style=GNU %t.so | FileCheck %s -check-prefix BAD-LMA
# BAD-LMA-LABEL: Section Headers:
# BAD-LMA: .sec1             PROGBITS        0000000000008000 002000 000100 00  WA  0   0  1
# BAD-LMA: .sec2             PROGBITS        0000000000008800 002800 000100 00  WA  0   0  1
# BAD-LMA-LABEL: Program Headers:
# BAD-LMA-NEXT:  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align
# BAD-LMA-NEXT:  LOAD           0x001000 0x0000000000000000 0x0000000000000000 0x000100 0x000100 R E 0x1000
# BAD-LMA-NEXT:  LOAD           0x002000 0x0000000000008000 0x0000000000008000 0x000100 0x000100 RW  0x1000
# BAD-LMA-NEXT:  LOAD           0x002800 0x0000000000008800 0x0000000000008080 0x000170 0x000170 RW  0x1000
# BAD-LMA-LABEL: Section to Segment mapping:
# BAD-LMA:  01     .sec1
# BAD-LMA:  02     .sec2 .dynamic

# Now try a script where the virtual memory addresses overlap but ensure that the
# load addresses don't:
# RUN: echo "SECTIONS { \
# RUN:   .sec1 0x8000 : AT(0x8000) { sec1_start = .; *(.first_sec) sec1_end = .;} \
# RUN:   .sec2 0x8020 : AT(0x8800) { sec2_start = .; *(.second_sec) sec2_end = .;} \
# RUN: }" > %t-vaddr.script
# RUN: not ld.lld -o %t.so --script %t-vaddr.script %t.o -shared 2>&1 | FileCheck %s -check-prefix VADDR-OVERLAP-ERR
# VADDR-OVERLAP-ERR:      error: section .sec1 virtual address range overlaps with .sec2
# VADDR-OVERLAP-ERR-NEXT: >>> .sec1 range is [0x8000, 0x80FF]
# VADDR-OVERLAP-ERR-NEXT: >>> .sec2 range is [0x8020, 0x811F]

# Check that the expected binary was created with --noinhibit-exec:
# RUN: ld.lld -o %t.so --script %t-vaddr.script %t.o -shared --noinhibit-exec
# RUN: llvm-readobj -sections -program-headers -elf-output-style=GNU %t.so | FileCheck %s -check-prefix BAD-VADDR
# BAD-VADDR-LABEL: Section Headers:
# BAD-VADDR: .sec1             PROGBITS        0000000000008000 002000 000100 00  WA  0   0  1
# BAD-VADDR: .sec2             PROGBITS        0000000000008020 003020 000100 00  WA  0   0  1
# BAD-VADDR-LABEL: Program Headers:
# BAD-VADDR-NEXT:  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align
# BAD-VADDR-NEXT:  LOAD           0x001000 0x0000000000000000 0x0000000000000000 0x000100 0x000100 R E 0x1000
# BAD-VADDR-NEXT:  LOAD           0x002000 0x0000000000008000 0x0000000000008000 0x000100 0x000100 RW  0x1000
# BAD-VADDR-NEXT:  LOAD           0x003020 0x0000000000008020 0x0000000000008800 0x000170 0x000170 RW  0x1000
# BAD-VADDR-LABEL: Section to Segment mapping:
# BAD-VADDR:  01     .sec1
# BAD-VADDR:  02     .sec2 .dynamic

# Finally check the case where both LMA and vaddr overlap

# RUN: echo "SECTIONS { \
# RUN:   .sec1 0x8000 : { sec1_start = .; *(.first_sec) sec1_end = .;} \
# RUN:   .sec2 0x8040 : { sec2_start = .; *(.second_sec) sec2_end = .;} \
# RUN: }" > %t-both-overlap.script

# RUN: not ld.lld -o %t.so --script %t-both-overlap.script %t.o -shared 2>&1 | FileCheck %s -check-prefix BOTH-OVERLAP-ERR

# BOTH-OVERLAP-ERR:      error: section .sec1 file range overlaps with .sec2
# BOTH-OVERLAP-ERR-NEXT: >>> .sec1 range is [0x2000, 0x20FF]
# BOTH-OVERLAP-ERR-NEXT: >>> .sec2 range is [0x2040, 0x213F]
# BOTH-OVERLAP-ERR:      error: section .sec1 virtual address range overlaps with .sec2
# BOTH-OVERLAP-ERR-NEXT: >>> .sec1 range is [0x8000, 0x80FF]
# BOTH-OVERLAP-ERR-NEXT: >>> .sec2 range is [0x8040, 0x813F]
# BOTH-OVERLAP-ERR:      error: section .sec1 load address range overlaps with .sec2
# BOTH-OVERLAP-ERR-NEXT: >>> .sec1 range is [0x8000, 0x80FF]
# BOTH-OVERLAP-ERR-NEXT: >>> .sec2 range is [0x8040, 0x813F]

# RUN: ld.lld -o %t.so --script %t-both-overlap.script %t.o -shared --noinhibit-exec
# Note: In case everything overlaps we create a binary with overlapping file
# offsets. ld.bfd seems to place .sec1 to file offset 18000 and .sec2
# at 18100 so that only virtual addr and LMA overlap
# However, in order to create such a broken binary the user has to ignore a
# fatal error by passing --noinhibit-exec, so this behaviour is fine.

# RUN: llvm-objdump -s %t.so | FileCheck %s -check-prefix BROKEN-OUTPUT-FILE
# BROKEN-OUTPUT-FILE-LABEL: Contents of section .sec1:
# BROKEN-OUTPUT-FILE-NEXT: 8000 01010101 01010101 01010101 01010101
# BROKEN-OUTPUT-FILE-NEXT: 8010 01010101 01010101 01010101 01010101
# BROKEN-OUTPUT-FILE-NEXT: 8020 01010101 01010101 01010101 01010101
# BROKEN-OUTPUT-FILE-NEXT: 8030 01010101 01010101 01010101 01010101
# Starting here the contents of .sec2 overwrites .sec1:
# BROKEN-OUTPUT-FILE-NEXT: 8040 02020202 02020202 02020202 02020202

# RUN: llvm-readobj -sections -program-headers -elf-output-style=GNU %t.so | FileCheck %s -check-prefix BAD-BOTH
# BAD-BOTH-LABEL: Section Headers:
# BAD-BOTH: .sec1             PROGBITS        0000000000008000 002000 000100 00  WA  0   0  1
# BAD-BOTH: .sec2             PROGBITS        0000000000008040 002040 000100 00  WA  0   0  1
# BAD-BOTH-LABEL: Program Headers:
# BAD-BOTH-NEXT:  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align
# BAD-BOTH-NEXT:  LOAD 0x001000 0x0000000000000000 0x0000000000000000 0x000100 0x000100 R E 0x1000
# BAD-BOTH-NEXT:  LOAD           0x002000 0x0000000000008000 0x0000000000008000 0x0001b0 0x0001b0 RW  0x1000
# BAD-BOTH-LABEL: Section to Segment mapping:
# BAD-BOTH:   01     .sec1 .sec2 .dynamic

.section        .first_sec,"aw",@progbits
.rept 0x100
.byte 1
.endr

.section        .second_sec,"aw",@progbits
.rept 0x100
.byte 2
.endr
