.section ".note.gnu.property", "a"
.align 4
.long 4
.long 24
.long 5
.asciz "GNU"

.long 0xc0000000
.long 4
.long 0

.long 0xc0000002
.long 4
.long 3

.text
.globl func2
.type func2,@function
func2:
  ret
