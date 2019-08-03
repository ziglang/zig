.globl foo
foo:

.word _start - foo
.fill 14,1,0xcc

.byte _start - foo
.fill 15,1,0xcc
