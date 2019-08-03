# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t.o
# RUN: ld.lld -r %t.o -o %t2.o
# RUN: llvm-readelf -n %t2.o | FileCheck -match-full-lines %s

## Test that .note.gnu.property is passed through -r, and that we can handle
## more than one FEATURE_AND in the same object file. This is logically the
## same as if the features were combined in a single FEATURE_AND as the rule
## states that the bit in the output pr_data field if it is set in all
.text
ret

.section ".note.gnu.property", "a"
.p2align 3
.long 4
.long 0x10
.long 0x5
.asciz "GNU"

.long 0xc0000000 // GNU_PROPERTY_AARCH64_FEATURE_1_AND
.long 4
.long 1          // GNU_PROPERTY_AARCH64_FEATURE_1_BTI
.long 0

.long 4
.long 0x10
.long 0x5
.asciz "GNU"
.long 0xc0000000 // GNU_PROPERTY_AARCH64_FEATURE_1_AND
.long 4
.long 2          // GNU_PROPERTY_AARCH64_FEATURE_1_PAC
.long 0

# CHECK:   Owner                 Data size	Description
# CHECK-NEXT:   GNU                   0x00000010	NT_GNU_PROPERTY_TYPE_0 (property note)
# CHECK-NEXT:     Properties:    aarch64 feature: BTI, PAC
