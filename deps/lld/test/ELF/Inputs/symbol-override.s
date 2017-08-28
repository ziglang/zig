.text
.globl foo
.type foo,@function
foo:
nop

.globl bar
.type bar,@function
bar:
nop

.globl do
.type do,@function
do:
callq foo@PLT
callq bar@PLT
