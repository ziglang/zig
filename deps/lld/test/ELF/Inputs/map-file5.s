.bss
.type sharedFoo,@object
.globl sharedFoo
sharedFoo:
.long 0
.size sharedFoo, 4

.type sharedBar,@object
.globl sharedBar
sharedBar:
.quad 0
.size sharedBar, 8

.text
.globl sharedFunc1
.type sharedFunc1,@function
sharedFunc1:
 nop

.globl sharedFunc2
.type sharedFunc2,@function
sharedFunc2:
 nop
