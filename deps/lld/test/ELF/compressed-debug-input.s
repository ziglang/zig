# REQUIRES: zlib, x86

# RUN: llvm-mc -compress-debug-sections=zlib -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: llvm-readobj -sections %t | FileCheck -check-prefix=ZLIB %s
# ZLIB:      Section {
# ZLIB:        Index: 2
# ZLIB:        Name: .debug_str
# ZLIB-NEXT:   Type: SHT_PROGBITS
# ZLIB-NEXT:   Flags [
# ZLIB-NEXT:     SHF_COMPRESSED (0x800)
# ZLIB-NEXT:     SHF_MERGE (0x10)
# ZLIB-NEXT:     SHF_STRINGS (0x20)
# ZLIB-NEXT:   ]
# ZLIB-NEXT:   Address:
# ZLIB-NEXT:   Offset:
# ZLIB-NEXT:   Size:
# ZLIB-NEXT:   Link:
# ZLIB-NEXT:   Info:
# ZLIB-NEXT:   AddressAlignment: 1
# ZLIB-NEXT:   EntrySize: 1
# ZLIB-NEXT: }

# RUN: llvm-mc -compress-debug-sections=zlib-gnu -filetype=obj -triple=x86_64-unknown-linux %s -o %t2
# RUN: llvm-readobj -sections %t2 | FileCheck -check-prefix=GNU %s
# GNU:      Section {
# GNU:        Index: 2
# GNU:        Name: .zdebug_str
# GNU-NEXT:   Type: SHT_PROGBITS
# GNU-NEXT:   Flags [
# GNU-NEXT:     SHF_MERGE (0x10)
# GNU-NEXT:     SHF_STRINGS (0x20)
# GNU-NEXT:   ]
# GNU-NEXT:   Address:
# GNU-NEXT:   Offset:
# GNU-NEXT:   Size:
# GNU-NEXT:   Link:
# GNU-NEXT:   Info:
# GNU-NEXT:   AddressAlignment: 1
# GNU-NEXT:   EntrySize: 1
# GNU-NEXT: }

# RUN: ld.lld %t -o %t.so -shared
# RUN: llvm-readobj -sections -section-data %t.so | FileCheck -check-prefix=DATA %s

# RUN: ld.lld %t2 -o %t2.so -shared
# RUN: llvm-readobj -sections -section-data %t2.so | FileCheck -check-prefix=DATA %s

# DATA:      Section {
# DATA:        Index: 6
# DATA:        Name: .debug_str
# DATA-NEXT:   Type: SHT_PROGBITS
# DATA-NEXT:   Flags [
# DATA-NEXT:     SHF_MERGE (0x10)
# DATA-NEXT:     SHF_STRINGS (0x20)
# DATA-NEXT:   ]
# DATA-NEXT:   Address: 0x0
# DATA-NEXT:   Offset: 0x1060
# DATA-NEXT:   Size: 69
# DATA-NEXT:   Link: 0
# DATA-NEXT:   Info: 0
# DATA-NEXT:   AddressAlignment: 1
# DATA-NEXT:   EntrySize: 0
# DATA-NEXT:   SectionData (
# DATA-NEXT:     0000: 73686F72 7420756E 7369676E 65642069  |short unsigned i|
# DATA-NEXT:     0010: 6E740075 6E736967 6E656420 696E7400  |nt.unsigned int.|
# DATA-NEXT:     0020: 6C6F6E67 20756E73 69676E65 6420696E  |long unsigned in|
# DATA-NEXT:     0030: 74006368 61720075 6E736967 6E656420  |t.char.unsigned |
# DATA-NEXT:     0040: 63686172 00                          |char.|
# DATA-NEXT:   )
# DATA-NEXT: }

.section .debug_str,"MS",@progbits,1
.LASF2:
 .string "short unsigned int"
.LASF3:
 .string "unsigned int"
.LASF0:
 .string "long unsigned int"
.LASF8:
 .string "char"
.LASF1:
 .string "unsigned char"
