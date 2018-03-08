# REQUIRES: x86, zlib

# RUN: llvm-mc -compress-debug-sections=zlib-gnu -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
# RUN: llvm-readobj -sections %t1 | FileCheck -check-prefix=GNU %s
# GNU: Name: .zdebug_str

# RUN: ld.lld %t1 -o %t2 -r
# RUN: llvm-readobj -sections -section-data %t2 | FileCheck %s

## Check we decompress section and remove ".z" prefix specific for zlib-gnu compression.
# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .debug_str
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_MERGE
# CHECK-NEXT:     SHF_STRINGS
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Link:
# CHECK-NEXT:   Info:
# CHECK-NEXT:   AddressAlignment: 1
# CHECK-NEXT:   EntrySize: 1
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: {{.*}}  |long unsigned in|
# CHECK-NEXT:     0010: {{.*}}  |t.unsigned char.|
# CHECK-NEXT:     0020: {{.*}}  |unsigned int.cha|
# CHECK-NEXT:     0030: {{.*}}  |r.short unsigned|
# CHECK-NEXT:     0040: {{.*}}  | int.|
# CHECK-NEXT:   )
# CHECK-NEXT: }

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
