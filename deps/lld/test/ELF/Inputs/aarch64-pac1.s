.section ".note.gnu.property", "a"
.long 4
.long 0x10
.long 0x5
.asciz "GNU"

.long 0xc0000000 // GNU_PROPERTY_AARCH64_FEATURE_1_AND
.long 4
.long 2          // GNU_PROPERTY_AARCH64_FEATURE_1_PAC
.long 0

.text
.globl func2
.type func2,@function
func2:
  .globl func3
  .type func3, @function
  bl func3
  ret
