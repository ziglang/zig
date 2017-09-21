.weak foo
foo:
        nop

.data
.global bar2
bar2:
.quad foo
